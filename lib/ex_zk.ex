defmodule ExZk do
  @moduledoc """
  This is the documentation for the ExZk project.
  """

  use Application

  @typedoc """
  Options that can be passed to starts a connection to Zookeeper (see `start_link/1`).

  #{ExZk.StartOptions.options_docs(:ex_zk)}
  """
  @type option() :: unquote(ExZk.StartOptions.options_typespec(:ex_zk))

  @typedoc """
  Passwords that can be passed to the `:password` option (see `start_link/1`).
  """
  @type password() :: String.t() | {module(), function_name :: atom(), arguments :: [term()]}

  @typedoc """
  A session name that can be passed to the `:name` option (see `start_link/1`).
  """
  @type name() :: atom() | {:global, name :: term()} | {:via, mod :: module(), name :: term()}

  ####
  ## Public API
  ##

  @doc """
  Starts a session to Zookeeper.

  This function returns `{:ok, pid}` if the ExZk process is started successfully.

      {:ok, pid} = ExZk.start_link()

  This function accepts one argument which can either be an string representing a URI or a keyword list of options.

  ## Examples

      iex> {:ok, pid} = ExZk.start_link()
      iex> is_pid(pid)
      true

      iex> {:ok, pid} = ExZk.start_link(host: "example.com", port: 9999, password: "secret")
      iex> is_pid(pid)
      true

      iex> {:ok, pid} = ExZk.start_link(database: 3, name: :ex_zk)
      iex> is_pid(pid)
      true

  """
  @spec start_link(binary() | list(option())) :: {:ok, pid()} | :ignore | {:error, term()}
  def start_link(uri_or_options \\ [])

  def start_link(uri) when is_binary(uri), do: start_link(uri, [])
  def start_link(opts) when is_list(opts), do: ExZk.Connection.start_link(opts)

  @spec start_link(binary(), list(option())) :: {:ok, pid()} | :ignore | {:error, term()}
  def start_link(uri, other_options)

  def start_link(uri, other_options) when is_binary(uri) and is_list(other_options) do
    opts = ExZk.URI.to_start_options(uri)
    start_link(Keyword.merge(opts, other_options))
  end

  ####
  ## Callbacks
  ##

  @doc false
  def start(_type, _args) do
    if Application.fetch_env!(:ex_zk, :logger) do
      ExZk.Logger.install()
    end

    children = [
      {DynamicSupervisor, name: ExZk.Transports.LongPoll.Supervisor, strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ExZk.Supervisor)
  end
end
