defmodule ExZk.Task.Create do
  use Task

  import ExZk.TypedEnum

  alias ExZk.Defs.OpCode
  alias ExZk.Data.{ACL, Stat}
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

  @spec is_ephemeral(Mode.t()) :: boolean()
  def is_ephemeral(mode), do: mode in [:ephemeral, :ephemeral_sequential]

  @spec is_sequential(Mode.t()) :: boolean()
  def is_sequential(mode),
    do:
      mode in [
        :persistent_sequential,
        :ephemeral_sequential,
        :persistent_sequential_with_ttl
      ]

  @spec is_container(Mode.t()) :: boolean()
  def is_container(mode), do: mode == :container

  @spec is_ttl(Mode.t()) :: boolean()
  def is_ttl(mode), do: mode in [:persistent_with_ttl, :persistent_sequential_with_ttl]

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
        is_ttl(mode) -> :create_ttl
        is_container(mode) -> :create_container
        true -> :create
      end

    request =
      if is_ttl(mode) do
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
