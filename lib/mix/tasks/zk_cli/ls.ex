defmodule Mix.Tasks.ZkCli.Ls do
  @moduledoc """
  List all nodes
  """

  @behaviour Mix.Tasks.ZkCli.Command

  alias ExZk.Util
  alias Mix.Tasks.ZkCli.Context

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

    if opts[:help] do
      usage()
    else
      ls(session, args, opts)
    end
  end

  defp ls(_session, [], _opts), do: usage()

  defp ls(session, [path | _], opts) do
    cond do
      opts[:recursive] ->
        for path <- Util.list_subtree(session, path, :dfs, opts[:watch]) do
          IO.puts(path)
        end

        :ok

      opts[:stat] ->
        with {:ok, children, stat} <- ExZk.get_children2(session, path, opts[:watch]) do
          print_children(children)

          stat |> IO.puts()
        end

      true ->
        with {:ok, children} <- ExZk.get_children(session, path, opts[:watch]) do
          print_children(children)
        end
    end
  end

  defp print_children(children),
    do: "[#{children |> Enum.sort() |> Enum.join(", ")}]" |> IO.puts()
end
