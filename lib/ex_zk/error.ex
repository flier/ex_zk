defmodule ExZk.Error do
  @moduledoc """
  An error response from the Zookeeper server.

  ## Examples

      iex> ExZk.Error.new(:no_node, "/foo/bar") |> to_string()
      "Node does not exist: /foo/bar"

      iex> ExZk.Error.new(:no_children_for_ephemerals, "/foo/bar") |> to_string()
      "Ephemerals cannot have children: /foo/bar"

      iex> ExZk.Error.new(:node_exists, "/foo/bar") |> to_string()
      "Node already exists: /foo/bar"

      iex> ExZk.Error.new(:not_empty, "/foo/bar") |> to_string()
      "Node not empty: /foo/bar"

      iex> ExZk.Error.new(:not_readonly, "/foo/bar") |> to_string()
      "Not a read-only call: /foo/bar"

      iex> ExZk.Error.new(:invalid_acl, "/foo/bar") |> to_string()
      "Acl is not valid: /foo/bar"

      iex> ExZk.Error.new(:no_auth, "/foo/bar") |> to_string()
      "Insufficient permission: /foo/bar"

      iex> ExZk.Error.new(:bad_arguments, "/foo/bar") |> to_string()
      "Arguments are not valid: /foo/bar"

      iex> ExZk.Error.new(:bad_version, "/foo/bar") |> to_string()
      "version No is not valid: /foo/bar"

      iex> ExZk.Error.new(:reconfig_in_progress, "/foo/bar") |> to_string()
      "Another reconfiguration is in progress -- concurrent reconfigs not supported (yet)"

      iex> ExZk.Error.new(:new_config_no_quorum, "/foo/bar") |> to_string()
      "No quorum of new config is connected and up-to-date with the leader of last committed config"

      iex> ExZk.Error.new(:quota_exceeded, "/foo/bar") |> to_string()
      "Quota has exceeded: /foo/bar"

      iex> ExZk.Error.new(123, "/foo/bar") |> to_string()
      "Error: 123: /foo/bar"

      iex> ExZk.Error.new(:session_expired, "") |> to_string()
      "Error: session_expired"

  """
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

    def to_string(%ExZk.Error{err: err, path: ""}), do: "Error: #{err}"
    def to_string(%ExZk.Error{err: err, path: path}), do: "Error: #{err}: #{path}"
  end
end
