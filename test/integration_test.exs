defmodule IntegrationTest do
  use ExUnit.Case

  @moduletag :zookeeper

  setup do
    {:ok, zk_uri: System.get_env("EX_ZK_ZOOKEEPER_URI", "zk://localhost:2181")}
  end

  describe "Given a zookeeper server" do
    test "it can be connected", %{zk_uri: zk_uri} = _context do
      {:ok, conn} = ExZk.start_link(zk_uri, sync_connect: true)
      assert is_pid(conn)

      assert {:connected, %{socket: _socket}} = ExZk.Session.status(conn)
    end
  end
end
