defmodule ExZk.Connector do
  import ExZk.Frame

  alias ExZk.{
    Auth,
    Format,
    Proto.ConnectResponse,
    Wire,
    Wire.Unpack
  }

  defmodule Connected do
    defstruct [:addr, :session_timeout, :session_id, :passwd, :readonly]

    @type t :: %__MODULE__{
            addr: String.t(),
            session_timeout: timeout(),
            session_id: ExZk.Session.id(),
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

  @spec connect(session :: Process.dest(), opts :: keyword()) ::
          {:ok, ExZk.Transport.socket(), Connected.t()}
          | {:error, term}
          | {:stop, term}
  def connect(session, opts) when is_pid(session) and is_list(opts) do
    {transport_module, transport_opts} =
      Keyword.get(
        opts,
        :transport_module,
        {if(opts[:ssl], do: ExZk.Transport.SSL, else: ExZk.Transport.TCP), []}
      )

    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)
    timeout = Keyword.fetch!(opts, :timeout)

    with {:ok, socket} <-
           transport_module.connect(host, port, transport_opts, timeout),
         :ok <- setup_socket_buffers(transport_module, socket),
         {:ok, res} <- negotiate(transport_module, socket, opts, timeout) do
      {:ok, socket, Connected.new(Format.format_host_and_port(host, port), res)}
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

  # Setups the `:buffer` option of the given socket.
  defp setup_socket_buffers(transport, socket) do
    with {:ok, opts} <- transport.getopts(socket, [:sndbuf, :recbuf, :buffer]) do
      sndbuf = Keyword.fetch!(opts, :sndbuf)
      recbuf = Keyword.fetch!(opts, :recbuf)
      buffer = Keyword.fetch!(opts, :buffer)

      transport.setopts(socket, buffer: buffer |> max(sndbuf) |> max(recbuf))
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
    with {:ok, data} <- transport.recv(socket, 0, timeout),
         data <- buffered <> data,
         {:error, :not_enough_data} <- parse_connect_response(data) do
      recv_connect_response(transport, socket, timeout, data)
    end
  end

  defp parse_connect_response(<<sz::32, data::binary-size(sz)>>) do
    with {:ok, res, _rest} <- Unpack.unpack(%ConnectResponse{}, data) do
      {:ok, res}
    end
  end

  defp parse_connect_response(<<sz::32, _data::binary-size(sz), _rest::binary>>),
    do: {:error, :extra_bytes_after_reply}

  defp parse_connect_response(_), do: {:error, :not_enough_data}
end
