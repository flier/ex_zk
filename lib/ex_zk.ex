defmodule ExZk do
  @moduledoc """
  This is the documentation for the ExZk project.
  """

  alias ExZk.{Error, Multi, Session, StartOptions, URI}
  alias ExZk.Data.{ACL, ClientInfo, Stat}

  use Application

  @typedoc """
  Options that can be passed to starts a session to Zookeeper (see `start_link/1`).

  #{StartOptions.options_docs(:ex_zk)}
  """
  @type option :: unquote(StartOptions.options_typespec(:ex_zk))

  @typedoc """
  Passwords that can be passed to the `:password` option (see `start_link/1`).
  """
  @type password :: String.t() | {module(), function_name :: atom(), arguments :: [term()]}

  @typedoc """
  A session name that can be passed to the `:name` option (see `start_link/1`).
  """
  @type name :: atom() | {:global, name :: term()} | {:via, mod :: module(), name :: term()}

  @type session :: Session.session()
  @type version :: Session.version()

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
      Session.start_link(opts)
    end
  end

  @spec start_link(binary(), list(option())) :: {:ok, pid()} | :ignore | {:error, term()}
  def start_link(uri, opts) when is_binary(uri) and is_list(opts) do
    uri
    |> URI.to_start_options()
    |> Keyword.merge(opts)
    |> start_link()
  end

  @spec close(session(), timeout()) :: :ok
  defdelegate close(session, timeout \\ :infinity), to: Session

  @spec get_children(session(), Path.t(), timeout()) ::
          {:ok, children :: list(Path.t())} | {:error, Error.t()}
  defdelegate get_children(session, path, timeout \\ @default_timeout), to: Session

  @spec get_children2(session(), Path.t(), timeout()) ::
          {:ok, children :: list(Path.t()), Stat.t()} | {:error, Error.t()}
  defdelegate get_children2(session, path, timeout \\ @default_timeout), to: Session

  @spec get_data(session(), Path.t(), timeout()) ::
          {:ok, iodata(), Stat.t()} | {:error, Error.t()}
  defdelegate get_data(session, path, timeout \\ @default_timeout), to: Session

  @spec set_data(session(), Path.t(), iodata(), version(), timeout()) ::
          {:ok, Stat.t()} | {:error, Error.t()}
  defdelegate set_data(
                session,
                path,
                data \\ "",
                version \\ @no_version,
                timeout \\ @default_timeout
              ),
              to: Session

  @spec create(session(), Path.t(), iodata(), opts :: [option()], timeout()) ::
          {:ok, Path.t(), Stat.t() | nil} | {:error, Error.t()}
  defdelegate create(session, path, data \\ "", opts \\ [], timeout \\ @default_timeout),
    to: Session

  @spec delete(session(), Path.t(), version(), timeout()) ::
          :ok | {:error, Error.t()}
  defdelegate delete(session, path, version \\ @no_version, timeout \\ @default_timeout),
    to: Session

  @spec exists(session(), Path.t(), timeout()) ::
          {:ok, boolean(), Stat.t() | nil} | {:error, Error.t()}
  defdelegate exists(session, path, timeout \\ @default_timeout), to: Session

  @spec get_acl(session(), Path.t(), timeout()) ::
          {:ok, list(ACL.t()), Stat.t()} | {:error, Error.t()}
  defdelegate get_acl(session, path, timeout \\ @default_timeout), to: Session

  @spec set_acl(session(), Path.t(), acl :: [ACL.t()], version(), timeout()) ::
          {:ok, Stat.t()} | {:error, Error.t()}
  defdelegate set_acl(session, path, acl, version \\ @no_version, timeout \\ @default_timeout),
    to: Session

  @spec sync(session(), Path.t(), timeout()) ::
          {:ok, Path.t()} | {:error, Error.t()}
  defdelegate sync(session, path, timeout \\ @default_timeout), to: Session

  @spec multi(session(), ops :: [Multi.Op.t()], timeout()) ::
          {:ok, [Multi.Result.t()]} | {:error, Error.t()}
  defdelegate multi(session, ops, timeout \\ @default_timeout), to: Session

  @spec whoami(session(), timeout()) :: {:ok, [ClientInfo.t()]} | {:error, Error.t()}
  defdelegate whoami(session, timeout \\ @default_timeout), to: Session

  ####
  ## Callbacks
  ##

  @doc false
  def start(_type, _args) do
    if Application.fetch_env!(:ex_zk, :logger) do
      ExZk.Logger.install()
    end

    children = []

    Supervisor.start_link(children, strategy: :one_for_one, name: ExZk.Supervisor)
  end
end
