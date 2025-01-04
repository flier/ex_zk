defmodule ExZk.Session do
  require Logger

  use ExZk.Defs

  import ExZk.Frame

  alias ExZk.{
    Connector.Connected,
    Create,
    Defs.ErrCode,
    Error,
    Frame,
    Framer,
    Multi,
    Proto,
    Proto.ReplyHeader,
    Socket,
    WatchedEvent,
    WatchManager
  }

  alias ExZk.Data.{ACL, ClientInfo, Stat}

  @behaviour :gen_statem

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
  @type status :: :disconnected | :connecting | :connected
  @type version :: integer()
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

  defguard is_version_or_nil(version) when is_integer(version) or is_nil(version)

  @spec get_children(session(), Path.t(), watch :: boolean(), timeout()) ::
          {:ok, children :: list(Path.t())} | {:error, Error.t()}
  def get_children(session, path, watch \\ false, timeout \\ @default_timeout) do
    :telemetry.span([:ex_zk, :session, :get_children], %{session: session, path: path}, fn ->
      request = %Proto.GetChildrenRequest{
        path: IO.chardata_to_string(path),
        watch: watch || false
      }

      case send_request(session, :get_children, request, timeout) do
        {:ok, %Proto.GetChildrenResponse{children: children}} ->
          {{:ok, children}, %{children: children}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec get_children2(session(), Path.t(), watch :: boolean(), timeout()) ::
          {:ok, children :: list(Path.t()), Stat.t()} | {:error, Error.t()}
  def get_children2(session, path, watch \\ false, timeout \\ @default_timeout) do
    :telemetry.span([:ex_zk, :session, :get_children2], %{session: session, path: path}, fn ->
      request = %Proto.GetChildren2Request{
        path: IO.chardata_to_string(path),
        watch: watch || false
      }

      case send_request(session, :get_children2, request, timeout) do
        {:ok, %Proto.GetChildren2Response{children: children, stat: stat}} ->
          {{:ok, children, stat}, %{children: children, stat: stat}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec get_ephemerals(session(), Path.t(), timeout()) ::
          {:ok, children :: list(Path.t())} | {:error, Error.t()}
  def get_ephemerals(session, prefix_path \\ "/", timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :get_ephemerals],
      %{session: session, path: prefix_path},
      fn ->
        request = %Proto.GetEphemeralsRequest{prefix_path: IO.chardata_to_string(prefix_path)}

        case send_request(session, :get_ephemerals, request, timeout) do
          {:ok, %Proto.GetEphemeralsResponse{ephemerals: ephemerals}} ->
            {{:ok, ephemerals}, %{ephemerals: ephemerals}}

          {:error, err} ->
            {{:error, Error.new(err, prefix_path)}, %{error: err}}
        end
      end
    )
  end

  @spec get_all_children_number(session(), Path.t(), timeout()) ::
          {:ok, total_number :: integer()} | {:error, Error.t()}
  def get_all_children_number(session, path, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :get_all_children_number],
      %{session: session, path: path},
      fn ->
        request = %Proto.GetAllChildrenNumberRequest{path: IO.chardata_to_string(path)}

        case send_request(session, :get_all_children_number, request, timeout) do
          {:ok, %Proto.GetAllChildrenNumberResponse{total_number: total_number}} ->
            {{:ok, total_number}, %{total_number: total_number}}

          {:error, err} ->
            {{:error, Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec get_data(session(), Path.t(), watch :: boolean(), timeout()) ::
          {:ok, iodata(), Stat.t()} | {:error, Error.t()}
  def get_data(session, path, watch \\ false, timeout \\ @default_timeout) do
    :telemetry.span([:ex_zk, :session, :get_data], %{session: session, path: path}, fn ->
      request = %Proto.GetDataRequest{path: IO.chardata_to_string(path), watch: watch || false}

      case send_request(session, :get_data, request, timeout) do
        {:ok, %Proto.GetDataResponse{data: data, stat: stat}} ->
          {{:ok, data, stat}, %{data: data, stat: stat}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec set_data(session(), Path.t(), iodata(), version(), timeout()) ::
          {:ok, Stat.t()} | {:error, Error.t()}
  def set_data(session, path, data, version \\ @any_version, timeout \\ @default_timeout)
      when is_version_or_nil(version) do
    :telemetry.span(
      [:ex_zk, :session, :set_data],
      %{session: session, path: path, data: data, version: version},
      fn ->
        request = %Proto.SetDataRequest{
          path: IO.chardata_to_string(path),
          data: IO.iodata_to_binary(data),
          version: version || @any_version
        }

        case send_request(session, :set_data, request, timeout) do
          {:ok, %Proto.SetDataResponse{stat: stat}} ->
            {{:ok, stat}, %{stat: stat}}

          {:error, err} ->
            {{:error, Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec create(session(), Path.t(), iodata(), opts :: [Create.option()], timeout()) ::
          {:ok, Path.t(), Stat.t() | nil} | {:error, Error.t()}
  def create(session, path, data \\ "", opts \\ [], timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :create],
      %{session: session, path: path, data: data, opts: opts},
      fn ->
        {opcode, request} = Create.new_request(path, data, opts)

        case send_request(session, opcode, request, timeout) do
          {:ok, %Proto.CreateResponse{path: path}} ->
            {{:ok, path, nil}, %{path: path}}

          {:ok, %Proto.Create2Response{path: path, stat: stat}} ->
            {{:ok, path, stat}, %{path: path, stat: stat}}

          {:error, err} ->
            {{:error, Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec delete(session(), Path.t(), version() | nil, timeout()) ::
          :ok | {:error, Error.t()}
  def delete(session, path, version \\ @any_version, timeout \\ @default_timeout)
      when is_version_or_nil(version) do
    :telemetry.span(
      [:ex_zk, :session, :delete],
      %{session: session, path: path, version: version},
      fn ->
        request = %Proto.DeleteRequest{
          path: IO.chardata_to_string(path),
          version: version || @any_version
        }

        case send_request(session, :delete, request, timeout) do
          :ok ->
            {:ok, %{}}

          {:error, err} ->
            {{:error, Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec exists(session(), Path.t(), timeout()) ::
          {:ok, boolean(), Stat.t() | nil} | {:error, Error.t()}
  def exists(session, path, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :exists],
      %{session: session, path: path},
      fn ->
        request = %Proto.ExistsRequest{path: IO.chardata_to_string(path)}

        case send_request(session, :exists, request, timeout) do
          {:ok, %Proto.ExistsResponse{stat: stat}} ->
            {{:ok, true, stat}, %{stat: stat}}

          {:error, :no_node} ->
            {{:ok, false, nil}, %{}}

          {:error, err} ->
            {{:error, Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec get_acl(session(), Path.t(), timeout()) ::
          {:ok, list(ACL.t()), Stat.t()} | {:error, Error.t()}
  def get_acl(session, path, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :get_acl],
      %{session: session, path: path},
      fn ->
        request = %Proto.GetACLRequest{path: IO.chardata_to_string(path)}

        case send_request(session, :get_acl, request, timeout) do
          {:ok, %Proto.GetACLResponse{acl: acl, stat: stat}} ->
            {{:ok, acl, stat}, %{acl: acl, stat: stat}}

          {:error, err} ->
            {{:error, Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec set_acl(session(), Path.t(), acl :: [ACL.t()], version(), timeout()) ::
          {:ok, Stat.t()} | {:error, Error.t()}
  def set_acl(session, path, acl, version \\ @any_version, timeout \\ @default_timeout)
      when is_version_or_nil(version) do
    :telemetry.span(
      [:ex_zk, :session, :set_acl],
      %{session: session, path: path, acl: acl, version: version},
      fn ->
        request = %Proto.SetACLRequest{
          path: IO.chardata_to_string(path),
          acl: acl,
          version: version || @any_version
        }

        case send_request(session, :set_acl, request, timeout) do
          {:ok, %Proto.SetACLResponse{stat: stat}} ->
            {{:ok, stat}, %{stat: stat}}

          {:error, err} ->
            {{:error, Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec sync(session(), Path.t(), timeout()) :: {:ok, Path.t()} | {:error, Error.t()}
  def sync(session, path, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :sync],
      %{session: session, path: path},
      fn ->
        request = %Proto.SyncRequest{path: IO.chardata_to_string(path)}

        case send_request(session, :sync, request, timeout) do
          {:ok, %Proto.SyncResponse{path: path}} ->
            {{:ok, path}, %{path: path}}

          {:error, err} ->
            {{:error, Error.new(err, path)}, %{error: err}}
        end
      end
    )
  end

  @spec multi(session(), ops :: [Multi.Op.t()], timeout()) ::
          {[Multi.Result.t()]} | {:error, Error.t()}
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
            {{:error, Error.new(err)}, %{error: err}}
        end
      end
    )
  end

  @spec whoami(session(), timeout()) :: {:ok, [ClientInfo.t()]} | {:error, Error.t()}
  @spec whoami(atom() | pid() | {atom(), any()} | {:via, atom(), any()}) ::
          {:error, Error.t()} | {:ok, [ClientInfo.t()]}
  def whoami(session, timeout \\ @default_timeout) do
    :telemetry.span(
      [:ex_zk, :session, :who_am_i],
      %{session: session},
      fn ->
        case(send_request(session, :who_am_i, nil, timeout)) do
          {:ok, %Proto.WhoAmIResponse{client_info: client_info}} ->
            {{:ok, client_info}, %{client_info: client_info}}

          {:error, err} ->
            {{:error, Error.new(err)}, %{error: err}}
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

        {:disconnected, ^socket, error} ->
          {:stop, error}
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
        {:disconnected, socket, error},
        %__MODULE__{socket: socket} = data
      ) do
    :telemetry.execute(
      [:ex_zk, :session, :disconnected],
      %{system_time: System.system_time()},
      session_info(data)
    )

    data = %{data | connected_address: nil}
    disconnect(data, error)
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

  def connecting(:info, {:disconnected, socket, error}, %__MODULE__{socket: socket} = data) do
    :telemetry.execute([:ex_zk, :session, :disconnected], %{}, session_info(data))

    disconnect(data, error)
  end

  def connecting({:call, from}, :status, %__MODULE__{socket: socket} = _data) do
    :gen_statem.reply(from, {:connecting, %{socket: socket}})
    :keep_state_and_data
  end

  # "Connected" state: the session is up and the socket is alive.
  def connected(:info, {:disconnected, socket, error}, %__MODULE__{socket: socket} = data) do
    :telemetry.execute([:ex_zk, :session, :disconnected], %{}, session_info(data))

    data = %{data | connected_address: nil}
    disconnect(data, error)
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

  def connected(:cast, :send_ping, data), do: send_ping_request(data)
  def connected({:timeout, :send_ping}, %{}, data), do: send_ping_request(data)

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

    action = {{:timeout, :send_ping}, ping_interval(session_timeout), %{}}

    {data, action}
  end

  defp handle_frame(%Frame{response: :pong}, %__MODULE__{session_timeout: session_timeout} = data) do
    :telemetry.execute(
      [:ex_zk, :session, :pong],
      %{latency: ping_latency(data)},
      session_info(data)
    )

    data = %__MODULE__{data | last_ping_sent: nil}
    action = {{:timeout, :send_ping}, ping_interval(session_timeout), %{}}

    {:keep_state, data, action}
  end

  defp handle_frame(%Frame{response: {:auth_failed, err}}, %__MODULE__{} = data) do
    :telemetry.execute(
      [:ex_zk, :session, :auth, :failed],
      %{system_time: System.system_time()},
      session_info(data) |> Map.put(:error, ErrCode.cast!(err))
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
        res = extract_response(frame)

        :telemetry.execute(
          [:ex_zk, :session, :task, :stop],
          %{system_time: System.system_time()},
          session_info(data) |> Map.merge(%{task: task, frame: frame, reply: res})
        )

        :gen_statem.reply(from, res)

        {:keep_state, %__MODULE__{data | framer: framer, last_zxid: zxid}}

      {:error, reason} ->
        disconnect(data, reason)
    end
  end

  defp extract_response(%Frame{reply_hdr: %ReplyHeader{err: err}}) when err != 0,
    do:
      {:error,
       case ErrCode.cast(err) do
         {:ok, code} -> code
         :error -> err
       end}

  defp extract_response(%Frame{response: nil}), do: :ok
  defp extract_response(%Frame{response: response}), do: {:ok, response}

  defp disconnect(%__MODULE__{opts: opts} = data, error) do
    if opts[:exit_on_disconnection] do
      {:stop, error}
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

  defp send_ping_request(%__MODULE__{socket: socket} = data) do
    :ok = Socket.send_frame(socket, new_ping_request())

    {:keep_state, %{data | last_ping_sent: Time.utc_now()}}
  end

  defp ping_interval(nil), do: :infinity

  defp ping_interval(session_timeout) do
    recv_timeout = div(session_timeout * 2, 3)

    div(recv_timeout, 2)
  end

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
