defmodule ExZk.Create do
  import ExZk.TypedEnum

  alias ExZk.Data.ACL
  alias ExZk.Defs.OpCode
  alias ExZk.Frame

  alias ExZk.Proto.{
    CreateRequest,
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

  @spec new_request(path :: String.t(), data :: binary(), opts :: [option()]) ::
          {OpCode.t(), Frame.request()}
  def new_request(path, data \\ "", opts \\ []) do
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
end
