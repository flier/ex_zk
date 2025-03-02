defmodule ExZk.Socket do
  use GenServer

  alias ExZk.Wire.Unpack
  alias ExZk.{Connector, Frame, Transport}

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
    :buffered
  ]

  @type t :: %__MODULE__{
          session: Process.dest(),
          opts: [option()],
          transport_module: module(),
          socket: Transport.socket(),
          buffered: binary()
        }

  @type option :: {:ssl, boolean()} | :gen_tcp.option()

  ####
  ## Public API
  ##

  @spec start_link(session :: Process.dest(), [option()]) :: GenServer.on_start()
  def start_link(session, opts) do
    GenServer.start_link(__MODULE__, {session, opts}, [])
  end

  @spec normal_stop(sock :: GenServer.server()) :: :ok
  def normal_stop(sock) do
    GenServer.stop(sock, :normal)
  end

  @spec send_frame(sock :: GenServer.server(), frame :: Frame.t()) :: :ok
  def send_frame(sock, %Frame{} = frame) do
    data = ExZk.Wire.pack(frame)

    :telemetry.execute(
      [:ex_zk, :socket, :send],
      %{system_time: System.system_time(), size: byte_size(data)},
      %{
        socket: sock,
        frame: frame,
        data: data
      }
    )

    GenServer.cast(sock, {:send, data})
  end

  ####
  ## Callbacks
  ##

  @impl true
  def init({session, opts}) do
    state = %__MODULE__{
      session: session,
      opts: opts,
      transport_module: if(opts[:ssl], do: ExZk.Transport.SSL, else: ExZk.Transport.TCP)
    }

    {:ok, state, {:continue, []}}
  end

  @impl true
  def handle_continue(
        [],
        %{session: session, opts: opts, transport_module: transport_module} = state
      ) do
    with {:ok, socket, connected} <- Connector.connect(session, opts),
         :ok <- transport_module.setopts(socket, active: :once) do
      send(session, {:connected, self(), connected})
      {:noreply, %{state | socket: socket}}
    else
      {:error, reason} -> stop(reason, state)
      {:stop, reason} -> stop(reason, state)
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
    stop(:tcp_closed, state)
  end

  # A socket error occurred.
  def handle_info({:tcp_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    stop(reason, state)
  end

  # The socket was closed.
  def handle_info({:ssl_closed, socket}, %__MODULE__{socket: socket} = state) do
    stop(:ssl_closed, state)
  end

  # A socket error occurred.
  def handle_info({:ssl_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    stop(reason, state)
  end

  @impl true
  def handle_cast(
        {:send, packet},
        %__MODULE__{session: session, transport_module: transport_module, socket: socket} = state
      ) do
    case transport_module.send(socket, packet) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        :ok = transport_module.close(socket)

        send(session, {:disconnected, self(), %Error{reason: reason}})

        stop(transport_module.closed(), state)
    end
  end

  ####
  ## Private methods
  ##

  defp handle_data(%__MODULE__{} = state, "" = _data), do: state

  defp handle_data(
         %__MODULE__{session: session, buffered: nil} = state,
         <<sz::32, data::binary-size(sz), rest::binary>> = _data
       ) do
    {:ok, frame, _rest} = Unpack.unpack(%Frame{}, data)

    :telemetry.execute(
      [:ex_zk, :socket, :recv],
      %{system_time: System.system_time(), size: byte_size(data)},
      %{
        socket: self(),
        frame: frame,
        data: data
      }
    )

    send(session, {:frame, self(), frame})

    handle_data(state, rest)
  end

  defp handle_data(%__MODULE__{buffered: nil} = state, data) do
    %__MODULE__{state | buffered: data}
  end

  defp handle_data(%__MODULE__{buffered: buffered} = state, data) do
    handle_data(%__MODULE__{state | buffered: nil}, buffered <> data)
  end

  defp stop(reason, %__MODULE__{session: session} = state) do
    send(session, {:disconnected, self(), %Error{reason: reason}})

    {:stop, :normal, state}
  end
end
