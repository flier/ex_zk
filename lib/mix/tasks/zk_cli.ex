defmodule Mix.Tasks.ZkCli do
  @moduledoc """
  The interactive Zookeeper shell
  """

  use Mix.Task
  use ExZk.Defs

  import IO.ANSI

  require Logger

  alias ExZk.Session

  @requirements ["app.start"]

  defmodule History do
    defstruct next: 0, cmds: []

    @type t :: %__MODULE__{
            next: id(),
            cmds: [{id(), command()}]
          }

    @type id :: integer()
    @type command :: [String.t()]

    def id(%__MODULE__{next: next}), do: next

    @spec put(t(), command()) :: t()
    def put(%__MODULE__{next: next, cmds: cmds}, cmd),
      do: %__MODULE__{next: next + 1, cmds: [{next, cmd} | cmds]}

    @spec get(t(), id()) :: command() | nil
    def get(%__MODULE__{cmds: cmds}, id) when is_integer(id) do
      case cmds |> Enum.find(fn {n, _} -> n == id end) do
        nil ->
          nil

        {_, cmd} ->
          cmd
      end
    end

    defimpl String.Chars do
      def to_string(%History{cmds: cmds}) do
        cmds
        |> Stream.take(10)
        |> Enum.reverse()
        |> Enum.map_join("\n", fn {id, cmd} -> "#{id} - #{cmd |> Enum.join(" ")}" end)
      end
    end
  end

  defmodule Context do
    @enforce_keys [:host, :session]
    defstruct [:host, :session, :command, history: %History{}]

    @type t :: %__MODULE__{
            host: String.t(),
            session: pid(),
            command: atom(),
            history: History.t()
          }
  end

  defmodule Command do
    @callback usage :: :ok

    @callback run(context :: Context.t(), args :: [String.t()]) ::
                :ok | {:error, reason :: term()}
  end

  @shortdoc "Starts the interactive Zookeeper shell"

  @commands """
    help [command]            Print this help.
    addAuth <scheme> <auth>   Add authentication.
    close                     Close the current session.
    connect <host:port>       Connect to a different server.
    create <path> <data>      Create a node.
    delete <path>             Delete a node with a specific path.
    deleteAll <path>          Recursively delete a node with a specific path
    get <path>                Get the data of the specific path.
    getAcl <path>             Get the ACL permission of one path
    getEphemerals <path>      Get all the ephemeral nodes created by this session
    getAllChildrenNumber <path>
                              Get all numbers of children nodes under a specific path
    history                   Showing the history about the recent commands that you have executed.
    ls <path>                 List all nodes.
    quit                      Quit the CLI.
    redo <index>              Redo the cmd with the index from history.
    set <path> <data>         Set/update the data on a path.
    setAcl <path> <acl>       Set the Acl permission for one node.
    stat <path>               Showing the stat/metadata of one node.
    sync <path>               Sync the data of one node between leader and followers(Asynchronous sync).
    whoami                    Get the client information.
  """

  @usage """
  Usage: mix zk_cli [options] [command] [args]

  Options:
    -h, --help                Print this help
    -s, --server <host:port>  Zookeeper server to connect to (default: #{@default_server})
    -t, --timeout <ms>        Zookeeper connection timeout in milliseconds (default: #{@default_timeout})
    -d, --debug               Enable debug logging
    -v, --verbose             Enable verbose logging
    -w, --warn                Enable warning logging
    -e, --error               Enable error logging
    --critical                Enable critical logging
    --log-level <level>       Enable logging at the given level (default: #{Logger.level()})
    -r, --readonly            Enable read-only mode
    -S, --secure              Enable secure mode
    -c, --client-configuration <path>
                              Path to a client configuration file
    -W, --wait-for-connection Wait for Zookeeper connection to be established

  Commands:
  #{@commands}
  """

  @opts [
    help: :boolean,
    server: :string,
    timeout: :integer,
    log_level: :string,
    debug: :boolean,
    verbose: :count,
    warn: :boolean,
    error: :boolean,
    critical: :boolean,
    readonly: :boolean,
    secure: :boolean,
    client_configuration: :string,
    wait_for_connection: :boolean
  ]

  @aliases [
    h: :help,
    s: :server,
    t: :timeout,
    d: :debug,
    v: :verbose,
    w: :warn,
    e: :error,
    r: :readonly,
    S: :secure,
    c: :client_configuration,
    W: :wait_for_connection
  ]

  ####
  ## Commands
  ##

  @doc """
  Print this help
  """
  @spec help(Context.t()) :: :ok
  def help(%Context{} = _ctx), do: IO.puts(@commands)

  @doc """
  Print the help for a specific command
  """
  @spec help(Context.t(), cmd :: String.t()) :: :ok
  def help(%Context{} = _ctx, cmd), do: module(cmd).usage()

  @doc """
  Close the current session
  """
  @spec close(Context.t()) :: :ok
  def close(%Context{session: session}), do: ExZk.close(session)

  @doc """
  Quit the CLI
  """
  @spec quit(Context.t()) :: no_return()
  def quit(%Context{session: session}) do
    ExZk.close(session)

    System.halt(1)
  end

  @doc """
  Showing the history about the recent commands that you have executed
  """
  @spec history(Context.t()) :: :ok
  def history(%Context{history: history}), do: IO.puts(history)

  @doc """
  Redo the cmd with the index from history.
  """
  @spec redo(Context.t(), index :: binary()) :: :ok
  def redo(%Context{history: history} = ctx, index) do
    case History.get(history, String.to_integer(index)) do
      nil ->
        print_error("Command index out of range")

      cmd ->
        eval({ctx, cmd})

        :ok
    end
  end

  @doc """
  Sync the data of one node between leader and followers(Asynchronous sync)
  """
  @spec sync(Context.t(), Path.t()) :: :ok
  def sync(%Context{session: session}, path) do
    with {:ok, ^path} <- ExZk.sync(session, path) do
      IO.puts("Sync is OK")
    end
  end

  @doc """
  Get the client information
  """
  @spec whoami(Context.t()) :: :ok
  def whoami(%Context{session: session}) do
    with {:ok, client_info} <- ExZk.whoami(session) do
      IO.puts("Auth scheme: User")

      client_info |> Enum.map_join("\n", &"#{&1.auth_scheme}: #{&1.user}") |> IO.puts()
    end
  end

  @doc """
  Get all numbers of children nodes under a specific path
  """
  @spec get_all_children_number(Context.t(), Path.t()) :: :ok
  def get_all_children_number(%Context{session: session}, path) do
    with {:ok, n} <- ExZk.get_all_children_number(session, path) do
      IO.puts(n)
    end
  end

  ####
  ## Callbacks
  ##

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, args, invalid} = OptionParser.parse_head(args, aliases: @aliases, strict: @opts)

    Logger.configure(level: log_level(parsed))

    Logger.debug(parsed: parsed, args: args, invalid: invalid)

    ExZk.Logger.install()

    if parsed[:help] do
      usage()
    else
      start(args, parsed)
    end
  end

  ####
  ## Private methods
  ##

  defp start(args, opts) do
    server = Keyword.get(opts, :server, @default_server)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    readonly = Keyword.get(opts, :readonly, false)
    secure = Keyword.get(opts, :secure)
    wait_for_connection = Keyword.get(opts, :wait_for_connection, false)

    if args == [], do: print_progress("Connecting to #{server}")

    scheme = if Keyword.get(opts, :secure), do: "ssl", else: "zk"

    if secure do
      print_progress("Secure connection is enabled")
    end

    {:ok, session} =
      ExZk.start_link("#{scheme}://#{server}/",
        sync_connect: wait_for_connection,
        timeout: timeout,
        readonly: readonly
      )

    Logger.debug(cli: self(), session: session, status: Session.status(session))

    ctx = %Context{host: server, session: session}

    if args == [] do
      print_progress("Welcome to ZooKeeper!")

      loop(ctx)
    else
      eval({ctx, args})
    end
  end

  defp loop(ctx), do: ctx |> read() |> eval() |> loop()

  defp read(%Context{host: host, session: session, history: history} = ctx) do
    line = prompt("[zk: #{host}(#{session |> state()}) #{History.id(history)}] ")

    {ctx, line |> OptionParser.split()}
  end

  defp state(session) do
    {state, %{}} = Session.status(session)
    state |> Atom.to_string() |> String.upcase()
  end

  defp eval({%Context{} = ctx, []}), do: ctx

  defp eval({%Context{history: history} = ctx, [cmd | args]}) do
    Logger.debug(ctx: ctx, cmd: cmd, args: args)

    cmd = Macro.underscore(cmd)

    try do
      ctx = %{ctx | command: String.to_existing_atom(cmd)}

      case run(ctx, cmd, args) do
        :ok ->
          nil

        {:error, reason} ->
          print_error(reason)
      end

      %{ctx | history: History.put(history, [cmd | args])}
    rescue
      ArgumentError ->
        help(ctx)

        print_error("Command not found: #{cmd}")

        ctx
    end
  end

  defp run(ctx, cmd, args) do
    if function_exported?(__MODULE__, String.to_existing_atom(cmd), length(args) + 1) do
      apply(__MODULE__, String.to_existing_atom(cmd), [ctx | args])
    else
      module(cmd) |> Task.async(:run, [ctx, args]) |> Task.await()
    end
  end

  defp module(cmd), do: Module.concat(__MODULE__, cmd |> Macro.camelize())

  defp log_level(opts) when is_list(opts), do: log_level(Enum.into(opts, %{}))
  defp log_level(%{debug: true}), do: :debug
  defp log_level(%{verbose: 1}), do: :notice
  defp log_level(%{verbose: 2}), do: :info
  defp log_level(%{verbose: n}) when n >= 3, do: :debug
  defp log_level(%{warn: true}), do: :warning
  defp log_level(%{error: true}), do: :error
  defp log_level(%{critical: true}), do: :critical
  defp log_level(%{log_level: level}) when is_binary(level), do: String.to_existing_atom(level)
  defp log_level(_), do: Logger.level()

  defp prompt(prompt) do
    IO.write(light_black() <> prompt <> reset())
    IO.read(:line) |> String.trim()
  end

  defp print_progress(msg) when is_binary(msg), do: IO.puts(msg)
  defp print_error(msg) when is_binary(msg), do: IO.puts(light_red() <> msg <> reset())
  defp print_error(arg), do: print_error(to_string(arg))

  defp usage, do: IO.puts(@usage)
end
