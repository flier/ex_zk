defmodule ExZk.Logger do
  @moduledoc """
  Instrumenter to handle logging of various instrumentation events.

  ## Instrumentation

  ExZk uses the `:telemetry` library for instrumentation.
  The following events are published by ExZk with the following measurements and metadata:

    * `[:ex_zk, :session, :connected]` - dispatched by `ExZk.Session` after the session has been established
      * Measurement: `%{system_time: system_time}`
      * Metadata: `%{session: pid(), name: String.t(), session_id: integer(), addr: String.t(), socket: pid()}`

    * `[:ex_zk, :session, :disconnected]` - dispatched by `ExZk.Session` after the session has been disconnected
      * Measurement: `%{system_time: system_time}`
      * Metadata: `%{session: pid(), name: String.t(), session_id: integer(), addr: String.t(), socket: pid()}`

    * `[:ex_zk, :session, :pong]` - dispatched by `ExZk.Session` after a pong has been received
      * Measurement: `%{latency: Duration.t()}`
      * Metadata: `%{session: pid(), name: String.t(), session_id: integer(), addr: String.t(), socket: pid()}`

    * `[:ex_zk, :session, :task, :stop]` - dispatched by `ExZk.Session` after a task has been completed
      * Measurement: `%{system_time: system_time}`
      * Metadata: `%{session: pid(), name: String.t(), session_id: integer(), task: pid(), frame: ExZk.Frame.t(), reply: term()}`

    * `[:ex_zk, :socket, :send]` - dispatched by `ExZk.Socket` after a packet has been sent
      * Measurement: `%{system_time: system_time, size: non_neg_integer()}`
      * Metadata: `%{socket: pid(), frame: ExZk.Frame.t(), data: binary()}`

    * `[:ex_zk, :socket, :recv]` - dispatched by `ExZk.Socket` after a packet has been received
      * Measurement: `%{system_time: system_time, size: non_neg_integer()}`
      * Metadata: `%{socket: pid(), frame: ExZk.Frame.t(), data: binary()}`

  """

  require Logger

  ####
  ## Public API
  ##

  @doc false
  def install(opts \\ []) do
    handlers = %{
      [:ex_zk, :session, :connected] => &__MODULE__.session_connected/4,
      [:ex_zk, :session, :disconnected] => &__MODULE__.session_disconnected/4,
      [:ex_zk, :session, :pong] => &__MODULE__.session_ping/4,
      [:ex_zk, :session, :task, :stop] => &__MODULE__.session_task_completed/4,
      [:ex_zk, :socket, :send] => &__MODULE__.socket_send/4,
      [:ex_zk, :socket, :recv] => &__MODULE__.socket_recv/4
    }

    for {key, fun} <- handlers do
      :telemetry.attach({__MODULE__, key}, key, fun, opts)
    end
  end

  ####
  ## Events
  ##

  @doc false
  def session_connected(
        _name,
        _measurements,
        %{session: session, session_id: session_id, addr: addr, socket: socket} = _metadata,
        opts
      ) do
    case log_level(opts[:log], session) do
      false ->
        :ok

      level ->
        Logger.log(level,
          session: [pid: session, id: session_id, state: :connected],
          socket: [pid: socket, addr: addr]
        )
    end
  end

  @doc false
  def session_disconnected(
        _name,
        _measurements,
        %{session: session, session_id: session_id} = _metadata,
        opts
      ) do
    case log_level(opts[:log], session) do
      false ->
        :ok

      level ->
        Logger.log(level, session: [pid: session, id: session_id], state: :disconnected)
    end
  end

  @doc false
  def session_ping(
        _name,
        %{latency: latency} = _measurements,
        %{session: session, session_id: session_id} = _metadata,
        opts
      ) do
    case log_level(opts[:log] || :debug, session) do
      false ->
        :ok

      level ->
        Logger.log(level,
          session: [pid: session, id: session_id],
          ping: [latency: latency |> Duration.to_iso8601()]
        )
    end
  end

  @doc false
  def session_task_completed(
        _name,
        _measurements,
        %{session: session, session_id: session_id, task: task, frame: frame, reply: reply} =
          _metadata,
        opts
      ) do
    case log_level(opts[:log] || :debug, session) do
      false ->
        :ok

      level ->
        Logger.log(level,
          session: [pid: session, id: session_id],
          task: task,
          frame: frame,
          reply: reply
        )
    end
  end

  @doc false
  def socket_send(
        _name,
        _measurements,
        %{socket: socket, frame: frame} = _metadata,
        opts
      ) do
    case log_level(opts[:log] || :debug, socket) do
      false ->
        :ok

      level ->
        Logger.log(level, socket: socket, send: frame)
    end
  end

  @doc false
  def socket_recv(
        _name,
        _measurements,
        %{socket: socket, frame: frame} = _metadata,
        opts
      ) do
    case log_level(opts[:log] || :debug, socket) do
      false ->
        :ok

      level ->
        Logger.log(level, socket: socket, recv: frame)
    end
  end

  defp log_level(nil, _session), do: :info
  defp log_level(level, _session) when is_atom(level), do: level

  defp log_level({mod, fun, args}, session)
       when is_atom(mod) and is_atom(fun) and is_list(args),
       do: apply(mod, fun, [session | args])
end
