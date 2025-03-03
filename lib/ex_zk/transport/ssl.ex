defmodule ExZk.Transport.SSL do
  @moduledoc """
  Defines a `ExZk.Transport` implementation based on TCP SSL sockets as provided by Erlang's `:ssl` module.
  """

  @type socket() :: :ssl.sslsocket()

  @behaviour ExZk.Transport

  @impl ExZk.Transport
  @spec close(socket()) :: ExZk.Transport.on_close()
  defdelegate close(socket), to: :ssl

  @impl ExZk.Transport
  @spec closed :: ExZk.Transport.on_closed()
  def closed, do: {:ssl_error, :closed}

  @impl ExZk.Transport
  @spec recv(socket(), non_neg_integer(), timeout()) :: ExZk.Transport.on_recv()
  defdelegate recv(socket, length, timeout), to: :ssl

  @impl ExZk.Transport
  @spec send(socket(), iodata()) :: ExZk.Transport.on_send()
  defdelegate send(socket, data), to: :ssl

  @impl ExZk.Transport
  @spec getopts(socket(), ExZk.Transport.socket_get_options()) :: ExZk.Transport.on_getopts()
  defdelegate getopts(socket, options), to: :ssl

  @impl ExZk.Transport
  @spec setopts(socket(), ExZk.Transport.socket_set_options()) :: ExZk.Transport.on_setopts()
  defdelegate setopts(socket, options), to: :ssl
end
