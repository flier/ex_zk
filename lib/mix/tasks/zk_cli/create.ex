defmodule Mix.Tasks.ZkCli.Create do
  @moduledoc """
  Create a znode.
  """

  @behaviour Mix.Tasks.ZkCli.Command

  import ExZk.Defs.Ids
  alias Mix.Tasks.ZkCli.Context

  @usage """
  Usage: create [options] <path> [data] [acl]

  Options:
    -h, --help                Print this help
    -e, --ephemeral           Create a ephemeral node
    -s, --sequential          Create a sequential node
    -c, --container           Create a container node
    --ttl <ttl>               Create a node with TTL
  """

  @opts [
    help: :boolean,
    ephemeral: :boolean,
    sequential: :boolean,
    container: :boolean,
    ttl: :integer
  ]

  @aliases [
    h: :help,
    e: :ephemeral,
    s: :sequential,
    c: :container
  ]

  @impl true
  def usage, do: IO.puts(@usage)

  @impl true
  def run(%Context{session: session} = _ctx, args) do
    {opts, args, _invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    if opts[:help] do
      usage()
    else
      create(session, args, opts)
    end
  end

  defp create(session, [path], opts), do: create(session, path, "", [open_acl()], opts)
  defp create(session, [path, data], opts), do: create(session, path, data, [open_acl()], opts)

  defp create(session, [path, data, acl | _rest], opts),
    do: create(session, path, data, parse_acl(acl), opts)

  defp create(session, path, data, acl, opts) do
    with {:ok, path, _stat} <-
           ExZk.create(session, path, data, mode: create_mode(opts), ttl: opts[:ttl], acl: acl) do
      IO.puts("Created #{path}")
    end
  end

  defp create_mode(opts) do
    ephemeral = Keyword.has_key?(opts, :ephemeral)
    sequential = Keyword.has_key?(opts, :sequential)
    container = Keyword.has_key?(opts, :container)
    ttl = Keyword.get(opts, :ttl)

    cond do
      ephemeral and sequential -> :ephemeral_sequential
      ephemeral -> :ephemeral
      sequential and !is_nil(ttl) -> :persistent_sequential_with_ttl
      container -> :container
      !is_nil(ttl) -> :persistent_with_ttl
      true -> :persistent
    end
  end
end
