defmodule ExZk.Error do
  alias ExZk.Defs.ErrCode

  @enforce_keys [:err]
  defstruct [:err, :path]

  @type t :: %__MODULE__{
          err: ErrCode.t() | integer(),
          path: Path.t() | nil
        }

  @spec new(ErrCode.t() | integer(), Path.t() | nil) :: t()
  def new(err, path \\ nil) do
    err =
      case ErrCode.cast(err) do
        {:ok, code} -> code
        :error -> err
      end

    %__MODULE__{err: err, path: path}
  end

  defimpl String.Chars do
    def to_string(%ExZk.Error{err: :no_node, path: path}), do: "Node does not exist: #{path}"

    def to_string(%ExZk.Error{err: :no_children_for_ephemerals, path: path}),
      do: "Ephemerals cannot have children: #{path}"

    def to_string(%ExZk.Error{err: :node_exists, path: path}), do: "Node already exists: #{path}"

    def to_string(%ExZk.Error{err: :not_empty, path: path}), do: "Node not empty: #{path}"

    def to_string(%ExZk.Error{err: :not_readonly, path: path}),
      do: "Not a read-only call: #{path}"

    def to_string(%ExZk.Error{err: :invalid_acl, path: path}), do: "Acl is not valid: #{path}"

    def to_string(%ExZk.Error{err: :no_auth, path: path}), do: "Insufficient permission: #{path}"

    def to_string(%ExZk.Error{err: :bad_arguments, path: path}),
      do: "Arguments are not valid: #{path}"

    def to_string(%ExZk.Error{err: :bad_version, path: path}),
      do: "version No is not valid: #{path}"

    def to_string(%ExZk.Error{err: :reconfig_in_progress}),
      do: "Another reconfiguration is in progress -- concurrent reconfigs not supported (yet)"

    def to_string(%ExZk.Error{err: :new_config_no_quorum}),
      do:
        "No quorum of new config is connected and up-to-date with the leader of last committed config"

    def to_string(%ExZk.Error{err: :quota_exceeded, path: path}),
      do: "Quota has exceeded: #{path}"

    def to_string(%ExZk.Error{err: err, path: path}), do: "#{err}: #{path}"
  end
end
