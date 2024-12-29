defmodule Mix.Tasks.Zkcli.Stat do
  defmodule Printer do
    alias ExZk.Data.Stat

    @enforce_keys [:stat]
    defstruct [:stat]

    @type t :: %__MODULE__{
            stat: Stat.t()
          }

    @spec new(Stat.t()) :: t()
    def new(stat), do: %__MODULE__{stat: stat}

    defimpl String.Chars do
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
end
