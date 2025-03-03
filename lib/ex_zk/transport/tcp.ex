defmodule ExZk.Transport.TCP do
  @moduledoc """
  Defines a `ExZk.Transport` implementation based on clear TCP sockets as provided by Erlang's `:gen_tcp` module.
  """

  @type socket :: :inet.socket()
  @type addr :: :inet.socket_address() | :inet.hostname()
  @type socket_connect_options :: [:inet.inet_backend() | :gen_tcp.connect_option()]

  @socket_opts [:binary, active: false]

  @behaviour ExZk.Transport

  @impl ExZk.Transport
  @spec connect(addr(), port :: :inet.port_number(), socket_connect_options(), timeout()) ::
          ExZk.Transport.on_connect()
  def connect(addr, port, opts, timeout),
    do: :gen_tcp.connect(addr, port, @socket_opts ++ opts, timeout)

  @impl ExZk.Transport
  @spec close(socket()) :: :ok
  defdelegate close(socket), to: :gen_tcp

  @impl ExZk.Transport
  @spec closed :: ExZk.Transport.on_closed()
  def closed, do: {:tcp_error, :closed}

  @impl ExZk.Transport
  @spec recv(socket(), length :: non_neg_integer(), timeout()) :: ExZk.Transport.on_recv()
  defdelegate recv(socket, length, timeout), to: :gen_tcp

  @impl ExZk.Transport
  @spec send(socket(), packet :: iodata()) :: ExZk.Transport.on_send()
  defdelegate send(socket, data), to: :gen_tcp

  @impl ExZk.Transport
  @spec getopts(socket(), ExZk.Transport.socket_get_options()) :: ExZk.Transport.on_getopts()
  defdelegate getopts(socket, options), to: :inet

  @impl ExZk.Transport
  @spec setopts(socket(), ExZk.Transport.socket_set_options()) :: ExZk.Transport.on_setopts()
  defdelegate setopts(socket, options), to: :inet
end
