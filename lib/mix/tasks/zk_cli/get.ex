defmodule Mix.Tasks.ZkCli.Get do
  @moduledoc """
  Get the data of the specific path
  """

  @behaviour Mix.Tasks.ZkCli.Command

  alias Mix.Tasks.ZkCli.{Context, Stat}

  @usage """
  Usage: get [options] <path>

  Options:
    -h, --help                Print this help
    -s, --stat                Print znode stats additionally
    -w, --watch               Watch for changes on the znode
    -b, --base64              Output data in base64 format
    -x, --hexdump             Output data in hexdump format
  """

  @opts [
    help: :boolean,
    stat: :boolean,
    watch: :boolean,
    base64: :boolean,
    hexdump: :boolean
  ]

  @aliases [
    h: :help,
    s: :stat,
    w: :watch,
    b: :base64,
    x: :hexdump
  ]

  @impl true
  def usage, do: IO.puts(@usage)

  @impl true
  def run(%Context{session: session} = _ctx, args) do
    {opts, args, _invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    if opts[:help] do
      usage()
    else
      get(session, List.first(args, "/"), opts)
    end
  end

  @hexdump_header """
            +-----------------------------------------+
            |  0 1  2 3  4 5  6 7  8 9  a b  c d  e f |
   +--------+-----------------------------------------+------------------+
  """

  @hexdump_footer """

   +--------+-----------------------------------------+------------------+
  """

  defp get(session, path, opts) do
    with {:ok, data, stat} <- ExZk.get_data(session, path, opts[:watch]) do
      cond do
        IO.iodata_length(data) == 0 ->
          "null"

        opts[:base64] ->
          data |> Base.encode64()

        opts[:hexdump] ->
          @hexdump_header <> Hexdump.format_hexdump_output(data) <> @hexdump_footer

        true ->
          data
      end
      |> IO.puts()

      if opts[:stat], do: stat(stat)

      :ok
    end
  end

  defp stat(stat), do: stat |> Stat.Printer.new() |> IO.puts()
end
