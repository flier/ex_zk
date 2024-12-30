defmodule Mix.Tasks.ZkCli.Ls do
  @moduledoc """
  List all nodes
  """

  @behaviour Mix.Tasks.ZkCli.Command

  alias Mix.Tasks.ZkCli.{Context, Stat}

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
    {opts, args, _invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    path = List.first(args, "/")

    cond do
      opts[:help] ->
        usage()

      opts[:recursive] ->
        {:error, :not_implemented}

      opts[:stat] ->
        with {:ok, children, stat} <- ExZk.get_children2(session, path) do
          print_children(children)
          print_stat(stat)
        end

      true ->
        with {:ok, children} <- ExZk.get_children(session, path) do
          print_children(children)
        end
    end
  end

  defp print_children(children),
    do: "[#{children |> Enum.sort() |> Enum.join(", ")}]" |> IO.puts()

  defp print_stat(stat), do: stat |> Stat.Printer.new() |> IO.puts()
end
