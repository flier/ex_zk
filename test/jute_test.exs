defmodule JuteTest do
  use ExUnit.Case

  describe "Given a data id" do
    test "it can be packed" do
      id = %ExZk.Data.Id{scheme: "zk", id: "test"}

      assert ExZk.Wire.pack(ExZk.Data.Id, id) ==
               <<0, 0, 0, 2, ?z, ?k, 0, 0, 0, 4, ?t, ?e, ?s, ?t>>
    end

    test "it can be unpacked" do
      buf = <<0, 0, 0, 2, ?z, ?k, 0, 0, 0, 4, ?t, ?e, ?s, ?t>>

      assert ExZk.Wire.unpack(ExZk.Data.Id, buf) ==
               {:ok, %ExZk.Data.Id{scheme: "zk", id: "test"}, ""}
    end
  end
end
