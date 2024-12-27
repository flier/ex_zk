defmodule ExZk do
  @moduledoc """
  This is the documentation for the ExZk project.
  """
  alias ExZk.{Session, StartOptions}

  use Application

  @typedoc """
  Options that can be passed to starts a session to Zookeeper (see `start_link/1`).

  #{ExZk.StartOptions.options_docs(:ex_zk)}
  """
  @type option :: unquote(ExZk.StartOptions.options_typespec(:ex_zk))

  @typedoc """
  Passwords that can be passed to the `:password` option (see `start_link/1`).
  """
  @type password :: String.t() | {module(), function_name :: atom(), arguments :: [term()]}

  @typedoc """
  A session name that can be passed to the `:name` option (see `start_link/1`).
  """
  @type name :: atom() | {:global, name :: term()} | {:via, mod :: module(), name :: term()}

  @type session :: Session.session()
  @type path :: Session.path()

  @default_timeout 5000
  @no_version -1

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

  """
  @spec start_link(binary() | list(option())) :: {:ok, pid()} | :ignore | {:error, term()}
  def start_link(uri_or_options \\ [])

  def start_link(uri) when is_binary(uri), do: start_link(uri, [])

  def start_link(opts) when is_list(opts) do
    with({:ok, opts} <- StartOptions.validate(opts)) do
      ExZk.Session.start_link(opts)
    end
  end

  @spec start_link(binary(), list(option())) :: {:ok, pid()} | :ignore | {:error, term()}
  def start_link(uri, opts) when is_binary(uri) and is_list(opts) do
    uri
    |> ExZk.URI.to_start_options()
    |> Keyword.merge(opts)
    |> start_link()
  end

  @spec get_children(session(), path(), timeout()) ::
          {:ok, children :: list(path())} | {:error, reason :: term()}
  defdelegate get_children(session, path, timeout \\ @default_timeout), to: Session

  @spec get_children2(session(), path(), timeout()) ::
          {:ok, children :: list(path()), Stat.t()} | {:error, reason :: term()}
  defdelegate get_children2(session, path, timeout \\ @default_timeout), to: Session

  @spec get_data(session(), path(), timeout()) ::
          {:ok, data :: binary(), Stat.t()} | {:error, reason :: term()}
  defdelegate get_data(session, path, timeout \\ @default_timeout), to: Session

  @spec set_data(
          session(),
          path(),
          data :: binary(),
          version :: integer(),
          timeout()
        ) ::
          {:ok, Stat.t()} | {:error, reason :: term()}
  defdelegate set_data(
                session,
                path,
                data \\ "",
                version \\ @no_version,
                timeout \\ @default_timeout
              ),
              to: Session

  @spec create(
          session(),
          path(),
          data :: binary(),
          opts :: [option()],
          timeout()
        ) :: {:ok, path(), Stat.t() | nil} | {:error, reason :: term()}
  defdelegate create(session, path, data \\ "", opts \\ [], timeout \\ @default_timeout),
    to: Session

  @spec delete(
          session(),
          path(),
          version :: integer(),
          timeout()
        ) ::
          :ok | {:error, reason :: term()}
  defdelegate delete(session, path, version \\ @no_version, timeout \\ @default_timeout),
    to: Session

  @spec exists(session(), path(), timeout()) ::
          {:ok, boolean(), Stat.t()} | {:error, reason :: term()}
  defdelegate exists(session, path, timeout \\ @default_timeout), to: Session

  @spec get_acl(session(), path(), timeout()) ::
          {:ok, list(ACL.t()), Stat.t()} | {:error, reason :: term()}
  defdelegate get_acl(session, path, timeout \\ @default_timeout), to: Session

  @spec set_acl(
          session(),
          path(),
          acl :: [ACL.t()],
          version :: integer(),
          timeout()
        ) ::
          {:ok, Stat.t()} | {:error, reason :: term()}
  defdelegate set_acl(session, path, acl, version \\ @no_version, timeout \\ @default_timeout),
    to: Session

  @spec sync(session(), path(), timeout()) ::
          {:ok, path()} | {:error, reason :: term()}
  defdelegate sync(session, path, timeout \\ @default_timeout), to: Session

  @spec multi(session(), ops :: [Multi.Op.t()], timeout()) ::
          {:ok, [Multi.Result.t()]} | {:error, reason :: term()}
  defdelegate multi(session, ops, timeout \\ @default_timeout), to: Session

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
