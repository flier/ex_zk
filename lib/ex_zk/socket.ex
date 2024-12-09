defmodule ExZk.Socket do
  use GenServer

  alias ExZk.Connector

  defstruct [
    :conn,
    :opts,
    :transport,
    :socket
  ]

  @type t :: %__MODULE__{
          conn: pid(),
          opts: [option()],
          transport: module(),
          socket: socket()
        }

  @type option :: {:ssl, boolean()} | :gen_tcp.option()
  @type transport :: :gen_tcp | :ssl
  @type socket :: :gen_tcp.socket() | :ssl.sslsocket()

  ####
  ## Public API
  ##

  @spec start_link(pid(), [option()]) :: GenServer.on_start()
  def start_link(conn, opts) do
    GenServer.start_link(__MODULE__, {conn, opts}, [])
  end

  @spec normal_stop(GenServer.server()) :: :ok
  def normal_stop(sock) do
    GenServer.stop(sock, :normal)
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
    with {:ok, socket, address} <- Connector.connect(conn, opts),
         :ok <- setopts(transport, socket, active: :once) do
      send(conn, {:connected, self(), socket, address})
      {:noreply, %{state | socket: socket}}
    else
      {:error, reason} -> stop(reason, state)
      {:stop, reason} -> stop(reason, state)
    end
  end

  ####
  ## Private methods
  ##

  defp setopts(:ssl, socket, opts), do: :ssl.setopts(socket, opts)
  defp setopts(:gen_tcp, socket, opts), do: :inet.setopts(socket, opts)

  defp stop(reason, %__MODULE__{conn: conn} = state) do
    send(conn, {:stopped, self(), reason})
    {:stop, :normal, state}
  end
end
