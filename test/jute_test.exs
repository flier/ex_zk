defmodule JuteTest do
  use ExUnit.Case

  import ExZk.Wire
  alias ExZk.Data.Id

  describe "Given a data id" do
    test "it can be packed" do
      id = %Id{scheme: "zk", id: "test"}

      assert pack({Id, id}) ==
               <<0, 0, 0, 2, ?z, ?k, 0, 0, 0, 4, ?t, ?e, ?s, ?t>>

      assert pack(id) ==
               <<0, 0, 0, 2, ?z, ?k, 0, 0, 0, 4, ?t, ?e, ?s, ?t>>
    end

    test "it can be unpacked" do
      buf = <<0, 0, 0, 2, ?z, ?k, 0, 0, 0, 4, ?t, ?e, ?s, ?t>>

      assert unpack(buf, Id) ==
               {:ok, %Id{scheme: "zk", id: "test"}, ""}
    end
  end
end
