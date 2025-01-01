defmodule Mix.Tasks.ZkCli.GetEphemerals do
  @moduledoc """
  Get all the ephemeral nodes created by this session
  """

  @behaviour Mix.Tasks.ZkCli.Command

  alias Mix.Tasks.ZkCli.Context

  @usage """
  Usage: get [options] <path>

  Options:
    -h, --help                Print this help
  """

  @opts [
    help: :boolean
  ]

  @aliases [
    h: :help
  ]

  @impl true
  def usage, do: IO.puts(@usage)

  @impl true
  def run(%Context{session: session} = _ctx, args) do
    {opts, args, _invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    if opts[:help] do
      usage()
    else
      get_ephemerals(session, args, opts)
    end
  end

  defp get_ephemerals(session, [], opts), do: get_ephemerals(session, ["/"], opts)

  defp get_ephemerals(session, [path | _], _opts) do
    with {:ok, ephemerals} <- ExZk.get_ephemerals(session, path) do
      ephemerals |> Enum.sort() |> print_ephemerals()
    end
  end

  defp print_ephemerals(ephemerals),
    do: "[#{ephemerals |> Enum.sort() |> Enum.join(", ")}]" |> IO.puts()
end
