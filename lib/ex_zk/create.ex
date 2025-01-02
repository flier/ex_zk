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

  @type option :: op_option() | {:ttl, integer()}
  @type op_option :: {:acl, list(ACL.t())} | {:mode, Mode.t()}

  ####
  ## Public API
  ##

  @spec new_request(Path.t(), iodata(), opts :: [option()]) ::
          {OpCode.t(), Frame.request()}
  def new_request(path, data \\ "", opts \\ []) do
    acl = Keyword.get(opts, :acl, [])
    ttl = Keyword.get(opts, :ttl)

    mode =
      case Keyword.get(opts, :mode, :persistent) do
        :persistent when ttl != nil -> :persistent_with_ttl
        :persistent_sequential when ttl != nil -> :persistent_sequential_with_ttl
        mode -> mode
      end

    opcode =
      cond do
        ttl?(mode) -> :create_ttl
        container?(mode) -> :create_container
        true -> :create
      end

    request =
      if ttl?(mode) do
        %CreateTTLRequest{
          path: IO.chardata_to_string(path),
          data: IO.iodata_to_binary(data),
          acl: acl,
          flags: Mode.value!(mode),
          ttl: ttl || 0
        }
      else
        %CreateRequest{
          path: IO.chardata_to_string(path),
          data: IO.iodata_to_binary(data),
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
