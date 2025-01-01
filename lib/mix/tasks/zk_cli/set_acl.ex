defmodule Mix.Tasks.ZkCli.SetAcl do
  @moduledoc """
  Set the Acl permission for one node.
  """

  @behaviour Mix.Tasks.ZkCli.Command

  alias ExZk.Defs.ACL
  alias Mix.Tasks.ZkCli.Context

  @usage """
  Usage: setAcl [options] <path> <acl>

  Options:
    -h, --help                Print this help
    -s, --stat                Print znode stats additionally
    -v, --version             Set with an expected version
    -R, --recursive           Recursively set a node ACL
  """

  @opts [
    help: :boolean,
    stat: :boolean,
    version: :integer,
    recursive: :boolean
  ]

  @aliases [
    h: :help,
    s: :stat,
    v: :version,
    R: :recursive
  ]

  @impl true
  def usage, do: IO.puts(@usage)

  @impl true
  def run(%Context{session: session} = _ctx, args) do
    {opts, args, _invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    if opts[:help] do
      usage()
    else
      set_acl(session, args, opts)
    end
  end

  defp set_acl(_session, [], _opts), do: usage()
  defp set_acl(_session, [_path], _opts), do: usage()

  defp set_acl(session, [path, acl], opts) do
    with {:ok, stat} <-
           ExZk.set_acl(session, path, ACL.parse_acls(acl), opts[:version]) do
      if opts[:stat], do: IO.puts(stat)

      :ok
    end
  end
end
