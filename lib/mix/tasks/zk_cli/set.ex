defmodule Mix.Tasks.ZkCli.Set do
  @moduledoc """
  Set/update the data on a path.
  """

  @behaviour Mix.Tasks.ZkCli.Command

  alias Mix.Tasks.ZkCli.Context

  @usage """
  Usage: set [options] <path>

  Options:
    -h, --help                Print this help
    -s, --stat                Print znode stats additionally
    -v, --version <version>   Set with an expected version
    -b, --base64              Supply data in base64 format
  """

  @opts [
    help: :boolean,
    stat: :boolean,
    version: :integer,
    base64: :boolean
  ]

  @aliases [
    h: :help,
    s: :stat,
    v: :version,
    b: :base64
  ]

  @impl true
  def usage, do: IO.puts(@usage)

  @impl true
  def run(%Context{session: session} = _ctx, args) do
    {opts, args, _invalid} = OptionParser.parse(args, aliases: @aliases, strict: @opts)

    if opts[:help] do
      usage()
    else
      set(session, args, opts)
    end
  end

  defp set(_session, [], _opts), do: usage()
  defp set(_session, [_path], _opts), do: usage()

  defp set(session, [path, data], opts) do
    data = if Keyword.has_key?(opts, :base64), do: Base.decode64!(data), else: data

    with {:ok, stat} <- ExZk.set_data(session, path, data, opts[:version]) do
      if opts[:stat], do: stat |> IO.puts()
    end
  end
end
