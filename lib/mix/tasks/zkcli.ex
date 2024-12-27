defmodule Mix.Tasks.Zkcli do
  use Mix.Task

  import Logger

  defmodule Context do
    defstruct [:session, :command]

    @type t :: %__MODULE__{
            session: pid(),
            command: atom()
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

  @command """
    help [command]            Print this help
    ls <path>                 List all nodes
    close                     Close the current session
    connect <host:port>       Connect to a different server
    addauth <scheme> <auth>   Add authentication
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
    --log-level <level>       Enable logging at the given level (default: #{level()})
    -c, --client-configuration <path>
                              Path to a client configuration file

  Commands:
  #{@command}
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
    client_configuration: :string
  ]

  @aliases [
    h: :help,
    s: :server,
    t: :timeout,
    d: :debug,
    v: :verbose,
    w: :warn,
    e: :error,
    c: :client_configuration
  ]

  @impl true
  def run(args) do
    {parsed, args, invalid} = OptionParser.parse_head(args, aliases: @aliases, strict: @opts)

    Logger.configure(level: log_level(parsed))

    debug(parsed: parsed, args: args, invalid: invalid)

    if Keyword.get(parsed, :help) do
      usage()
    end

    if length(invalid) > 0 do
      IO.puts(
        "Invalid options: #{invalid |> Enum.map_join(", ", fn
          {key, nil} -> key
          {key, value} -> "#{key} #{value}"
        end)}"
      )

      usage()
    end

    server = Keyword.get(parsed, :server, @default_server)
    timeout = Keyword.get(parsed, :timeout, @default_timeout)

    debug(pid: self(), server: server, timeout: timeout)

    IO.puts("Connecting to #{server}")

    # children = [
    #   %{
    #     id: Session,
    #     start: {ExZk, :start_link, ["zk://#{server}/", [sync_connect: true, timeout: timeout]]}
    #   }
    # ]

    # {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)

    # debug(sup: sup, session: Process.whereis(Session))

    session = nil

    case args do
      [] ->
        nil

      [cmd | args] when is_binary(cmd) ->
        debug(cmd: cmd, args: args)

        ctx = %Context{session: session, command: String.to_existing_atom(cmd)}

        if function_exported?(__MODULE__, String.to_existing_atom(cmd), length(args) + 1) do
          apply(__MODULE__, String.to_existing_atom(cmd), [ctx | args])
        else
          mod = Module.concat(__MODULE__, cmd |> String.capitalize())

          Task.async(mod, :run, [ctx, args]) |> Task.await()
        end
    end
  end

  defp log_level(opts) when is_list(opts), do: log_level(Enum.into(opts, %{}))
  defp log_level(%{debug: true}), do: :debug
  defp log_level(%{verbose: 1}), do: :notice
  defp log_level(%{verbose: 2}), do: :info
  defp log_level(%{verbose: n}) when n >= 3, do: :debug
  defp log_level(%{warn: true}), do: :warning
  defp log_level(%{error: true}), do: :error
  defp log_level(%{critical: true}), do: :critical
  defp log_level(%{log_level: level}) when is_binary(level), do: String.to_existing_atom(level)
  defp log_level(_), do: level()

  defp usage() do
    IO.puts(@usage)
    Process.exit(self(), :normal)
  end

  def help(_ctx), do: IO.puts(@command)

  def help(_ctx, cmd) do
    mod = Module.concat(__MODULE__, cmd |> String.capitalize())
    mod.usage()
  end
end
