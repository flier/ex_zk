defmodule Mix.Tasks.Zkcli do
  alias ExZk.Session
  use Mix.Task

  require Logger

  defmodule Context do
    @enforce_keys [:host, :session]
    defstruct [:host, :session, :command, count: 0]

    @type t :: %__MODULE__{
            host: String.t(),
            session: pid(),
            command: atom(),
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
    quit                      QUit the CLI
  """

  @usage """
  Usage: mix zkcli [options] [command] [args]

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

  @spec help(%Context{}) :: :ok
  def help(_ctx), do: IO.puts(@commands)
  def help(_ctx, cmd), do: module(cmd).usage()

  @spec quit(%Context{}) :: no_return()
  def quit(_ctx), do: System.halt(1)

  ####
  ## Callbacks
  ##

  @impl true
  def run(args) do
    {parsed, args, invalid} = OptionParser.parse_head(args, aliases: @aliases, strict: @opts)

    Logger.configure(level: log_level(parsed))

    Logger.debug(parsed: parsed, args: args, invalid: invalid)

    cond do
      Keyword.get(parsed, :help) ->
        usage()

      invalid != [] ->
        IO.puts(
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

    IO.puts("Connecting to #{server}")

    scheme = if Keyword.get(opts, :secure), do: "ssl", else: "zk"

    if secure do
      IO.puts("Secure connection is enabled")
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
      IO.puts("Welcome to ZooKeeper!")

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

  defp eval({%Context{count: count} = ctx, [cmd | args]}) do
    Logger.debug(ctx: ctx, cmd: cmd, args: args)

    try do
      ctx = %{ctx | command: String.to_existing_atom(cmd)}

      :ok = run(ctx, cmd, args)

      %{ctx | count: count + 1}
    rescue
      ArgumentError ->
        help(ctx)

        IO.puts("Command not found: #{cmd}")

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

  defp usage, do: IO.puts(@usage)
end
