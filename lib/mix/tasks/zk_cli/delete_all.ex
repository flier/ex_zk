defmodule Mix.Tasks.ZkCli.DeleteAll do
  @moduledoc """
  Recursively delete a node with a specific path
  """

  @behaviour Mix.Tasks.ZkCli.Command

  alias Mix.Tasks.ZkCli.Context

  @usage """
  Usage: deleteAll [options] <path>

  Options:
    -h, --help                Print this help
    -b, --batch <size>        The maximum number of delete operations to be submitted in one call.
  """

  @opts [
    help: :boolean,
    batch: :integer
  ]

  @aliases [
    h: :help,
    b: :batch
  ]

  @impl true
  def usage, do: IO.puts(@usage)

  @impl true
  def run(%Context{session: session} = _ctx, args) do
    {opts, args, _invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    cond do
      opts[:help] ->
        usage()

      args == [] ->
        {:error, :missing_path}

      [path | _] = args ->
        ExZk.delete_recursive(session, path, opts[:batch])
    end
  end
end
