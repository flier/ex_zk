defmodule ExZk.Socket do
  use GenServer

  alias ExZk.Frame
  alias ExZk.Connector

  defstruct [
    :conn,
    :opts,
    :transport,
    :socket,
    :buffered
  ]

  @type t :: %__MODULE__{
          conn: pid(),
          opts: [option()],
          transport: module(),
          socket: socket(),
          buffered: binary()
        }

  @type option :: {:ssl, boolean()} | :gen_tcp.option()
  @type transport :: :gen_tcp | :ssl
  @type socket :: :gen_tcp.socket() | :ssl.sslsocket()

  ####
  ## Public API
  ##

  @spec start_link(conn :: pid(), [option()]) :: GenServer.on_start()
  def start_link(conn, opts) do
    GenServer.start_link(__MODULE__, {conn, opts}, [])
  end

  @spec normal_stop(sock :: GenServer.server()) :: :ok
  def normal_stop(sock) do
    GenServer.stop(sock, :normal)
  end

  @spec send_frame(sock :: GenServer.server(), frame :: Frame.t()) :: :ok
  def send_frame(sock, %Frame{} = frame) do
    GenServer.cast(sock, {:send, ExZk.Wire.pack(frame)})
  end

  ####
  ## Callbacks
  ##

  @impl true
  def init({conn, opts}) do
    state = %__MODULE__{
      conn: conn,
      opts: opts,
      transport: if(opts[:ssl], do: :ssl, else: :gen_tcp)
    }

    {:ok, state, {:continue, []}}
  end

  @impl true
  def handle_continue([], %{conn: conn, opts: opts, transport: transport} = state) do
    with {:ok, socket, connected} <- Connector.connect(conn, opts),
         :ok <- setopts(transport, socket, active: :once) do
      send(conn, {:connected, self(), connected})
      {:noreply, %{state | socket: socket}}
    else
      {:error, reason} -> stop(reason, state)
      {:stop, reason} -> stop(reason, state)
    end
  end

  @impl true
  def handle_info(msg, state)

  # Inbound data from the socket.
  def handle_info({transport, socket, data}, %__MODULE__{socket: socket} = state)
      when transport in [:tcp, :ssl] do
    :ok = setopts(transport, socket, active: :once)
    state = new_data(state, data)
    {:noreply, state}
  end

  # The socket was closed.
  def handle_info({:tcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    stop(:tcp_closed, state)
  end

  # A socket error occurred.
  def handle_info({:tcp_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    stop({:tcp_error, reason}, state)
  end

  # The socket was closed.
  def handle_info({:ssl_closed, socket}, %__MODULE__{socket: socket} = state) do
    stop(:ssl_closed, state)
  end

  # A socket error occurred.
  def handle_info({:ssl_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    stop({:ssl_error, reason}, state)
  end

  @impl true
  def handle_cast(
        {:send, packet},
        %__MODULE__{conn: conn, transport: transport, socket: socket} = state
      ) do
    case transport.send(socket, packet) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        :ok = transport.close(socket)

        send(conn, {:stopped, self(), reason})

        error =
          case transport do
            :ssl -> {:ssl_error, :closed}
            :gen_tcp -> {:tcp_error, :closed}
          end

        stop(error, state)
    end
  end

  ####
  ## Private methods
  ##

  defp setopts(:tcp, socket, opts), do: :inet.setopts(socket, opts)
  defp setopts(:gen_tcp, socket, opts), do: :inet.setopts(socket, opts)
  defp setopts(:ssl, socket, opts), do: :ssl.setopts(socket, opts)

  defp new_data(state, _data = ""), do: state

  defp new_data(
         %__MODULE__{conn: conn, buffered: nil} = state,
         <<sz::32, data::binary-size(sz), rest::binary>> = _data
       ) do
    frame = Frame.unpack(data)

    send(conn, {:frame, self(), frame})

    new_data(state, rest)
  end

  defp new_data(%__MODULE__{buffered: nil} = state, data) do
    %__MODULE__{state | buffered: data}
  end

  defp new_data(%__MODULE__{buffered: buffered} = state, data) do
    new_data(%__MODULE__{state | buffered: nil}, buffered <> data)
  end

  defp stop(reason, %__MODULE__{conn: conn} = state) do
    send(conn, {:stopped, self(), reason})
    {:stop, :normal, state}
  end
end
