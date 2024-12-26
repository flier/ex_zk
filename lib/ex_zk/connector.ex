defmodule ExZk.Connector do
  import ExZk.Frame
  alias ExZk.Proto.ConnectResponse
  alias ExZk.{Auth, Format, Wire}

  defmodule Connected do
    defstruct [:addr, :session_timeout, :session_id, :passwd, :readonly]

    @type t :: %__MODULE__{
            addr: String.t(),
            session_timeout: timeout(),
            session_id: integer(),
            passwd: binary(),
            readonly: boolean() | nil
          }

    def new(addr, res) do
      %__MODULE__{
        addr: addr,
        session_timeout: res.time_out,
        session_id: res.session_id,
        passwd: res.passwd,
        readonly: res.read_only
      }
    end
  end

  ####
  ## Public API
  ##

  @spec connect(conn :: pid(), opts :: keyword()) ::
          {:ok, ExZk.Socket.socket(), Connected.t()}
          | {:error, term}
          | {:stop, term}
  def connect(conn, opts) when is_pid(conn) and is_list(opts) do
    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)

    transport = if opts[:ssl], do: :ssl, else: :gen_tcp
    socket_opts = build_socket_opts(transport, Keyword.get(opts, :socket_opts, []))
    timeout = Keyword.fetch!(opts, :timeout)

    with {:ok, socket} <- transport.connect(String.to_charlist(host), port, socket_opts, timeout),
         :ok <- setup_socket_buffers(transport, socket) do
      case negotiate(transport, socket, opts, timeout) do
        {:ok, res} ->
          {:ok, socket, Connected.new(Format.format_host_and_port(host, port), res)}

        {:error, %ExZk.Error{} = error} ->
          {:stop, error}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @spec negotiate(
          transport :: module(),
          socket :: :inet.socket(),
          opts :: keyword(),
          timeout()
        ) ::
          {:ok, ConnectResponse.t()} | {:error, term} | {:stop, term}
  def negotiate(transport, socket, opts, timeout) do
    with :ok <- send_connect_request(transport, socket, opts),
         {:ok, res} <- recv_connect_response(transport, socket, timeout),
         :ok <- maybe_auth(transport, socket, opts) do
      {:ok, res}
    end
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

  defp send_connect_request(transport, socket, opts) do
    frame =
      new_connect_request(
        opts[:last_zxid] || 0,
        opts[:session_timeout] || 0,
        opts[:session_id] || 0,
        opts[:password] || "",
        opts[:readonly]
      )

    data = Wire.pack(frame)

    transport.send(socket, data)
  end

  defp maybe_auth(transport, socket, opts) do
    case new_auth_request(opts[:auth_info]) |> Enum.map_join(&Wire.pack(&1)) do
      "" -> :ok
      data -> transport.send(socket, data)
    end
  end

  defp new_auth_request(nil), do: []

  defp new_auth_request(auth_info) when is_list(auth_info) do
    auth_info |> Enum.flat_map(&new_auth_request(&1))
  end

  defp new_auth_request({:digest, {username, password}}),
    do: new_auth_request(Auth.digest(username, password))

  defp new_auth_request({:ip, addr}) when is_binary(addr) or is_tuple(addr),
    do: new_auth_request(Auth.ip(addr))

  defp new_auth_request({:x509, subject}) when is_binary(subject),
    do: new_auth_request(Auth.x509(subject))

  defp new_auth_request(%Auth.Info{scheme: scheme, data: data}),
    do: [new_auth_packet(scheme, data)]

  defp recv_connect_response(transport, socket, timeout, buffered \\ <<>>) do
    with {:ok, data} <- transport.recv(socket, 0, timeout) do
      case buffered <> data do
        <<sz::32, data::binary-size(sz), rest::binary>> ->
          if byte_size(rest) == 0 do
            {:ok, res, _rest} = ConnectResponse.unpack(data)
            {:ok, res}
          else
            {:error, :extra_bytes_after_reply}
          end

        buffered ->
          recv_connect_response(transport, socket, timeout, buffered)
      end
    end
  end
end
