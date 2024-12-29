defmodule Mix.Tasks.Zkcli.Stat do
  @moduledoc """
  Showing the stat/metadata of one node.
  """

  @behaviour Mix.Tasks.Zkcli.Command

  alias ExZk.Error
  alias Mix.Tasks.Zkcli.{Context, Stat}

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
    {parsed, args, _invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    stat(session, List.first(args, "/"), parsed)
  end

  defp stat(_, _, help: true), do: usage()

  defp stat(session, path, _opts) do
    case ExZk.exists(session, path) do
      {:ok, true, stat} -> print_stat(stat)
      {:ok, false, nil} -> {:error, Error.new(:no_node, path)}
      {:error, err} -> {:error, err}
    end
  end

  defp print_stat(stat), do: stat |> Stat.Printer.new() |> IO.puts()
end

defmodule Mix.Tasks.Zkcli.Stat.Printer do
  alias ExZk.Data.Stat

  @enforce_keys [:stat]
  defstruct [:stat]

  @type t :: %__MODULE__{
          stat: Stat.t()
        }

  @spec new(Stat.t()) :: t()
  def new(stat), do: %__MODULE__{stat: stat}

  defimpl String.Chars do
    alias Mix.Tasks.Zkcli.Stat.Printer

    def to_string(%Printer{
          stat: %Stat{
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
          }
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
