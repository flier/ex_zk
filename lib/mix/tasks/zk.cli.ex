defmodule Mix.Tasks.ZkCli do
  use Mix.Task

  import IO.ANSI

  require Logger

  alias ExZk.Session

  defmodule Context do
    @enforce_keys [:host, :session]
    defstruct [:host, :session, :command, history: [], count: 0]

    @type t :: %__MODULE__{
            host: String.t(),
            session: pid(),
            command: atom(),
            history: [{integer(), [String.t()]}],
            count: integer()
          }
  end

  defmodule Command do
    @callback usage :: :ok

    @callback run(context :: Context.t(), args :: [String.t()]) ::
                :ok | {:error, reason :: term()}
  end

  @shortdoc "Starts the interactive shell"

  @default_server "localhost:2181"
  @default_timeout 300_000

  @commands """
    help [command]            Print this help
    ls <path>                 List all nodes
    close                     Close the current session
    connect <host:port>       Connect to a different server
    addauth <scheme> <auth>   Add authentication
    history                   Showing the history about the recent commands that you have executed
    redo <index>              Redo the cmd with the index from history.
    stat <path>               Showing the stat/metadata of one node.
    sync <path>               Sync the data of one node between leader and followers(Asynchronous sync)
    whoami                    Get the client information
    quit                      Quit the CLI
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
  def history(%Context{history: history}) do
    for {id, cmd} <- history |> Stream.take(10) |> Enum.reverse() do
      IO.puts("#{id} - #{cmd |> Enum.join(" ")}")
    end

    :ok
  end

  @doc """
  Redo the cmd with the index from history.
  """
  @spec redo(Context.t(), index :: binary()) :: :ok
  def redo(%Context{history: history} = ctx, index) do
    id = index |> String.to_integer()

    case history |> Enum.find(fn {idx, _} -> idx == id end) do
      nil ->
        print_error("Command index out of range")

      {_, cmd} ->
        eval({ctx, cmd})
        :ok
    end
  end

  @doc """
  Sync the data of one node between leader and followers(Asynchronous sync)
  """
  @spec sync(Context.t(), path :: String.t()) :: :ok
  def sync(%Context{session: session}, path) do
    case ExZk.sync(session, path) do
      {:ok, ^path} -> IO.puts("Sync is OK")
      {:error, err} -> print_error("Sync has failed. Error: #{err}")
    end
  end

  @doc """
  Get the client information
  """
  @spec whoami(Context.t()) :: :ok
  def whoami(%Context{session: session}) do
    case ExZk.whoami(session) do
      {:ok, client_info} ->
        IO.puts("Auth scheme: User")

        client_info |> Enum.map_join("\n", &"#{&1.auth_scheme}: #{&1.user}") |> IO.puts()

      {:error, err} ->
        {:error, err}
    end
  end

  ####
  ## Callbacks
  ##

  @impl true
  def run(args) do
    {parsed, args, invalid} = OptionParser.parse_head(args, aliases: @aliases, strict: @opts)

    Logger.configure(level: log_level(parsed))

    Logger.debug(parsed: parsed, args: args, invalid: invalid)

    Mix.Task.run("app.start")

    ExZk.Logger.install()

    cond do
      Keyword.get(parsed, :help) ->
        usage()

      invalid != [] ->
        print_error(
          "Invalid options: #{invalid |> Enum.map_join(", ", fn
            {key, nil} -> key
            {key, value} -> "#{key} #{value}"
          end)}"
        )

        usage()

      true ->
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

    print_progress("Connecting to #{server}")

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

  defp read(%Context{host: host, session: session, count: count} = ctx) do
    line =
      Prompt.text("[zk: #{host}(#{session |> state()}) #{count}]",
        color: :light_black,
        trim: true
      )

    {ctx, line |> String.split()}
  end

  defp state(session) do
    {state, %{}} = Session.status(session)
    state |> Atom.to_string() |> String.upcase()
  end

  defp eval({%Context{} = ctx, []}), do: ctx

  defp eval({%Context{history: history, count: count} = ctx, [cmd | args]}) do
    Logger.debug(ctx: ctx, cmd: cmd, args: args)

    try do
      ctx = %{ctx | command: String.to_existing_atom(cmd)}

      case run(ctx, cmd, args) do
        :ok ->
          nil

        {:error, reason} ->
          print_error(reason)
      end

      %{ctx | history: [{count, [cmd | args]} | history], count: count + 1}
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

  defp module(cmd), do: Module.concat(__MODULE__, cmd |> String.capitalize())

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

  defp print_progress(msg) when is_binary(msg), do: IO.puts(msg)
  defp print_error(msg) when is_binary(msg), do: IO.puts(light_red() <> msg <> reset())
  defp print_error(arg), do: print_error(to_string(arg))

  defp usage, do: IO.puts(@usage)
end
