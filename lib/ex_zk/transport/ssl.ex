defmodule ExZk.Transport.SSL do
  @moduledoc """
  Defines a `ExZk.Transport` implementation based on TCP SSL sockets as provided by Erlang's `:ssl` module.
  """

  @type socket() :: :ssl.sslsocket()
  @type host() :: :ssl.host()
  @type socket_connect_options() :: [:ssl.tls_client_option()]

  @socket_opts [:binary, active: false]
  @default_ssl_opts [verify: :verify_peer, depth: 3]

  @behaviour ExZk.Transport

  @impl ExZk.Transport
  @spec connect(host(), port :: :inet.port_number(), socket_connect_options(), timeout()) ::
          ExZk.Transport.on_connect()
  def connect(host, port, opts, timeout) do
    # Needs to be dynamic to avoid compile-time warnings.
    ca_store_mod = CAStore

    default_opts =
      if Code.ensure_loaded?(ca_store_mod) do
        [{:cacertfile, ca_store_mod.file_path()} | @default_ssl_opts]
      else
        @default_ssl_opts
      end
      |> Keyword.drop(Keyword.keys(opts))

    :ssl.connect(host, port, @socket_opts ++ opts ++ default_opts, timeout)
  end

  @impl ExZk.Transport
  @spec close(socket()) :: ExZk.Transport.on_close()
  defdelegate close(socket), to: :ssl

  @impl ExZk.Transport
  @spec closed :: ExZk.Transport.on_closed()
  def closed, do: {:ssl_error, :closed}

  @impl ExZk.Transport
  @spec recv(socket(), length :: non_neg_integer(), timeout()) :: ExZk.Transport.on_recv()
  defdelegate recv(socket, length, timeout), to: :ssl

  @impl ExZk.Transport
  @spec send(socket(), packet :: iodata()) :: ExZk.Transport.on_send()
  defdelegate send(socket, data), to: :ssl

  @impl ExZk.Transport
  @spec getopts(socket(), ExZk.Transport.socket_get_options()) :: ExZk.Transport.on_getopts()
  defdelegate getopts(socket, options), to: :ssl

  @impl ExZk.Transport
  @spec setopts(socket(), ExZk.Transport.socket_set_options()) :: ExZk.Transport.on_setopts()
  defdelegate setopts(socket, options), to: :ssl
end
