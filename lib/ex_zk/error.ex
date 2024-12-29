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
    def to_string(%ExZk.Error{err: err, path: path}) do
      case err do
        :no_node ->
          "Node does not exist: #{path}"

        :no_children_for_ephemerals ->
          "Ephemerals cannot have children: #{path}"

        :node_exists ->
          "Node already exists: #{path}"

        :not_empty ->
          "Node not empty: #{path}"

        :not_readonly ->
          "Not a read-only call: #{path}"

        :invalid_acl ->
          "Acl is not valid: #{path}"

        :no_auth ->
          "Insufficient permission: #{path}"

        :bad_arguments ->
          "Arguments are not valid: #{path}"

        :bad_version ->
          "version No is not valid: #{path}"

        :reconfig_in_progress ->
          "Another reconfiguration is in progress -- concurrent reconfigs not supported (yet)"

        :new_config_no_quorum ->
          "No quorum of new config is connected and up-to-date with the leader of last committed config"

        :quota_exceeded ->
          "Quota has exceeded: #{path}"

        _ ->
          "#{err}: #{path}"
      end
    end
  end
end
