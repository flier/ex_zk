defmodule ExZk.Connection do
  require Logger

  import ExZk.Frame
  alias ExZk.Connector.Connected
  alias ExZk.Defs.{ErrCode, OpCode}
  alias ExZk.Proto.ReplyHeader
  alias ExZk.{Frame, Framer, Socket, WatchedEvent, WatchManager}

  @behaviour :gen_statem

  defmodule Error do
    defexception [:reason]

    @type t() :: %__MODULE__{reason: atom}

    @impl true
    def message(%__MODULE__{reason: reason}) do
      format_reason(reason)
    end

    # :inet.format_error/1 doesn't format closed messages.
    defp format_reason(:tcp_closed), do: "TCP connection closed"
    defp format_reason(:ssl_closed), do: "SSL connection closed"

    # Manually returned by us when the connection is closed and someone tries to send a command to Zookeeper.
    defp format_reason(:closed), do: "the connection to Zookeeper is closed"

    defp format_reason(reason), do: reason |> :inet.format_error() |> List.to_string()
  end

  defmodule WatcherSetEvent do
    defstruct [:watchers, :event]

    @type t :: %__MODULE__{watchers: list(), event: WatchedEvent.t()}
  end

  defstruct [
    :opts,
    :socket,
    :connected_address,
    :backoff_current,
    :reconnect_times,
    :session_id,
    :session_timeout,
    :framer,
    :last_zxid,
    :last_ping_sent,
    :watch_manager,
    :waiting_events
  ]

  @type t :: %__MODULE__{
          opts: [option()],
          socket: pid(),
          connected_address: String.t(),
          backoff_current: timeout(),
          reconnect_times: integer(),
          session_id: integer(),
          session_timeout: timeout(),
          framer: Framer.t(),
          last_zxid: zxid(),
          last_ping_sent: Time.t(),
          watch_manager: WatchManager.t(),
          waiting_events: :queue.queue(WatcherSetEvent.t())
        }

  @type option :: {:session_id, integer()} | Socket.option() | :gen_statem.start_opt()

  @type status :: :disconnected | :connecting | :connected
  @type zxid :: Frame.zxid()

  ####
  ## Public API
  ##

  @spec start_link([option()]) :: :gen_statem.start_ret()
  def start_link(opts) when is_list(opts) do
    {gen_statem_opts, opts} = Keyword.split(opts, [:hibernate_after, :debug, :spawn_opt])

    case Keyword.fetch(opts, :name) do
      :error ->
        :gen_statem.start_link(__MODULE__, opts, gen_statem_opts)

      {:ok, atom} when is_atom(atom) ->
        :gen_statem.start_link({:local, atom}, __MODULE__, opts, gen_statem_opts)

      {:ok, {:global, _term} = tuple} ->
        :gen_statem.start_link(tuple, __MODULE__, opts, gen_statem_opts)

      {:ok, {:via, via_module, _term} = tuple} when is_atom(via_module) ->
        :gen_statem.start_link(tuple, __MODULE__, opts, gen_statem_opts)

      {:ok, other} ->
        raise ArgumentError, """
        expected :name option to be one of the following:

          * nil
          * atom
          * {:global, term}
          * {:via, module, term}

        Got: #{inspect(other)}
        """
    end
  end

  @spec stop(:gen_statem.server_ref(), timeout()) :: :ok
  def stop(conn, timeout \\ :infinity) do
    :gen_statem.stop(conn, :normal, timeout)
  end

  @spec status(:gen_statem.server_ref()) :: status()
  def status(conn) do
    :gen_statem.call(conn, :status)
  end

  @spec send_request(:gen_statem.server_ref(), OpCode.t(), Frame.request()) :: :ok
  def send_request(conn, opcode, request) do
    :gen_statem.cast(conn, {:send_request, self(), opcode, request})
  end

  ####
  ## Callbacks
  ##

  @impl true
  def callback_mode, do: :state_functions

  @impl true
  def init(opts) do
    {:ok, socket} = Socket.start_link(self(), opts)

    data = %__MODULE__{
      opts: opts,
      socket: socket,
      watch_manager: %WatchManager{}
    }

    if opts[:sync_connect] do
      # We don't need to handle a timeout here because we're using a timeout in
      # connect/3 down the pipe.
      receive do
        {:connected, ^socket, %Connected{} = connected} ->
          {:ok, :connected, on_connected(data, socket, connected)}

        {:stopped, ^socket, reason} ->
          {:stop, %Error{reason: reason}}
      end
    else
      {:ok, :connecting, data}
    end
  end

  @impl true
  def terminate(reason, _state, %__MODULE__{socket: socket}) do
    :ok = Socket.send_frame(socket, new_close_session())

    if Process.alive?(socket) and reason == :normal do
      :ok = Socket.normal_stop(socket)
    end
  end

  ####
  ## State functions
  ##

  # "Disconnected" state: the connection is down and the socket is not alive.
  def disconnected({:timeout, :reconnect}, _timer_info, %__MODULE__{opts: opts} = data) do
    {:ok, socket} = Socket.start_link(self(), opts)

    {:next_state, :connecting, %{data | socket: socket}}
  end

  def disconnected(:info, {:stopped, socket, reason}, %__MODULE__{socket: socket} = data) do
    data = %{data | connected_address: nil}
    disconnect(data, reason)
  end

  def disconnected(
        {:call, from},
        :status,
        %__MODULE__{backoff_current: backoff_current, reconnect_times: reconnect_times} = _data
      ) do
    :gen_statem.reply(
      from,
      {:disconnected, %{backoff_current: backoff_current, reconnect_times: reconnect_times}}
    )

    :keep_state_and_data
  end

  # "Connecting" state: the connection is on going and the socket is not alive.
  def connecting(
        :info,
        {:connected, socket, %Connected{} = connected},
        %__MODULE__{socket: socket} = data
      ) do
    {:next_state, :connected, on_connected(data, socket, connected)}
  end

  def connecting(:info, {:stopped, socket, reason}, %__MODULE__{socket: socket} = data) do
    disconnect(data, reason)
  end

  def connecting({:call, from}, :status, %__MODULE__{socket: socket} = _data) do
    :gen_statem.reply(from, {:connecting, %{socket: socket}})
    :keep_state_and_data
  end

  # "Connected" state: the connection is up and the socket is alive.
  def connected(:info, {:stopped, socket, reason}, %__MODULE__{socket: socket} = data) do
    data = %{data | connected_address: nil}
    disconnect(data, reason)
  end

  def connected(:info, {:frame, socket, frame}, %__MODULE__{socket: socket} = data) do
    handle_frame(frame, data)
  end

  def connected(
        {:call, from},
        :status,
        %__MODULE__{socket: socket, connected_address: addr} = _data
      ) do
    :gen_statem.reply(from, {:connected, %{socket: socket, addr: addr}})
    :keep_state_and_data
  end

  def connected(:cast, :ping, %__MODULE__{socket: socket} = data) do
    :ok = Socket.send_frame(socket, new_ping_request())

    {:keep_state, %{data | last_ping_sent: Time.utc_now()}}
  end

  def connected(
        :cast,
        {:send_request, sender, opcode, request},
        %__MODULE__{socket: socket, framer: framer} = data
      ) do
    {:ok, frame, framer} = Framer.new_frame(framer, opcode, request, sender)
    :ok = Socket.send_frame(socket, frame)
    {:keep_state, %{data | framer: framer}}
  end

  ####
  ## Private methods
  ##

  defp on_connected(%__MODULE__{opts: opts, last_zxid: last_zxid} = data, socket, connected) do
    if !opts[:disable_auto_watch_reset] do
      for set_watches <- new_set_watches_request(last_zxid, data.watch_manager) do
        :ok = Socket.send_frame(socket, set_watches)
      end
    end

    %{
      data
      | socket: socket,
        connected_address: connected.addr,
        session_timeout: connected.session_timeout,
        session_id: connected.session_id,
        framer: %Framer{},
        backoff_current: nil,
        reconnect_times: nil
    }
  end

  defp handle_frame(%Frame{response: :pong}, %__MODULE__{} = data) do
    Logger.debug(
      "Got ping response for session id #{session_id(data)} after #{ping_response_time(data) |> Duration.to_iso8601()}"
    )

    {:keep_state, %__MODULE__{data | last_ping_sent: nil}}
  end

  defp handle_frame(%Frame{response: {:auth_failed, err}}, %__MODULE__{} = data) do
    Logger.debug("Got auth response for session id #{session_id(data)} with err: #{err}")

    :keep_state_and_data
  end

  defp handle_frame(%Frame{response: {:notification, evt}}, %__MODULE__{} = data) do
    Logger.debug(
      "Got notification for session id #{session_id(data)} with event: #{evt |> inspect()}"
    )

    {:keep_state, queue_event(data, evt)}
  end

  defp handle_frame(%Frame{reply_hdr: %ReplyHeader{xid: xid}}, %__MODULE__{} = data)
       when xid < 0 do
    Logger.warning("Got unknown reply for session id #{session_id(data)} with with xid: #{xid}")

    :keep_state_and_data
  end

  defp handle_frame(
         %Frame{reply_hdr: %ReplyHeader{zxid: zxid}, payload: payload},
         %__MODULE__{framer: framer} = data
       ) do
    case Framer.parse_frame(framer, payload) do
      {:ok, frame, sender, framer} ->
        case frame do
          %Frame{reply_hdr: %ReplyHeader{err: err}} when err != 0 ->
            send(
              sender,
              {:error,
               case ErrCode.cast(err) do
                 {:ok, code} -> code
                 :error -> err
               end}
            )

          %Frame{response: response} ->
            send(sender, {:ok, response})
        end

        {:keep_state, %__MODULE__{data | framer: framer, last_zxid: zxid}}

      {:error, reason} ->
        disconnect(data, reason)
    end
  end

  defp disconnect(%__MODULE__{opts: opts} = data, reason) do
    if opts[:exit_on_disconnection] do
      {:stop, %Error{reason: reason}}
    else
      {backoff, data} = next_backoff(data)

      actions = [
        {{:timeout, :reconnect}, backoff, nil}
      ]

      {:next_state, :disconnected, data, actions}
    end
  end

  defp next_backoff(%__MODULE__{backoff_current: nil} = data) do
    backoff_initial = data.opts[:backoff_initial]
    {backoff_initial, %{data | backoff_current: backoff_initial, reconnect_times: 1}}
  end

  @backoff_exponent 1.5

  defp next_backoff(%__MODULE__{opts: opts, reconnect_times: reconnect_times} = data) do
    next_exponential_backoff = round(data.backoff_current * @backoff_exponent)

    backoff_current =
      case opts[:backoff_max] do
        :infinity -> next_exponential_backoff
        backoff_max -> min(next_exponential_backoff, backoff_max)
      end

    {backoff_current,
     %{data | backoff_current: backoff_current, reconnect_times: reconnect_times + 1}}
  end

  defp session_id(%__MODULE__{session_id: session_id}) when session_id in [nil, 0], do: "-"

  defp session_id(%__MODULE__{session_id: session_id}),
    do: session_id |> Integer.to_string(16) |> String.pad_leading(8, "0")

  defp ping_response_time(%__MODULE__{last_ping_sent: nil}), do: %Duration{}

  defp ping_response_time(%__MODULE__{last_ping_sent: last_ping_sent}) do
    %Duration{microsecond: {Time.diff(Time.utc_now(), last_ping_sent, :microsecond), 6}}
  end

  defp queue_event(%__MODULE__{waiting_events: nil} = data, event) do
    queue_event(%__MODULE__{data | waiting_events: :queue.new()}, event)
  end

  defp queue_event(%__MODULE__{waiting_events: waiting_events} = data, event) do
    %__MODULE__{data | waiting_events: :queue.in(%WatcherSetEvent{event: event}, waiting_events)}
  end

  @set_watches_max_length 128 * 1024

  defp new_set_watches_request(last_zxid, %WatchManager{} = watch_manager) do
    if WatchManager.empty?(watch_manager) do
      []
    else
      watch_manager
      |> WatchManager.watches()
      |> Enum.chunk_every(@set_watches_max_length)
      |> Enum.map(&new_set_watches_request(last_zxid, &1))
    end
  end

  defp new_set_watches_request(last_zxid, watches) when is_list(watches) do
    watches = watches |> Enum.group_by(fn {type, _path} -> type end, fn {_, path} -> path end)

    data_watches = watches[:data] || []
    exists_watches = watches[:exists] || []
    child_watches = watches[:child] || []
    persistent_watches = watches[:persistent] || []
    persistent_recursive_watches = watches[:persistent_recursive] || []

    if persistent_watches == [] and persistent_recursive_watches == [] do
      new_set_watches_request(
        last_zxid,
        data_watches,
        exists_watches,
        child_watches
      )
    else
      new_set_watches2_request(
        last_zxid,
        data_watches,
        exists_watches,
        child_watches,
        persistent_watches,
        persistent_recursive_watches
      )
    end
  end
end
