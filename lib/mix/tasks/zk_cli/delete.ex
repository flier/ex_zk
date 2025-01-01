defmodule Mix.Tasks.ZkCli.Delete do
  @moduledoc """
  Delete a node with a specific path
  """

  @behaviour Mix.Tasks.ZkCli.Command

  alias Mix.Tasks.ZkCli.Context

  @usage """
  Usage: delete [options] <path>

  Options:
    -h, --help                Print this help
    -R, --recursive           Recursively delete nodes
    -v, --version <version>   Delete a node with a specific version
  """

  @opts [
    help: :boolean,
    recursive: :boolean,
    version: :integer
  ]

  @aliases [
    h: :help,
    R: :recursive,
    v: :version
  ]

  @impl true
  def usage, do: IO.puts(@usage)

  @impl true
  def run(%Context{session: session} = _ctx, args) do
    {opts, args, _invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    if opts[:help] do
      usage()
    else
      delete(session, args, opts)
    end
  end

  defp delete(_session, [], _opts), do: usage()

  defp delete(session, [path | _], opts) do
    if opts[:recursive] do
      ExZk.delete_recursive(session, path)
    else
      ExZk.delete(session, path, opts[:version])
    end
  end
end
