defmodule ExZk.Task do
  defmodule Create do
    use Task

    import ExZk.TypedEnum

    alias ExZk.Data.{ACL, Stat}
    alias ExZk.Defs.OpCode
    alias ExZk.{Connection, Frame}

    alias ExZk.Proto.{
      Create2Response,
      CreateRequest,
      CreateResponse,
      CreateTTLRequest
    }

    defenum(Mode,
      persistent: 0,
      ephemeral: 1,
      persistent_sequential: 2,
      ephemeral_sequential: 3,
      container: 4,
      persistent_with_ttl: 5,
      persistent_sequential_with_ttl: 6
    )

    @type option ::
            {:acl, list(ACL.t())}
            | {:mode, Mode.t()}
            | {:ttl, integer()}

    ####
    ## Public API
    ##

    @spec start_link(
            :gen_statem.server_ref(),
            path :: String.t(),
            data :: binary(),
            opts :: [option()]
          ) ::
            {:ok, pid()}
    def start_link(conn, path, data \\ <<>>, opts \\ []) do
      Task.start_link(__MODULE__, :run, [conn, path, data, opts])
    end

    @spec ephemeral?(Mode.t()) :: boolean()
    def ephemeral?(mode), do: mode in [:ephemeral, :ephemeral_sequential]

    @spec sequential?(Mode.t()) :: boolean()
    def sequential?(mode),
      do:
        mode in [
          :persistent_sequential,
          :ephemeral_sequential,
          :persistent_sequential_with_ttl
        ]

    @spec container?(Mode.t()) :: boolean()
    def container?(mode), do: mode == :container

    @spec ttl?(Mode.t()) :: boolean()
    def ttl?(mode), do: mode in [:persistent_with_ttl, :persistent_sequential_with_ttl]

    @spec run(
            conn :: :gen_statem.server_ref(),
            path,
            data :: binary(),
            opts :: [option()]
          ) :: {:ok, path, Stat.t() | nil} | {:error, reason :: term()}
          when path: String.t()
    def run(conn, path, data, opts) do
      {opcode, request} = new_request(path, data, opts)
      :ok = Connection.send_request(conn, opcode, request)

      receive do
        {:ok, %CreateResponse{path: path}} ->
          {:ok, path, nil}

        {:ok, %Create2Response{path: path, stat: stat}} ->
          {:ok, path, stat}

        {:error, reason} ->
          {:error, reason}
      end
    end

    @spec new_request(path :: String.t(), data :: binary(), opts :: [option()]) ::
            {OpCode.t(), Frame.request()}
    def new_request(path, data, opts \\ []) do
      acl = Keyword.get(opts, :acl, [])
      mode = Keyword.get(opts, :mode, :persistent)
      ttl = Keyword.get(opts, :ttl, 0)

      opcode =
        cond do
          ttl?(mode) -> :create_ttl
          container?(mode) -> :create_container
          true -> :create
        end

      request =
        if ttl?(mode) do
          %CreateTTLRequest{
            path: path,
            data: data,
            acl: acl,
            flags: Mode.value!(mode),
            ttl: ttl
          }
        else
          %CreateRequest{
            path: path,
            data: data,
            acl: acl,
            flags: Mode.value!(mode)
          }
        end

      {opcode, request}
    end
  end

  defmodule Delete do
    use Task

    alias ExZk.Connection
    alias ExZk.Proto.DeleteRequest

    ####
    ## Public API
    ##

    @spec start_link(
            conn :: :gen_statem.server_ref(),
            path :: String.t(),
            version :: integer()
          ) ::
            {:ok, pid()}
    def start_link(conn, path, version \\ 0) do
      Task.start_link(__MODULE__, :run, [conn, path, version])
    end

    @spec run(conn :: :gen_statem.server_ref(), path :: String.t(), version :: integer() | nil) ::
            :ok | {:error, reason :: term()}
    def run(conn, path, version) do
      request = %DeleteRequest{path: path, version: version}

      :ok = Connection.send_request(conn, :delete, request)

      receive do
        {:ok, nil} ->
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule Exists do
    use Task

    alias ExZk.Connection
    alias ExZk.Data.Stat
    alias ExZk.Proto.{ExistsRequest, ExistsResponse}

    ####
    ## Public API
    ##

    @spec start_link(conn :: :gen_statem.server_ref(), path :: String.t()) :: {:ok, pid()}
    def start_link(conn, path) do
      Task.start_link(__MODULE__, :run, [conn, path])
    end

    @spec run(conn :: :gen_statem.server_ref(), path :: String.t()) ::
            {:ok, boolean(), Stat.t()} | {:error, reason :: term()}
    def run(conn, path) do
      request = %ExistsRequest{path: path}

      :ok = Connection.send_request(conn, :exists, request)

      receive do
        {:ok, %ExistsResponse{stat: stat}} ->
          {:ok, true, stat}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
