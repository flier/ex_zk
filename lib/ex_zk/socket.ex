defmodule ExZk.Socket do
  use GenServer

  alias ExZk.Wire.Unpack
  alias ExZk.{Connector, Frame, Telemetry, Transport}

  defmodule Error do
    @moduledoc """
    Error raised when the connection is closed.

    ## Example

        iex> raise %ExZk.Socket.Error{reason: :tcp_closed}
        ** (ExZk.Socket.Error) TCP connection closed

        iex> raise %ExZk.Socket.Error{reason: :ssl_closed}
        ** (ExZk.Socket.Error) SSL connection closed

        iex> raise %ExZk.Socket.Error{reason: :closed}
        ** (ExZk.Socket.Error) the connection to Zookeeper is closed

        iex> raise %ExZk.Socket.Error{reason: :eacces}
        ** (ExZk.Socket.Error) permission denied
    """

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

  defstruct [
    :session,
    :opts,
    :transport_module,
    :socket,
    :buffered,
    :span
  ]

  @type t :: %__MODULE__{
          session: Process.dest(),
          opts: [option()],
          transport_module: module(),
          socket: Transport.socket(),
          buffered: binary(),
          span: Telemetry.t()
        }

  @type option :: {:ssl, boolean()} | :gen_tcp.option()

  ####
  ## Public API
  ##

  @spec start_link(session :: Process.dest(), session_span :: Telemetry.t(), [option()]) ::
          GenServer.on_start()
  def start_link(session, session_span, opts \\ []) do
    GenServer.start_link(__MODULE__, {session, session_span, opts}, [])
  end

  @spec normal_stop(sock :: GenServer.server()) :: :ok
  def normal_stop(sock) do
    GenServer.stop(sock, :normal)
  end

  @spec send_frame(sock :: GenServer.server(), frame :: Frame.t()) :: :ok
  def send_frame(sock, %Frame{} = frame) do
    GenServer.cast(sock, {:send, frame})
  end

  ####
  ## Callbacks
  ##

  @impl true
  def init({session, session_span, opts}) do
    {transport_module, _args} =
      Keyword.get(
        opts,
        :transport_module,
        {if(opts[:ssl], do: ExZk.Transport.SSL, else: ExZk.Transport.TCP), []}
      )

    span =
      Telemetry.start_child_span(session_span, :socket, %{}, %{
        transport_module: transport_module
      })

    state = %__MODULE__{
      session: session,
      opts: opts,
      transport_module: transport_module,
      span: span
    }

    {:ok, state, {:continue, []}}
  end

  @impl true
  def handle_continue(
        [],
        %{session: session, opts: opts, transport_module: transport_module, span: span} = state
      ) do
    with {:ok, socket, connected} <- Connector.connect(session, opts),
         :ok <- transport_module.setopts(socket, active: :once) do
      span =
        span
        |> Map.put(
          :metadata,
          span.metadata |> Map.merge(%{socket: socket, peer_addr: connected.addr})
        )

      Telemetry.span_event(span, :connected)

      send(session, {:connected, self(), connected})

      {:noreply, %{state | socket: socket, span: span}}
    else
      {:error, reason} -> stop(:connect_error, reason, state)
      {:stop, reason} -> stop(:connect_error, reason, state)
    end
  end

  @impl true
  def handle_info(msg, state)

  # Inbound data from the socket.
  def handle_info(
        {transport, socket, data},
        %__MODULE__{transport_module: transport_module, socket: socket} = state
      )
      when transport in [:tcp, :ssl] do
    :ok = transport_module.setopts(socket, active: :once)

    state = handle_data(state, data)

    {:noreply, state}
  end

  # The socket was closed.
  def handle_info({:tcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    stop(:recv_error, :tcp_closed, state)
  end

  # A socket error occurred.
  def handle_info({:tcp_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    stop(:recv_error, reason, state)
  end

  # The socket was closed.
  def handle_info({:ssl_closed, socket}, %__MODULE__{socket: socket} = state) do
    stop(:recv_error, :ssl_closed, state)
  end

  # A socket error occurred.
  def handle_info({:ssl_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    stop(:recv_error, reason, state)
  end

  @impl true
  def handle_cast(
        {:send, frame},
        %__MODULE__{
          session: session,
          transport_module: transport_module,
          socket: socket,
          span: span
        } = state
      ) do
    data = ExZk.Wire.pack(frame)

    Telemetry.untimed_span_event(span, :send, %{size: byte_size(data)}, %{
      frame: frame,
      data: data
    })

    case transport_module.send(socket, data) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        :ok = transport_module.close(socket)

        send(session, {:disconnected, self(), %Error{reason: reason}})

        stop(:send_error, transport_module.closed(), state)
    end
  end

  @impl true
  def terminate(reason, %__MODULE__{span: span}) do
    Telemetry.stop_span(span, %{}, %{reason: reason})
  end

  ####
  ## Private methods
  ##

  defp handle_data(%__MODULE__{} = state, "" = _data), do: state

  defp handle_data(
         %__MODULE__{session: session, buffered: nil, span: span} = state,
         <<sz::32, data::binary-size(sz), rest::binary>> = _data
       ) do
    {:ok, frame, _rest} = Unpack.unpack(%Frame{}, data)

    Telemetry.untimed_span_event(span, :recv, %{size: byte_size(data)}, %{
      frame: frame,
      data: data
    })

    send(session, {:frame, self(), frame})

    handle_data(state, rest)
  end

  defp handle_data(%__MODULE__{buffered: nil} = state, data) do
    %__MODULE__{state | buffered: data}
  end

  defp handle_data(%__MODULE__{buffered: buffered} = state, data) do
    handle_data(%__MODULE__{state | buffered: nil}, buffered <> data)
  end

  defp stop(event, reason, %__MODULE__{session: session, span: span} = state) do
    Telemetry.span_event(span, event, %{error: reason})

    send(session, {:disconnected, self(), %Error{reason: reason}})

    {:stop, :normal, state}
  end
end
