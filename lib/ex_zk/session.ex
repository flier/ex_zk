defmodule ExZk.Session do
  require Logger

  import ExZk.Frame

  alias ExZk.{
    Create,
    Frame,
    Framer,
    Multi,
    Socket,
    WatchedEvent,
    WatchManager
  }

  alias ExZk.Connector.Connected
  alias ExZk.Data.{ACL, ClientInfo, Stat}
  alias ExZk.Defs.ErrCode

  alias ExZk.Proto.{
    Create2Response,
    CreateResponse,
    DeleteRequest,
    ExistsRequest,
    ExistsResponse,
    GetACLRequest,
    GetACLResponse,
    GetChildren2Request,
    GetChildren2Response,
    GetChildrenRequest,
    GetChildrenResponse,
    GetDataRequest,
    GetDataResponse,
    ReplyHeader,
    SetACLRequest,
    SetACLResponse,
    SetDataRequest,
    SetDataResponse,
    SyncRequest,
    SyncResponse,
    WhoAmIResponse
  }

  @behaviour :gen_statem

  defmodule Error do
    defexception [:reason]

    @type t :: %__MODULE__{reason: atom}

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

  @type session :: :gen_statem.server_ref()
  @type version :: integer()
  @type status :: :disconnected | :connecting | :connected
  @type zxid :: Frame.zxid()

  @default_timeout 5000
  @no_version -1

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

  @spec close(session(), timeout()) :: :ok
  def close(session, timeout \\ :infinity) do
    :gen_statem.stop(session, :normal, timeout)
  end

  @spec status(session()) :: {status(), metadata :: %{}}
  def status(session) do
    :telemetry.span([:ex_zk, :session, :status], %{session: session}, fn ->
      {status, metadata} = :gen_statem.call(session, :status)

      {{status, metadata}, %{status: status}}
    end)
  end

  @spec get_children(session(), Path.t(), timeout()) ::
          {:ok, children :: list(Path.t())} | {:error, ExZk.Error.t()}
  def get_children(session, path, timeout \\ @default_timeout) do
    :telemetry.span([:ex_zk, :session, :get_children], %{session: session, path: path}, fn ->
      request = %GetChildrenRequest{path: IO.chardata_to_string(path)}

      case send_request(session, :get_children, request, timeout) do
        {:ok, %GetChildrenResponse{children: children}} ->
          {{:ok, children}, %{children: children}}

        {:error, err} ->
          {{:error, ExZk.Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec get_children2(session(), Path.t(), timeout()) ::
          {:ok, children :: list(Path.t()), Stat.t()} | {:error, ExZk.Error.t()}
  def get_children2(session, path, timeout \\ @default_timeout) do
    :telemetry.span([:ex_zk, :session, :get_children2], %{session: session, path: path}, fn ->
      request = %GetChildren2Request{path: IO.chardata_to_string(path)}

      case send_request(session, :get_children2, request, timeout) do
        {:ok, %GetChildren2Response{children: children, stat: stat}} ->
          {{:ok, children, stat}, %{children: children, stat: stat}}

        {:error, err} ->
          {{:error, ExZk.Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec get_data(session(), Path.t(), timeout()) ::
          {:ok, iodata(), Stat.t()} | {:error, ExZk.Error.t()}
  def get_data(session, path, timeout \\ @default_timeout) do
    :telemetry.span([:ex_zk, :session, :get_data], %{session: session, path: path}, fn ->
      request = %GetDataRequest{path: IO.chardata_to_string(path)}

      case send_request(session, :get_data, request, timeout) do
        {:ok, %GetDataResponse{data: data, stat: stat}} ->
          {{:ok, data, stat}, %{data: data, stat: stat}}

        {:error, err} ->
          {{:error, ExZk.Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec set_data(session(), Path.t(), iodata(), version(), timeout()) ::
          {:ok, Stat.t()} | {:error, ExZk.Error.t()}
  def set_data(session, path, data \\ "", version \\ @no_version, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :set_data],
      %{session: session, path: path, data: data, version: version},
      fn ->
        request = %SetDataRequest{
          path: IO.chardata_to_string(path),
          data: IO.iodata_to_binary(data),
          version: version
        }

        case send_request(session, :set_data, request, timeout) do
          {:ok, %SetDataResponse{stat: stat}} ->
            {{:ok, stat}, %{stat: stat}}

          {:error, err} ->
            {{:error, ExZk.Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec create(session(), Path.t(), iodata(), opts :: [option()], timeout()) ::
          {:ok, Path.t(), Stat.t() | nil} | {:error, ExZk.Error.t()}
  def create(session, path, data \\ "", opts \\ [], timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :create],
      %{session: session, path: path, data: data, opts: opts},
      fn ->
        {opcode, request} = Create.new_request(path, data, opts)

        case send_request(session, opcode, request, timeout) do
          {:ok, %CreateResponse{path: path}} ->
            {{:ok, path, nil}, %{path: path}}

          {:ok, %Create2Response{path: path, stat: stat}} ->
            {{:ok, path, stat}, %{path: path, stat: stat}}

          {:error, err} ->
            {{:error, ExZk.Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec delete(session(), Path.t(), version(), timeout()) ::
          :ok | {:error, ExZk.Error.t()}
  def delete(session, path, version \\ @no_version, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :delete],
      %{session: session, path: path, version: version},
      fn ->
        request = %DeleteRequest{path: IO.chardata_to_string(path), version: version}

        case send_request(session, :delete, request, timeout) do
          :ok ->
            {:ok, %{}}

          {:error, err} ->
            {{:error, ExZk.Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec exists(session(), Path.t(), timeout()) ::
          {:ok, boolean(), Stat.t() | nil} | {:error, ExZk.Error.t()}
  def exists(session, path, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :exists],
      %{session: session, path: path},
      fn ->
        request = %ExistsRequest{path: IO.chardata_to_string(path)}

        case send_request(session, :exists, request, timeout) do
          {:ok, %ExistsResponse{stat: stat}} ->
            {{:ok, true, stat}, %{stat: stat}}

          {:error, :no_node} ->
            {{:ok, false, nil}, %{}}

          {:error, err} ->
            {{:error, ExZk.Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec get_acl(session(), Path.t(), timeout()) ::
          {:ok, list(ACL.t()), Stat.t()} | {:error, ExZk.Error.t()}
  def get_acl(session, path, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :get_acl],
      %{session: session, path: path},
      fn ->
        request = %GetACLRequest{path: IO.chardata_to_string(path)}

        case send_request(session, :get_acl, request, timeout) do
          {:ok, %GetACLResponse{acl: acl, stat: stat}} ->
            {{:ok, acl, stat}, %{acl: acl, stat: stat}}

          {:error, err} ->
            {{:error, ExZk.Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec set_acl(session(), Path.t(), acl :: [ACL.t()], version(), timeout()) ::
          {:ok, Stat.t()} | {:error, ExZk.Error.t()}
  def set_acl(session, path, acl, version \\ @no_version, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :set_acl],
      %{session: session, path: path, acl: acl, version: version},
      fn ->
        request = %SetACLRequest{path: IO.chardata_to_string(path), acl: acl, version: version}

        case send_request(session, :get_acl, request, timeout) do
          {:ok, %SetACLResponse{stat: stat}} ->
            {{:ok, stat}, %{stat: stat}}

          {:error, err} ->
            {{:error, ExZk.Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec sync(session(), Path.t(), timeout()) :: {:ok, Path.t()} | {:error, ExZk.Error.t()}
  def sync(session, path, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :sync],
      %{session: session, path: path},
      fn ->
        request = %SyncRequest{path: IO.chardata_to_string(path)}

        case send_request(session, :sync, request, timeout) do
          {:ok, %SyncResponse{path: path}} ->
            {{:ok, path}, %{path: path}}

          {:error, err} ->
            {{:error, ExZk.Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec multi(session(), ops :: [Multi.Op.t()], timeout()) ::
          {:ok, [Multi.Result.t()]} | {:error, ExZk.Error.t()}
  def multi(session, ops, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :exists],
      %{session: session, ops: ops},
      fn ->
        request = Multi.to_request(ops)

        case send_request(session, :multi, request, timeout) do
          {:ok, %Multi.Response{results: results}} ->
            {{:ok, results}, %{results: results}}

          {:error, err} ->
            {{:error, ExZk.Error.new(err)}, %{error: err}}
        end
      end
    )
  end

  @spec whoami(session(), timeout()) :: {:ok, [ClientInfo.t()]} | {:error, ExZk.Error.t()}
  def whoami(session, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :who_am_i],
      %{session: session},
      fn ->
        case(send_request(session, :who_am_i, nil, timeout)) do
          {:ok, %WhoAmIResponse{client_info: client_info}} ->
            {{:ok, client_info}, %{client_info: client_info}}

          {:error, err} ->
            {{:error, ExZk.Error.new(err)}, %{error: err}}
        end
      end
    )
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
        {:connected, ^socket, connected} ->
          {data, action} = on_connected(data, socket, connected)

          {:ok, :connected, data, action}

        {:disconnected, ^socket, reason} ->
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

  # "Disconnected" state: the session is close and the socket is not alive.
  def disconnected({:timeout, :reconnect}, _timer_info, %__MODULE__{opts: opts} = data) do
    {:ok, socket} = Socket.start_link(self(), opts)

    {:next_state, :connecting, %{data | socket: socket}}
  end

  def disconnected(
        :info,
        {:disconnected, socket, reason},
        %__MODULE__{opts: opts, socket: socket} = data
      ) do
    :telemetry.execute([:ex_zk, :session, :disconnected], %{system_time: System.system_time()}, %{
      session: self(),
      name: opts[:name]
    })

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

  # "Connecting" state: the session is on going and the socket is not alive.
  def connecting(
        :info,
        {:connected, socket, %Connected{} = connected},
        %__MODULE__{socket: socket} = data
      ) do
    {data, action} = on_connected(data, socket, connected)

    {:next_state, :connected, data, action}
  end

  def connecting(
        :info,
        {:disconnected, socket, reason},
        %__MODULE__{opts: opts, socket: socket} = data
      ) do
    :telemetry.execute([:ex_zk, :session, :disconnected], %{}, %{
      session: self(),
      name: opts[:name]
    })

    disconnect(data, reason)
  end

  def connecting({:call, from}, :status, %__MODULE__{socket: socket} = _data) do
    :gen_statem.reply(from, {:connecting, %{socket: socket}})
    :keep_state_and_data
  end

  # "Connected" state: the session is up and the socket is alive.
  def connected(
        :info,
        {:disconnected, socket, reason},
        %__MODULE__{opts: opts, socket: socket, session_id: session_id} = data
      ) do
    :telemetry.execute([:ex_zk, :session, :disconnected], %{}, %{
      session: self(),
      name: opts[:name],
      session_id: session_id
    })

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

  def connected(
        {:call, from},
        {:send_request, opcode, request},
        %__MODULE__{socket: socket, framer: framer} = data
      ) do
    {:ok, frame, framer} = Framer.new_frame(framer, opcode, request, from)
    :ok = Socket.send_frame(socket, frame)
    {:keep_state, %{data | framer: framer}}
  end

  def connected({:timeout, :send_ping}, %{}, %__MODULE__{socket: socket} = data) do
    :ok = Socket.send_frame(socket, new_ping_request())

    {:keep_state, %{data | last_ping_sent: Time.utc_now()}}
  end

  ####
  ## Private methods
  ##

  defp on_connected(
         %__MODULE__{opts: opts, last_zxid: last_zxid} = data,
         socket,
         %Connected{addr: addr, session_timeout: session_timeout, session_id: session_id}
       ) do
    :telemetry.execute(
      [:ex_zk, :session, :connected],
      %{system_time: System.system_time()},
      %{session_info(data) | session_id: session_id, addr: addr}
    )

    if !opts[:disable_auto_watch_reset] do
      for set_watches <- new_set_watches_request(last_zxid, data.watch_manager) do
        :ok = Socket.send_frame(socket, set_watches)
      end
    end

    data = %{
      data
      | socket: socket,
        connected_address: addr,
        session_id: session_id,
        session_timeout: session_timeout,
        framer: %Framer{},
        backoff_current: nil,
        reconnect_times: nil
    }

    action = {{:timeout, :send_ping}, ping_interval(data), %{}}

    {data, action}
  end

  defp handle_frame(%Frame{response: :pong}, %__MODULE__{} = data) do
    :telemetry.execute(
      [:ex_zk, :session, :pong],
      %{latency: ping_latency(data)},
      session_info(data)
    )

    data = %__MODULE__{data | last_ping_sent: nil}
    action = {{:timeout, :send_ping}, ping_interval(data), %{}}

    {:keep_state, data, action}
  end

  defp handle_frame(%Frame{response: {:auth_failed, err}}, %__MODULE__{} = data) do
    :telemetry.execute(
      [:ex_zk, :session, :auth, :failed],
      %{system_time: System.system_time()},
      session_info(data) |> Map.put(:error, ErrCode.cast(err))
    )

    :keep_state_and_data
  end

  defp handle_frame(%Frame{response: {:notification, evt}}, %__MODULE__{} = data) do
    :telemetry.execute(
      [:ex_zk, :session, :notification],
      %{system_time: System.system_time()},
      session_info(data) |> Map.put(:event, evt)
    )

    {:keep_state, queue_event(data, evt)}
  end

  defp handle_frame(%Frame{reply_hdr: %ReplyHeader{xid: xid}}, %__MODULE__{} = data)
       when xid < 0 do
    Logger.warning("Got unknown reply for session id #{session_id(data)} with with xid: #{xid}")

    :keep_state_and_data
  end

  defp handle_frame(
         %Frame{reply_hdr: %ReplyHeader{zxid: zxid}} = frame,
         %__MODULE__{framer: framer} = data
       ) do
    case Framer.parse_reply(frame, framer) do
      {:ok, frame, {task, _} = from, framer} ->
        reply =
          case frame do
            %Frame{reply_hdr: %ReplyHeader{err: err}} when err != 0 ->
              {:error,
               case ErrCode.cast(err) do
                 {:ok, code} -> code
                 :error -> err
               end}

            %Frame{response: nil} ->
              :ok

            %Frame{response: response} ->
              {:ok, response}
          end

        :telemetry.execute(
          [:ex_zk, :session, :task, :stop],
          %{system_time: System.system_time()},
          session_info(data) |> Map.merge(%{task: task, frame: frame, reply: reply})
        )

        :gen_statem.reply(from, reply)

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

  defp session_info(%__MODULE__{
         opts: opts,
         session_id: session_id,
         socket: socket,
         connected_address: addr
       }),
       do: %{
         session: self(),
         name: opts[:name],
         session_id: session_id,
         socket: socket,
         addr: addr
       }

  defp recv_timeout(%__MODULE__{} = data), do: div(data.session_timeout * 2, 3)
  defp ping_interval(%__MODULE__{} = data), do: div(recv_timeout(data), 2)

  defp ping_latency(%__MODULE__{last_ping_sent: nil}), do: %Duration{}

  defp ping_latency(%__MODULE__{last_ping_sent: last_ping_sent}) do
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

  defp send_request(session, opcode, request, timeout) do
    :gen_statem.call(session, {:send_request, opcode, request}, timeout)
  end
end
