defmodule Mix.Tasks.ZkCli.GetAcl do
  @moduledoc """
  Get the ACL permission of one path
  """

  @behaviour Mix.Tasks.ZkCli.Command

  alias Mix.Tasks.ZkCli.Context

  @usage """
  Usage: getAcl [options] <path>

  Options:
    -h, --help                Print this help
    -s, --stat                Print znode stats additionally
  """

  @opts [
    help: :boolean,
    stat: :boolean
  ]

  @aliases [
    h: :help,
    s: :stat
  ]

  @impl true
  def usage, do: IO.puts(@usage)

  @impl true
  def run(%Context{session: session} = _ctx, args) do
    {opts, args, _invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    if opts[:help] do
      usage()
    else
      get_acl(session, args, opts)
    end
  end

  defp get_acl(_session, [], _opts), do: usage()

  defp get_acl(session, [path | _], opts) do
    with {:ok, acl, stat} <- ExZk.get_acl(session, path) do
      acl |> Enum.each(&IO.puts/1)

      if opts[:stat], do: stat |> IO.puts()

      :ok
    end
  end
end
