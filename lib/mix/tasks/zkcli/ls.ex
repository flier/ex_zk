defmodule Mix.Tasks.Zkcli.Ls do
  @moduledoc """
  List all nodes
  """

  @behaviour Mix.Tasks.Zkcli.Command

  alias Mix.Tasks.Zkcli.{Context, Stat}

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
    recursive: :boolean,
    stat: :boolean,
    watch: :boolean
  ]

  @aliases [
    h: :help,
    R: :recursive,
    s: :stat,
    w: :watch
  ]

  @impl true
  def usage, do: IO.puts(@usage)

  @impl true
  def run(%Context{session: session} = _ctx, args) do
    {parsed, args, _invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    ls(session, List.first(args, "/"), parsed)
  end

  defp ls(_, _, help: true), do: usage()
  defp ls(_session, _path, recursive: true), do: :not_implemented

  defp ls(session, path, stat: true) do
    with {:ok, children, stat} <- ExZk.get_children2(session, path) do
      print_children(children)
      print_stat(stat)
    end
  end

  defp ls(session, path, _opts) do
    with {:ok, children} <- ExZk.get_children(session, path) do
      print_children(children)
    end
  end

  defp print_children(children),
    do: "[#{children |> Enum.sort() |> Enum.join(", ")}]" |> IO.puts()

  defp print_stat(stat), do: stat |> Stat.Printer.new() |> IO.puts()
end
