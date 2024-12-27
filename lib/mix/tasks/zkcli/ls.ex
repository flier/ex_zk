defmodule Mix.Tasks.Zkcli.Ls do
  @behaviour Mix.Tasks.Zkcli.Command

  import Logger

  alias Mix.Tasks.Zkcli.Context

  @usage """
  Usage: ls [options] <path>

  Options:
    -h, --help                Print this help
    -s, --stat                Print node stats
    -w, --watch               Set a watch on the child change
    -R, --recursive           Recursively list child nodes
  """

  @opts [
    help: :boolean,
    stat: :boolean,
    watch: :boolean,
    recursive: :boolean
  ]

  @aliases [
    h: :help,
    s: :stat,
    w: :watch,
    R: :recursive
  ]

  @impl true
  def usage(), do: IO.puts(@usage)

  @impl true
  def run(%Context{session: _session} = ctx, args) do
    {parsed, args, invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    debug(pid: self(), ctx: ctx, opts: parsed, args: args, rest: invalid)

    if Keyword.get(parsed, :help) do
      usage()
    end

    :ok
  end
end
