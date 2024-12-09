defmodule ExZk.Connector do
  import ExZk.Format

  ####
  ## Public API
  ##

  @spec connect(conn :: pid(), opts :: keyword()) ::
          {:ok, socket :: ExZk.Socket.socket(), connected_address :: String.t()}
          | {:error, term}
          | {:stop, term}
  def connect(conn, opts) when is_pid(conn) and is_list(opts) do
    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)

    transport = if opts[:ssl], do: :ssl, else: :gen_tcp
    socket_opts = build_socket_opts(transport, opts[:socket_opts])
    timeout = Keyword.fetch!(opts, :timeout)

    with {:ok, socket} <- transport.connect(host, port, socket_opts, timeout),
         :ok <- setup_socket_buffers(transport, socket) do
      # Here, we should stop if AUTHing or SELECTing a DB fails with a *semantic* error
      # because disconnecting and retrying doesn't make sense, but we should not
      # stop if the issue is at the network layer, because it might happen due to
      # a race condition where the network conn breaks after connecting but before
      # AUTH/SELECT.
      case auth(transport, socket, opts, timeout) do
        :ok ->
          {:ok, socket, format_host_and_port(host, port)}
          # {:error, %ExZk.Error{} = error} -> {:stop, error}
          # {:error, :extra_bytes_after_reply} -> {:stop, :extra_bytes_after_reply}
          # {:error, reason} -> {:error, reason}
      end
    end
  end

  @spec auth(transport :: module(), socket :: ExZk.Socket.socket(), opts :: keyword(), timeout()) ::
          :ok
  def auth(_transport, _socket, _opts, _timeout) do
    :ok
  end

  ####
  ## Private methods
  ##

  @socket_opts [:binary, active: false]
  @default_ssl_opts [verify: :verify_peer, depth: 3]

  defp build_socket_opts(:gen_tcp, user_socket_opts) do
    @socket_opts ++ user_socket_opts
  end

  defp build_socket_opts(:ssl, user_socket_opts) do
    # Needs to be dynamic to avoid compile-time warnings.
    ca_store_mod = CAStore

    default_opts =
      if Code.ensure_loaded?(ca_store_mod) do
        [{:cacertfile, ca_store_mod.file_path()} | @default_ssl_opts]
      else
        @default_ssl_opts
      end
      |> Keyword.drop(Keyword.keys(user_socket_opts))

    @socket_opts ++ user_socket_opts ++ default_opts
  end

  # Setups the `:buffer` option of the given socket.
  defp setup_socket_buffers(transport, socket) do
    inet_mod = if transport == :ssl, do: :ssl, else: :inet

    with {:ok, opts} <- inet_mod.getopts(socket, [:sndbuf, :recbuf, :buffer]) do
      sndbuf = Keyword.fetch!(opts, :sndbuf)
      recbuf = Keyword.fetch!(opts, :recbuf)
      buffer = Keyword.fetch!(opts, :buffer)
      inet_mod.setopts(socket, buffer: buffer |> max(sndbuf) |> max(recbuf))
    end
  end
end
