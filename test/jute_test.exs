defmodule JuteTest do
  use ExUnit.Case

  import ExZk.Wire

  alias ExZk.Data.Id
  alias ExZk.Wire.{Pack, Unpack}

  @id %Id{scheme: "zk", id: "test"}
  @data <<0, 0, 0, 2, ?z, ?k, 0, 0, 0, 4, ?t, ?e, ?s, ?t>>

  describe "given a Data.Id struct" do
    test "it can be packed" do
      assert pack({Id, @id}) == @data
      assert pack(@id) == @data

      assert Pack.pack(@id) == @data
    end

    test "it can be unpacked" do
      assert unpack(@data, Id) == {:ok, @id, ""}
      assert unpack(@data, %Id{}) == {:ok, @id, ""}

      assert Unpack.unpack(%Id{}, @data) == {:ok, @id, ""}
    end
  end
end
