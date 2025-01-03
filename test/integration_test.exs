defmodule IntegrationTest do
  use ExUnit.Case, async: true

  @moduletag :external

  setup_all do
    Logger.configure(level: :debug)

    ExZk.Logger.install()
  end

  setup_all do
    zk_uri = System.get_env("EX_ZK_ZOOKEEPER_URI", "zk://localhost:2181")

    on_exit(:cleanup_test_directories, fn ->
      with {:ok, session} <- ExZk.start_link(zk_uri, sync_connect: true),
           {:ok, children} <- ExZk.get_children(session, "/") do
        for dir <- children, String.starts_with?(dir, "test-") do
          assert ExZk.delete_recursive(session, "/#{dir}") == :ok
        end
      end
    end)

    [zk_uri: zk_uri]
  end

  setup %{zk_uri: zk_uri} do
    with {:ok, session} <- ExZk.start_link(zk_uri, sync_connect: true) do
      tmp_dir = "/test-#{System.os_time()}"

      assert ExZk.create(session, tmp_dir) == {:ok, tmp_dir, nil}

      on_exit(fn ->
        with {:ok, session} <- ExZk.start_link(zk_uri, sync_connect: true) do
          ExZk.delete_recursive(session, tmp_dir)
        end
      end)

      [session: session, tmp_dir: tmp_dir]
    end
  end

  describe "a zookeeper session" do
    test "it can be connected and closed", %{session: session} do
      assert {:connected, %{}} = ExZk.status(session)

      assert ExZk.close(session) == :ok
    end

    test "it can create a persistent node", %{session: session, tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "persistent_node")

      assert {:ok, ^path, nil} = ExZk.create(session, path)
    end

    test "it can create a ephemeral node", %{session: session, tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "ephemeral_node")

      assert {:ok, ^path, nil} = ExZk.create(session, path, "mydata", mode: :ephemeral)
    end

    test "it can create a persistent-sequential node", %{session: session, tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "persistent_sequential_node")

      assert {:ok, real_path, nil} =
               ExZk.create(session, path, "mydata", mode: :persistent_sequential)

      assert String.starts_with?(real_path, path)
    end

    test "it can create a ephemeral-sequential node", %{session: session, tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "ephemeral_sequential_node")

      assert {:ok, real_path, nil} =
               ExZk.create(session, path, "mydata", mode: :ephemeral_sequential)

      assert String.starts_with?(real_path, path)
    end
  end
end
