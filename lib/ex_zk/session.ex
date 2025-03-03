defmodule ExZk.Session do
  require Logger

  use ExZk.Defs

  import ExZk.Defs.OpCode
  import ExZk.Frame
  import ExZk.Watcher.Type
  import ExZk.Format

  alias ExZk.{
    Connector.Connected,
    Create,
    Defs.AddWatchMode,
    Defs.ErrCode,
    Error,
    Frame,
    Framer,
    Multi,
    NodeWatcher,
    Proto,
    Proto.ReplyHeader,
    Socket,
    StateWatcher,
    Telemetry,
    WatchDeregistration,
    WatchedEvent,
    Watcher,
    WatchManager,
    WatchRegistration
  }

  alias ExZk.Data.{ACL, ClientInfo, Stat}

  @behaviour :gen_statem

  defmodule Info do
    defstruct [:id, :timeout, :addr, :readonly, :last_zxid]

    @type t :: %__MODULE__{
            id: ExZk.Session.id(),
            timeout: timeout(),
            addr: String.t(),
            readonly: boolean(),
            last_zxid: ExZk.Frame.zxid()
          }
  end

  defstruct [
    :opts,
    :socket,
    :connected_address,
    :backoff_current,
    :reconnect_times,
    :session_id,
    :session_timeout,
    :readonly,
    :framer,
    :last_zxid,
    :last_ping_sent,
    :watch_manager,
    :span
  ]

  @type t :: %__MODULE__{
          opts: [option()],
          socket: pid(),
          connected_address: String.t(),
          backoff_current: timeout(),
          reconnect_times: integer(),
          session_id: id(),
          session_timeout: timeout(),
          readonly: boolean(),
          framer: Framer.t(),
          last_zxid: Frame.zxid(),
          last_ping_sent: Time.t(),
          watch_manager: WatchManager.t(),
          span: Telemetry.t()
        }

  @type option ::
          {:session_id, id()}
          | {:state_watcher, StateWatcher.t()}
          | {:default_watcher, NodeWatcher.t()}
          | Socket.option()
          | :gen_statem.start_opt()

  @type ref :: :gen_statem.server_ref()
  @type id :: integer()
  @type status :: :disconnected | :connecting | :connected
  @type version :: integer()

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

  @spec close(ref(), timeout()) :: :ok
  def close(session, timeout \\ :infinity) do
    :gen_statem.stop(session, :normal, timeout)
  end

  @spec status(ref()) :: {status(), metadata :: %{}}
  def status(session) do
    Telemetry.client_span(:status, %{session: session}, fn ->
      {status, metadata} = :gen_statem.call(session, :status)

      {{status, metadata}, %{status: status}}
    end)
  end

  @spec info(ref()) :: Info.t()
  def info(session) do
    Telemetry.client_span(:info, %{session: session}, fn ->
      case :gen_statem.call(session, :info) do
        {:ok, info} ->
          {{:ok, info}, %{info: info}}

        {:error, err} ->
          {{:error, err}, %{error: err}}
      end
    end)
  end

  defguard is_version_or_nil(version) when is_integer(version) or is_nil(version)

  @spec get_children(ref(), Path.t(), NodeWatcher.t(), timeout()) ::
          {:ok, children :: list(Path.t())} | {:error, Error.t()}
  def get_children(session, path, watcher \\ nil, timeout \\ @default_timeout) do
    Telemetry.client_span(:get_children, %{session: session, path: path}, fn ->
      request = %Proto.GetChildrenRequest{
        path: IO.chardata_to_string(path),
        watch: !is_nil(watcher)
      }

      watch_registration =
        if is_nil(watcher),
          do: nil,
          else: WatchRegistration.child_watch_registration(path, watcher)

      case send_request(session, :get_children, request, watch_registration, timeout) do
        {:ok, %Proto.GetChildrenResponse{children: children}} ->
          {{:ok, children}, %{children: children}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec get_children2(ref(), Path.t(), NodeWatcher.t(), timeout()) ::
          {:ok, children :: list(Path.t()), Stat.t()} | {:error, Error.t()}
  def get_children2(session, path, watcher \\ nil, timeout \\ @default_timeout) do
    Telemetry.client_span(:get_children2, %{session: session, path: path}, fn ->
      request = %Proto.GetChildren2Request{
        path: IO.chardata_to_string(path),
        watch: !is_nil(watcher)
      }

      watch_registration =
        if is_nil(watcher),
          do: nil,
          else: WatchRegistration.child_watch_registration(path, watcher)

      case send_request(session, :get_children2, request, watch_registration, timeout) do
        {:ok, %Proto.GetChildren2Response{children: children, stat: stat}} ->
          {{:ok, children, stat}, %{children: children, stat: stat}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec get_ephemerals(ref(), Path.t(), timeout()) ::
          {:ok, children :: list(Path.t())} | {:error, Error.t()}
  def get_ephemerals(session, prefix_path \\ "/", timeout \\ @default_timeout) do
    Telemetry.client_span(:get_ephemerals, %{session: session, path: prefix_path}, fn ->
      request = %Proto.GetEphemeralsRequest{prefix_path: IO.chardata_to_string(prefix_path)}

      case send_request(session, :get_ephemerals, request, timeout) do
        {:ok, %Proto.GetEphemeralsResponse{ephemerals: ephemerals}} ->
          {{:ok, ephemerals}, %{ephemerals: ephemerals}}

        {:error, err} ->
          {{:error, Error.new(err, prefix_path)}, %{error: err}}
      end
    end)
  end

  @spec get_all_children_number(ref(), Path.t(), timeout()) ::
          {:ok, total_number :: integer()} | {:error, Error.t()}
  def get_all_children_number(session, path, timeout \\ @default_timeout) do
    Telemetry.client_span(:get_all_children_number, %{session: session, path: path}, fn ->
      request = %Proto.GetAllChildrenNumberRequest{path: IO.chardata_to_string(path)}

      case send_request(session, :get_all_children_number, request, timeout) do
        {:ok, %Proto.GetAllChildrenNumberResponse{total_number: total_number}} ->
          {{:ok, total_number}, %{total_number: total_number}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec get_data(ref(), Path.t(), NodeWatcher.t(), timeout()) ::
          {:ok, iodata(), Stat.t()} | {:error, Error.t()}
  def get_data(session, path, watcher \\ nil, timeout \\ @default_timeout) do
    Telemetry.client_span(:get_data, %{session: session, path: path}, fn ->
      request = %Proto.GetDataRequest{path: IO.chardata_to_string(path), watch: !is_nil(watcher)}

      watch_registration =
        if is_nil(watcher),
          do: nil,
          else: WatchRegistration.data_watch_registration(path, watcher)

      case send_request(session, :get_data, request, watch_registration, timeout) do
        {:ok, %Proto.GetDataResponse{data: data, stat: stat}} ->
          {{:ok, data, stat}, %{data: data, stat: stat}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec set_data(ref(), Path.t(), iodata(), version(), timeout()) ::
          {:ok, Stat.t()} | {:error, Error.t()}
  def set_data(session, path, data, version \\ @any_version, timeout \\ @default_timeout)
      when is_version_or_nil(version) do
    Telemetry.client_span(
      :set_data,
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

  @spec create(ref(), Path.t(), iodata(), opts :: [Create.option()], timeout()) ::
          {:ok, Path.t(), Stat.t() | nil} | {:error, Error.t()}
  def create(session, path, data \\ "", opts \\ [], timeout \\ @default_timeout) do
    Telemetry.client_span(
      :create,
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

  @spec delete(ref(), Path.t(), version() | nil, timeout()) ::
          :ok | {:error, Error.t()}
  def delete(session, path, version \\ @any_version, timeout \\ @default_timeout)
      when is_version_or_nil(version) do
    Telemetry.client_span(:delete, %{session: session, path: path, version: version}, fn ->
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
    end)
  end

  @spec exists(ref(), Path.t(), NodeWatcher.t(), timeout()) ::
          {:ok, boolean(), Stat.t() | nil} | {:error, Error.t()}
  def exists(session, path, watcher \\ nil, timeout \\ @default_timeout) do
    Telemetry.client_span(:exists, %{session: session, path: path}, fn ->
      request = %Proto.ExistsRequest{path: IO.chardata_to_string(path), watch: !is_nil(watcher)}

      watch_registration =
        if is_nil(watcher),
          do: nil,
          else: WatchRegistration.exists_watch_registration(path, watcher)

      case send_request(session, :exists, request, watch_registration, timeout) do
        {:ok, %Proto.ExistsResponse{stat: stat}} ->
          {{:ok, true, stat}, %{stat: stat}}

        {:error, :no_node} ->
          {{:ok, false, nil}, %{}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec get_acl(ref(), Path.t(), timeout()) ::
          {:ok, list(ACL.t()), Stat.t()} | {:error, Error.t()}
  def get_acl(session, path, timeout \\ @default_timeout) do
    Telemetry.client_span(:get_acl, %{session: session, path: path}, fn ->
      request = %Proto.GetACLRequest{path: IO.chardata_to_string(path)}

      case send_request(session, :get_acl, request, timeout) do
        {:ok, %Proto.GetACLResponse{acl: acl, stat: stat}} ->
          {{:ok, acl, stat}, %{acl: acl, stat: stat}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec set_acl(ref(), Path.t(), acl :: [ACL.t()], version(), timeout()) ::
          {:ok, Stat.t()} | {:error, Error.t()}
  def set_acl(session, path, acl, version \\ @any_version, timeout \\ @default_timeout)
      when is_version_or_nil(version) do
    Telemetry.client_span(
      :set_acl,
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

  @spec sync(ref(), Path.t(), timeout()) :: {:ok, Path.t()} | {:error, Error.t()}
  def sync(session, path, timeout \\ @default_timeout) do
    Telemetry.client_span(:sync, %{session: session, path: path}, fn ->
      request = %Proto.SyncRequest{path: IO.chardata_to_string(path)}

      case send_request(session, :sync, request, timeout) do
        {:ok, %Proto.SyncResponse{path: path}} ->
          {{:ok, path}, %{path: path}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec multi(ref(), ops :: [Multi.Op.t()], timeout()) ::
          {[Multi.Result.t()]} | {:error, Error.t()}
  def multi(session, ops, timeout \\ @default_timeout) do
    Telemetry.client_span(:exists, %{session: session, ops: ops}, fn ->
      request = Multi.to_request(ops)

      case send_request(session, :multi, request, timeout) do
        {:ok, %Multi.Response{results: results}} ->
          {{:ok, results}, %{results: results}}

        {:error, err} ->
          {{:error, Error.new(err)}, %{error: err}}
      end
    end)
  end

  @spec add_watch(ref(), Path.t(), NodeWatcher.t(), recursive :: boolean(), timeout()) ::
          :ok | {:error, Error.t()}
  def add_watch(session, path, watcher \\ nil, recursive \\ false, timeout \\ @default_timeout) do
    Telemetry.client_span(:add_watch, %{session: session, path: path}, fn ->
      request = %Proto.AddWatchRequest{
        path: IO.chardata_to_string(path),
        mode: AddWatchMode.value!(if recursive, do: :persistent_recursive, else: :persistent)
      }

      watch_registration =
        if is_nil(watcher) do
          {:default_watcher, path, recursive}
        else
          WatchRegistration.persistent_watch_registration(path, watcher, recursive: recursive)
        end

      case send_request(session, :add_watch, request, watch_registration, timeout) do
        :ok ->
          {:ok, %{}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec remove_watch(ref(), Path.t(), Watcher.Type.t(), NodeWatcher.t(), timeout()) ::
          :ok | {:error, Error.t()}
  def remove_watch(session, path, type, watcher, timeout \\ @default_timeout)
      when is_type(type) and watcher != nil do
    path = IO.chardata_to_string(path)

    Telemetry.client_span(:check_watches, %{session: session, path: path}, fn ->
      request = %Proto.CheckWatchesRequest{
        path: path,
        type: Watcher.Type.value!(type)
      }

      case send_request(session, :check_watches, request, timeout) do
        :ok ->
          {:ok, %{}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec remove_all_watches(ref(), Path.t(), Watcher.Type.t(), timeout()) ::
          :ok | {:error, Error.t()}
  def remove_all_watches(session, path, type, timeout \\ @default_timeout) when is_type(type) do
    path = IO.chardata_to_string(path)

    Telemetry.client_span(:remove_watches, %{session: session, path: path}, fn ->
      request = %Proto.RemoveWatchesRequest{
        path: path,
        type: Watcher.Type.value!(type)
      }

      watch_deregistration = WatchDeregistration.new(type, path)

      case send_request(session, :remove_watches, request, nil, watch_deregistration, timeout) do
        :ok ->
          {:ok, %{}}

        {:error, err} ->
          {{:error, Error.new(err, path)}, %{error: err}}
      end
    end)
  end

  @spec whoami(ref(), timeout()) :: {:ok, [ClientInfo.t()]} | {:error, Error.t()}
  @spec whoami(atom() | pid() | {atom(), any()} | {:via, atom(), any()}) ::
          {:error, Error.t()} | {:ok, [ClientInfo.t()]}
  def whoami(session, timeout \\ @default_timeout) do
    Telemetry.client_span(:who_am_i, %{session: session}, fn ->
      case(send_request(session, :who_am_i, nil, timeout)) do
        {:ok, %Proto.WhoAmIResponse{client_info: client_info}} ->
          {{:ok, client_info}, %{client_info: client_info}}

        {:error, err} ->
          {{:error, Error.new(err)}, %{error: err}}
      end
    end)
  end

  ####
  ## Callbacks
  ##

  @impl true
  def callback_mode, do: [:state_functions, :state_enter]

  @impl true
  def init(opts) do
    span =
      Telemetry.start_span(:session, %{}, %{
        session: self(),
        name: opts[:name]
      })

    with {:ok, socket} <- Socket.start_link(self(), span, opts),
         {:ok, watch_manager} <- WatchManager.new(opts[:default_watcher]) do
      data = %__MODULE__{
        opts: opts,
        socket: socket,
        watch_manager: watch_manager,
        span: %{span | metadata: span.metadata |> Map.put(:socket, socket)}
      }

      if opts[:sync_connect] do
        sync_connect(data)
      else
        {:ok, :connecting, data}
      end
    end
  end

  @impl true
  def terminate(reason, _state, %__MODULE__{socket: socket, span: span}) do
    :ok = Socket.send_frame(socket, new_close_session_request())

    if is_pid(socket) and Process.alive?(socket) and reason == :normal do
      :ok = Socket.normal_stop(socket)
    end

    Telemetry.stop_span(span)
  end

  ####
  ## State functions
  ##

  # "Disconnected" state: the session is close and the socket is not alive.

  def disconnected(:enter, _old_state, %__MODULE__{opts: opts}),
    do: on_state_changed(:disconnected, opts[:state_watcher])

  def disconnected(
        {:timeout, :reconnect},
        _timer_info,
        %__MODULE__{opts: opts, span: span} = data
      ) do
    {:ok, socket} = Socket.start_link(self(), span, opts)

    {:next_state, :connecting, %{data | socket: socket}}
  end

  def disconnected(
        :info,
        {:disconnected, socket, error},
        %__MODULE__{socket: socket, span: span} = data
      ) do
    Telemetry.span_event(span, :disconnected, %{error: error})

    disconnect(%{data | connected_address: nil}, error)
  end

  def disconnected({:call, from}, :status, %__MODULE__{} = data) do
    :gen_statem.reply(
      from,
      {:disconnected, data |> Map.take([:backoff_current, :reconnect_times])}
    )

    :keep_state_and_data
  end

  # "Connecting" state: the session is on going and the socket is not alive.
  def connecting(:enter, _old_state, %__MODULE__{}), do: :keep_state_and_data

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
        {:disconnected, socket, error},
        %__MODULE__{socket: socket, span: span} = data
      ) do
    Telemetry.span_event(span, :disconnected, %{error: error})

    disconnect(data, error)
  end

  def connecting({:call, from}, :status, %__MODULE__{socket: socket} = _data) do
    :gen_statem.reply(from, {:connecting, %{socket: socket}})
    :keep_state_and_data
  end

  # "Connected" state: the session is up and the socket is alive.
  def connected(:enter, _old_state, %__MODULE__{opts: opts, readonly: readonly}),
    do:
      on_state_changed(
        if(readonly, do: :connected_readonly, else: :sync_connected),
        opts[:state_watcher]
      )

  def connected(
        :info,
        {:disconnected, socket, error},
        %__MODULE__{socket: socket, span: span} = data
      ) do
    Telemetry.span_event(span, :disconnected, %{error: error})

    disconnect(%{data | connected_address: nil}, error)
  end

  def connected(:info, {:frame, socket, frame}, %__MODULE__{socket: socket} = data),
    do: handle_frame(frame, data)

  def connected({:call, from}, :status, %__MODULE__{socket: socket, connected_address: addr}) do
    :gen_statem.reply(from, {:connected, %{socket: socket, addr: addr}})
    :keep_state_and_data
  end

  def connected({:call, from}, :info, %__MODULE__{} = data) do
    info = %Info{
      id: data.session_id,
      timeout: data.session_timeout,
      addr: data.connected_address,
      readonly: data.readonly,
      last_zxid: data.last_zxid
    }

    :gen_statem.reply(from, {:info, info})
    :keep_state_and_data
  end

  def connected(
        {:call, from},
        {:request, :add_watch, request, {:default_watcher, path, recursive},
         watch_deregistration},
        %__MODULE__{watch_manager: %WatchManager{default_watcher: default_watcher}} = data
      )
      when is_boolean(recursive) do
    watch_registration =
      if is_nil(default_watcher) do
        nil
      else
        WatchRegistration.persistent_watch_registration(path, default_watcher,
          recursive: recursive
        )
      end

    send_frame(data, :add_watch, request, watch_registration, watch_deregistration, from)
  end

  def connected(
        {:call, from},
        {:request, opcode, request, watch_registration, watch_deregistration},
        %__MODULE__{} = data
      ),
      do: send_frame(data, opcode, request, watch_registration, watch_deregistration, from)

  def connected(:cast, :send_ping, data), do: send_ping_request(data)
  def connected({:timeout, :send_ping}, %{}, data), do: send_ping_request(data)

  ####
  ## Private methods
  ##

  defp sync_connect(%__MODULE__{socket: socket} = data) do
    receive do
      {:connected, ^socket, connected} ->
        {data, action} = on_connected(data, socket, connected)

        {:ok, :connected, data, action}

      {:disconnected, ^socket, error} ->
        {:stop, error}
    end
  end

  defp on_connected(
         %__MODULE__{opts: opts, last_zxid: last_zxid, span: span} = data,
         socket,
         %Connected{
           addr: addr,
           session_timeout: session_timeout,
           session_id: session_id,
           readonly: readonly
         }
       ) do
    span = %{
      span
      | metadata:
          span.metadata |> Map.merge(%{session_id: format_session_id(session_id), addr: addr})
    }

    Telemetry.span_event(span, :connected)

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
        readonly: readonly,
        framer: %Framer{},
        backoff_current: nil,
        reconnect_times: nil,
        span: span
    }

    action = {{:timeout, :send_ping}, ping_interval(session_timeout), %{}}

    {data, action}
  end

  defp on_state_changed(_state, nil), do: :keep_state_and_data

  defp on_state_changed(state, watcher) do
    :ok = StateWatcher.state_changed(watcher, state)

    :keep_state_and_data
  end

  defp send_request(
         session,
         opcode,
         request,
         watch_registration \\ nil,
         watch_deregistration \\ nil,
         timeout
       )
       when is_op_code(opcode) do
    :gen_statem.call(
      session,
      {:request, opcode, request, watch_registration, watch_deregistration},
      timeout
    )
  end

  defp send_frame(
         %__MODULE__{socket: socket, framer: framer} = data,
         opcode,
         request,
         watch_registration,
         watch_deregistration,
         from
       ) do
    {:ok, frame, framer} =
      Framer.new_frame(framer, opcode, request, watch_registration, watch_deregistration, from)

    :ok = Socket.send_frame(socket, frame)
    {:keep_state, %{data | framer: framer}}
  end

  defp handle_frame(
         %Frame{response: :pong},
         %__MODULE__{session_timeout: session_timeout, span: span} = data
       ) do
    Telemetry.span_event(span, :pong, %{latency: ping_latency(data)})

    data = %__MODULE__{data | last_ping_sent: nil}
    action = {{:timeout, :send_ping}, ping_interval(session_timeout), %{}}

    {:keep_state, data, action}
  end

  defp handle_frame(
         %Frame{response: {:auth_failed, err}},
         %__MODULE__{opts: opts, span: span}
       ) do
    Telemetry.span_event(span, :auth_failed, %{}, %{error: as_err_code(err)})

    on_state_changed(:auth_failed, opts[:state_watcher])
  end

  defp handle_frame(
         %Frame{response: {:notification, %WatchedEvent{} = evt}},
         %__MODULE__{watch_manager: wm, span: span} = data
       ) do
    Telemetry.span_event(span, :notification, %{}, %{event: evt})

    wm = WatchManager.process_event(wm, evt)

    {:keep_state, %{data | watch_manager: wm}}
  end

  defp handle_frame(%Frame{reply_hdr: %ReplyHeader{xid: xid}}, %__MODULE__{} = data)
       when xid < 0 do
    Logger.warning(
      "Got unknown reply for session id #{format_session_id(data.session_id)} with with xid: #{xid}"
    )

    :keep_state_and_data
  end

  defp handle_frame(
         %Frame{reply_hdr: %ReplyHeader{zxid: zxid}} = frame,
         %__MODULE__{framer: framer, watch_manager: watch_manager, span: span} = data
       ) do
    case Framer.parse_reply(frame, framer) do
      {:ok, frame, watch_registration, watch_deregistration, {task, _} = from, framer} ->
        res = extract_response(frame)

        Telemetry.span_event(span, :task_stopped, %{}, %{
          task: task,
          frame: frame,
          reply: res
        })

        :gen_statem.reply(from, res)

        err =
          case res do
            {:error, err} -> err
            _ -> :ok
          end

        {_watchers, watch_manager} =
          watch_manager
          |> WatchManager.register(watch_registration, err)
          |> WatchManager.unregister(watch_deregistration)

        {:keep_state,
         %__MODULE__{data | framer: framer, last_zxid: zxid, watch_manager: watch_manager}}

      {:error, reason} ->
        disconnect(data, reason)
    end
  end

  defp extract_response(%Frame{reply_hdr: %ReplyHeader{err: err}}) when err != 0,
    do: {:error, as_err_code(err)}

  defp extract_response(%Frame{response: nil}), do: :ok
  defp extract_response(%Frame{response: response}), do: {:ok, response}

  defp as_err_code(err) do
    case ErrCode.cast(err) do
      {:ok, code} -> code
      :error -> err
    end
  end

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
    backoff_initial = data.opts[:backoff_initial] || @default_backoff_initial
    {backoff_initial, %{data | backoff_current: backoff_initial, reconnect_times: 1}}
  end

  @backoff_exponent 1.5

  defp next_backoff(%__MODULE__{opts: opts, reconnect_times: reconnect_times} = data) do
    next_exponential_backoff = round(data.backoff_current * @backoff_exponent)

    backoff_current =
      case opts[:backoff_max] || @default_backoff_max do
        :infinity -> next_exponential_backoff
        backoff_max -> min(next_exponential_backoff, backoff_max)
      end

    {backoff_current,
     %{data | backoff_current: backoff_current, reconnect_times: reconnect_times + 1}}
  end

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

  defp ping_latency(%__MODULE__{last_ping_sent: last_ping_sent}),
    do: %Duration{microsecond: {Time.diff(Time.utc_now(), last_ping_sent, :microsecond), 6}}

  @set_watches_max_length 128 * 1024

  defp new_set_watches_request(last_zxid, %WatchManager{} = watch_manager) do
    if WatchManager.empty?(watch_manager) do
      []
    else
      watch_manager
      |> WatchManager.watches()
      |> Stream.chunk_every(@set_watches_max_length)
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
