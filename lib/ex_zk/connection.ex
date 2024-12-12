defmodule ExZk.Connection do
  require Logger

  alias ExZk.{Frame, Socket}
  alias ExZk.Proto.WatcherEvent

  @behaviour :gen_statem

  defmodule WatchedEvent do
    defstruct [:state, :type, :path, :zxid]

    @type t :: %__MODULE__{state: integer(), type: integer(), path: String.t(), zxid: integer()}
  end

  defmodule WatcherSetEvent do
    defstruct [:watchers, :event]

    @type t :: %__MODULE__{watchers: list(), event: WatcherEvent.t()}
  end

  defstruct [
    :opts,
    :socket,
    :connected_address,
    :backoff_current,
    :reconnect_times,
    :session_id,
    :last_ping_sent,
    :waiting_events
  ]

  @type t :: %__MODULE__{
          opts: [option()],
          socket: pid(),
          connected_address: String.t(),
          backoff_current: timeout(),
          reconnect_times: integer(),
          session_id: integer(),
          last_ping_sent: Time.t(),
          waiting_events: :queue.queue(WatcherSetEvent.t())
        }

  @type option :: {:session_id, integer()} | ExZk.Socket.option() | :gen_statem.start_opt()

  @type status :: :disconnected | :connecting | :connected

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

  ####
  ## Callbacks
  ##

  @impl true
  def callback_mode, do: :state_functions

  @impl true
  def init(opts) do
    {:ok, socket} = ExZk.Socket.start_link(self(), opts)

    data = %__MODULE__{opts: opts, socket: socket}

    if opts[:sync_connect] do
      # We don't need to handle a timeout here because we're using a timeout in
      # connect/3 down the pipe.
      receive do
        {:connected, ^socket, _sock, address} ->
          {:ok, :connected, %__MODULE__{data | connected_address: address}}

        {:stopped, ^socket, reason} ->
          {:stop, %ExZk.ConnectionError{reason: reason}}
      end
    else
      {:ok, :connecting, data}
    end
  end

  @impl true
  def terminate(reason, _state, %__MODULE__{socket: socket}) do
    if Process.alive?(socket) and reason == :normal do
      :ok = ExZk.Socket.normal_stop(socket)
    end
  end

  ####
  ## State functions
  ##

  # "Disconnected" state: the connection is down and the socket is not alive.
  def disconnected({:timeout, :reconnect}, _timer_info, %__MODULE__{opts: opts} = data) do
    {:ok, socket} = ExZk.Socket.start_link(self(), opts)

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
  def connecting(:info, {:connected, socket, _sock, addr}, %__MODULE__{socket: socket} = data) do
    data = %{data | backoff_current: nil, reconnect_times: nil, connected_address: addr}
    {:next_state, :connected, %{data | socket: socket}}
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

  def connected(
        :info,
        {:frame, socket, %Frame{response: :pong}},
        %__MODULE__{socket: socket} = data
      ) do
    Logger.debug(
      "Got ping response for session id #{session_id(data)} after #{ping_response_time(data) |> Duration.to_iso8601()}"
    )

    {:keep_state, %__MODULE__{data | last_ping_sent: nil}}
  end

  def connected(
        :info,
        {:frame, socket, %Frame{response: {:auth_failed, err}}},
        %__MODULE__{socket: socket} = data
      ) do
    Logger.debug("Got auth response for session id #{session_id(data)} with err: #{err}")

    :keep_state_and_data
  end

  def connected(
        :info,
        {:frame, socket, %Frame{response: {:notification, zxid, watcher_event}}},
        %__MODULE__{socket: socket} = data
      ) do
    evt = struct!(%WatchedEvent{zxid: zxid}, Map.from_struct(watcher_event))

    Logger.debug(
      "Got notification for session id #{session_id(data)} with event: #{evt |> inspect()}"
    )

    {:keep_state, queue_event(data, evt)}
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
    :ok = Socket.send_frame(socket, Frame.new_ping_request())

    {:keep_state, %{data | last_ping_sent: Time.utc_now()}}
  end

  ####
  ## Private methods
  ##

  defp disconnect(%__MODULE__{opts: opts} = data, reason) do
    if opts[:exit_on_disconnection] do
      {:stop, %ExZk.ConnectionError{reason: reason}}
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

  defp session_id(%__MODULE__{session_id: nil}), do: "-"
  defp session_id(%__MODULE__{session_id: session_id}), do: Base.encode16(session_id)

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
end
