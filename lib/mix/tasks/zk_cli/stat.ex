defmodule Mix.Tasks.ZkCli.Stat do
  @moduledoc """
  Showing the stat/metadata of one node.
  """

  @behaviour Mix.Tasks.ZkCli.Command

  alias ExZk.Error
  alias Mix.Tasks.ZkCli.Context

  @usage """
  Usage: stat [options] <path>

  Options:
    -h, --help                Print this help
    -w, --watch               Set a watch on the child change
  """

  @opts [
    help: :boolean,
    watch: :boolean
  ]

  @aliases [
    h: :help,
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
      stat(session, args, opts)
    end
  end

  defp stat(_session, [], _opts), do: usage()

  defp stat(session, [path | _], _opts) do
    case ExZk.exists(session, path) do
      {:ok, true, stat} -> stat |> IO.puts()
      {:ok, false, nil} -> {:error, Error.new(:no_node, path)}
      {:error, err} -> {:error, err}
    end
  end

  defimpl String.Chars, for: ExZk.Data.Stat do
    def to_string(%ExZk.Data.Stat{
          czxid: czxid,
          mzxid: mzxid,
          ctime: ctime,
          mtime: mtime,
          version: version,
          cversion: cversion,
          aversion: aversion,
          ephemeral_owner: ephemeral_owner,
          data_length: data_length,
          num_children: num_children,
          pzxid: pzxid
        }) do
      """
      cZxid = #{czxid |> zxid()}
      ctime = #{ctime |> datetime()}
      mZxid = #{mzxid |> zxid()}
      mtime = #{mtime |> datetime()}
      pZxid = #{pzxid |> zxid()}
      cversion = #{cversion}
      dataVersion = #{version}
      aclVersion = #{aversion}
      ephemeralOwner = #{ephemeral_owner |> zxid()}
      dataLength = #{data_length}
      numChildren = #{num_children}
      """
    end

    defp zxid(zxid),
      do: "0x#{zxid |> Integer.to_string(16)}"

    @datetime_fmt "%a %b %d %H:%M:%S %Z %Y"

    defp datetime(ts),
      do:
        ts
        |> DateTime.from_unix!(:millisecond)
        |> Timex.to_datetime(:local)
        |> Calendar.strftime(@datetime_fmt)
  end
end
