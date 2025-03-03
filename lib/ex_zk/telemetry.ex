defmodule ExZk.Telemetry do
  @moduledoc """
  The following events are published by ExZk with the following measurements and metadata:

  ## Session

  `[:ex_zk, :session, *]`

  Represents a ExZk session that connects to the Zookeeper cluster

  This span is started by the following event:

  * `[:ex_zk, :session, :connected]`

    dispatched by `ExZk.Session` after the session has been established

    This event contains the following measurements:

    * `monotonic_time` :: `integer()` The time of this event, in `:native` units

    This event contains the following metadata:

    * `telemetry_span_context`: A unique identifier for this span
    * `session` :: `pid()` The session process identifier
    * `name` :: `String.t()` The name of the session
    * `session_id` :: `integer()` The session identifier
    * `socket` :: `pid()` The socket process identifier
    * `addr` :: `String.t()` The address of the peer

  * `[:ex_zk, :session, :disconnected]`

    dispatched by `ExZk.Session` after the session has been disconnected

    This event contains the following measurements:

    * `monotonic_time` :: `integer()` The time of this event, in `:native` units
    * `error`: A description of the error

    This event contains the following metadata:

    * `telemetry_span_context`: A unique identifier for this span
    * `session` :: `pid()` The session process identifier
    * `name` :: `String.t()` The name of the session
    * `session_id` :: `integer()` The session identifier
    * `socket` :: `pid()` The socket process identifier
    * `addr` :: `String.t()` The address of the peer

  * `[:ex_zk, :session, :pong]`

    dispatched by `ExZk.Session` after a pong has been received

    This event contains the following measurements:

    * `latency` :: `Duration.t()` The latency time it took to receive the pong after the ping has been sent.

    This event contains the following metadata:

    * `telemetry_span_context`: A unique identifier for this span
    * `session` :: `pid()` The session process identifier
    * `name` :: `String.t()` The name of the session
    * `session_id` :: `integer()` The session identifier
    * `socket` :: `pid()` The socket process identifier
    * `addr` :: `String.t()` The address of the peer

  * `[:ex_zk, :session, :auth_failed]`

    dispatched by `ExZk.Session` after an authentication has failed

    This event contains the following measurements:

    * `monotonic_time` :: `integer()` The time of this event, in `:native` units

    This event contains the following metadata:

    * `telemetry_span_context`: A unique identifier for this span
    * `session` :: `pid()` The session process identifier
    * `name` :: `String.t()` The name of the session
    * `session_id` :: `integer()` The session identifier
    * `socket` :: `pid()` The socket process identifier
    * `addr` :: `String.t()` The address of the peer
    * `error` :: `ErrCode.t()` The error code associated with the authentication failure

  * `[:ex_zk, :session, :notification]`

    dispatched by `ExZk.Session` after a notification `ExZk.WatchedEvent` event has been received

    This event contains the following measurements:

    * `monotonic_time` :: `integer()` The time of this event, in `:native` units

    This event contains the following metadata:

    * `telemetry_span_context`: A unique identifier for this span
    * `session` :: `pid()` The session process identifier
    * `name` :: `String.t()` The name of the session
    * `session_id` :: `integer()` The session identifier
    * `socket` :: `pid()` The socket process identifier
    * `addr` :: `String.t()` The address of the peer
    * `event` :: `ExZk.WatchedEvent.t()` The notification event

  * `[:ex_zk, :session, :task_stopped]` -

    dispatched by `ExZk.Session` after a task has been completed

    This event contains the following measurements:

    * `monotonic_time` :: `integer()` The time of this event, in `:native` units

    This event contains the following metadata:

    * `telemetry_span_context`: A unique identifier for this span
    * `session` :: `pid()` The session process identifier
    * `name` :: `String.t()` The name of the session
    * `session_id` :: `integer()` The session identifier
    * `socket` :: `pid()` The socket process identifier
    * `addr` :: `String.t()` The address of the peer
    * `task` :: `pid()` The task process identifier
    * `frame` :: `ExZk.Frame.t()` The frame that was sent
    * `reply` :: `term()` The response to the frame

  ## Socket

  `[:ex_zk, :socket, *]`

  Represents a ExZk socket process

  This span is started by the following event:

   * `[:ex_zk, :socket, :connected]`

    dispatched by `ExZk.Socket` after the connection has been established

    This event contains the following measurements:

    * `monotonic_time` :: `integer()` The time of this event, in `:native` units

    This event contains the following metadata:

    * `parent_span_context`: A unique identifier for the parent span
    * `telemetry_span_context`: A unique identifier for this span
    * `socket` :: `pid()` The socket process identifier
    * `addr` :: `String.t()` The address of the peer

  * `[:ex_zk, :socket, :send]`

    dispatched by `ExZk.Socket` after a `ExZk.Frame` has been sent

    This event contains the following measurements:

    * `monotonic_time` :: `integer()` The time of this event, in `:native` units
    * `size` :: `non_neg_integer()` The size of the data in the frame

    This event contains the following metadata:

    * `parent_span_context`: A unique identifier for the parent span
    * `telemetry_span_context`: A unique identifier for this span
    * `socket` :: `pid()` The socket process identifier
    * `frame` :: `ExZk.Frame.t()` The frame that was sent
    * `data` :: `binary()` The data that was sent

  * `[:ex_zk, :socket, :recv]`

    dispatched by `ExZk.Socket` after a `ExZk.Frame` has been received

    This event contains the following measurements:

    * `monotonic_time` :: `integer()` The time of this event, in `:native` units
    * `size` :: `non_neg_integer()` The size of the data in the frame

    This event contains the following metadata:

    * `parent_span_context`: A unique identifier for the parent span
    * `telemetry_span_context`: A unique identifier for this span
    * `socket` :: `pid()` The socket process identifier
    * `frame` :: `ExZk.Frame.t()` The frame that was received
    * `data` :: `binary()` The data that was received

  * `[:ex_zk, :socket, :connect_error]`

    dispatched by `ExZk.Socket` encountered an error connecting to the server

    This event contains the following measurements:

    * `error`: A description of the error

    This event contains the following metadata:

    * `parent_span_context`: A unique identifier for the parent span
    * `telemetry_span_context`: A unique identifier for this span

  * `[:ex_zk, :socket, :send_error]`

    dispatched by `ExZk.Socket` encountered an error sending frame to the server

    This event contains the following measurements:

    * `error`: A description of the error

    This event contains the following metadata:

    * `parent_span_context`: A unique identifier for the parent span
    * `telemetry_span_context`: A unique identifier for this span

  * `[:ex_zk, :socket, :recv_error]`

    dispatched by `ExZk.Socket` encountered an error reading frame from the server

    This event contains the following measurements:

    * `error`: A description of the error

    This event contains the following metadata:

    * `parent_span_context`: A unique identifier for the parent span
    * `telemetry_span_context`: A unique identifier for this span

  """

  @enforce_keys [:span_name, :span_context, :start_time, :metadata]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          span_name: span_name(),
          span_context: reference(),
          start_time: integer(),
          metadata: metadata()
        }

  @app_name :ex_zk

  @type span_name :: :session | :socket

  @typedoc false
  @type event_name ::
          :connected
          | :disconnected
          | :pong
          | :auth_failed
          | :notification
          | :task_stopped
          | :connect_error
          | :recv_error
          | :send_error

  @typedoc false
  @type untimed_event_name :: :recv | :send | :stop

  @type metadata :: :telemetry.event_metadata()
  @type measurements :: :telemetry.event_measurements()

  @doc false
  @spec start_span(span_name(), measurements(), metadata()) :: t()
  def start_span(span_name, measurements \\ %{}, metadata \\ %{}) do
    measurements = Map.put_new_lazy(measurements, :monotonic_time, &monotonic_time/0)

    span_context = make_ref()
    metadata = Map.put(metadata, :telemetry_span_context, span_context)
    _ = event([span_name, :start], measurements, metadata)

    %__MODULE__{
      span_name: span_name,
      span_context: span_context,
      start_time: measurements[:monotonic_time],
      metadata: metadata
    }
  end

  @doc false
  @spec start_child_span(t(), span_name(), measurements(), metadata()) :: t()
  def start_child_span(
        %__MODULE__{span_context: parent_span_context},
        span_name,
        measurements \\ %{},
        metadata \\ %{}
      ) do
    metadata = metadata |> Map.put(:parent_span_context, parent_span_context)

    start_span(span_name, measurements, metadata)
  end

  @doc false
  @spec stop_span(t(), measurements(), metadata()) :: :ok
  def stop_span(span, measurements \\ %{}, metadata \\ %{}) do
    measurements = Map.put_new_lazy(measurements, :monotonic_time, &monotonic_time/0)

    measurements =
      Map.put(measurements, :duration, measurements[:monotonic_time] - span.start_time)

    metadata = Map.merge(span.metadata, metadata)

    untimed_span_event(span, :stop, measurements, metadata)
  end

  @doc false
  @spec span_event(t(), event_name(), measurements(), metadata()) :: :ok
  def span_event(span, name, measurements \\ %{}, metadata \\ %{}) do
    measurements = Map.put_new_lazy(measurements, :monotonic_time, &monotonic_time/0)

    untimed_span_event(span, name, measurements, metadata)
  end

  @doc false
  @spec untimed_span_event(t(), event_name() | untimed_event_name(), measurements(), metadata()) ::
          :ok
  def untimed_span_event(
        %__MODULE__{span_name: span_name, span_context: span_context},
        name,
        measurements \\ %{},
        metadata \\ %{}
      ) do
    metadata = metadata |> Map.put(:telemetry_span_context, span_context)

    event([span_name, name], measurements, metadata)
  end

  @spec monotonic_time() :: integer
  defdelegate monotonic_time, to: System

  defp event(suffix, measurements, metadata) do
    :telemetry.execute([@app_name | suffix], measurements, metadata)
  end
end
