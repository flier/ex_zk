defmodule WatchTest do
  use ExUnit.Case, async: true

  use ExZk.Defs

  alias ExZk.{NodeWatcher, StateWatcher}

  defmodule SessionWatcher do
    use ExZk.StateWatcher

    def session_state_changed(state) do
      send(self(), {:session_state, state})

      :ok
    end
  end

  defmodule ConnectedWatcher do
    use ExZk.StateWatcher

    def session_sync_connected do
      send(self(), {:session_state, :sync_connected})

      :ok
    end
  end

  defmodule PathWatcher do
    use ExZk.NodeWatcher

    def node_changed(evt) do
      send(self(), evt)

      :ok
    end
  end

  defmodule CreateWatcher do
    use ExZk.NodeWatcher

    def node_created(path, zxid) do
      send(self(), {:node_created, path, zxid})

      :ok
    end
  end

  describe "a state watcher" do
    test "it could be notified as a process" do
      assert StateWatcher.state_changed(self(), :sync_connected) == :ok

      assert_received({:session_state, :sync_connected})
    end

    test "it could be notified as a named process" do
      Process.register(self(), :watcher)

      try do
        assert StateWatcher.state_changed(:watcher, :sync_connected) == :ok
      after
        Process.unregister(:watcher)
      end

      assert_received({:session_state, :sync_connected})
    end

    test "it could be notified as an anonymous function" do
      assert StateWatcher.state_changed(
               fn state ->
                 send(self(), {:session_state, state})

                 :ok
               end,
               :closed
             ) == :ok

      assert_received({:session_state, :closed})
    end

    test "it could be notified as a function" do
      assert StateWatcher.state_changed(&SessionWatcher.session_state_changed/1, :sync_connected) ==
               :ok

      assert_received({:session_state, :sync_connected})
    end

    test "it could be notified as a {module, function}" do
      assert StateWatcher.state_changed({SessionWatcher, :session_state_changed}, :disconnected) ==
               :ok

      assert_received({:session_state, :disconnected})
    end

    test "it could be notified as a module which exports state_changed/1" do
      assert StateWatcher.state_changed(SessionWatcher, :disconnected) == :ok
      assert_received({:session_state, :disconnected})

      assert StateWatcher.state_changed(SessionWatcher, :sync_connected) == :ok
      assert_received({:session_state, :sync_connected})
    end

    test "it could be notified as a module which exports state/0" do
      # the state is ignored
      assert StateWatcher.state_changed(ConnectedWatcher, :disconnected) == :ok

      assert StateWatcher.state_changed(ConnectedWatcher, :sync_connected) == :ok
      assert_received({:session_state, :sync_connected})
    end
  end

  @path "/foo/bar"
  @zxid 123

  describe "a node watcher" do
    test "it could be notified as a process" do
      assert NodeWatcher.node_changed(self(), {:node_created, @path, @zxid}) == :ok

      assert_received({:node_created, @path, @zxid})
    end

    test "it could be notified as a named process" do
      Process.register(self(), :watcher)

      try do
        assert NodeWatcher.node_changed(:watcher, {:node_created, @path, @zxid}) == :ok
      after
        Process.unregister(:watcher)
      end

      assert_received({:node_created, @path, @zxid})
    end

    test "it could be notified as an anonymous function" do
      assert NodeWatcher.node_changed(
               fn evt ->
                 send(self(), evt)

                 :ok
               end,
               {:node_children_changed, @path, @zxid}
             ) == :ok

      assert_received({:node_children_changed, @path, @zxid})
    end

    test "it could be notified as a function" do
      assert NodeWatcher.node_changed(&PathWatcher.node_changed/1, {:node_created, @path, @zxid}) ==
               :ok

      assert_received({:node_created, @path, @zxid})
    end

    test "it could be notified as a {module, function}" do
      assert NodeWatcher.node_changed({PathWatcher, :node_changed}, {:node_deleted, @path, @zxid}) ==
               :ok

      assert_received({:node_deleted, @path, @zxid})
    end

    test "it could be notified as a module which exports node_changed/1" do
      assert NodeWatcher.node_changed(PathWatcher, {:node_data_changed, @path, @zxid}) == :ok
      assert_received({:node_data_changed, @path, @zxid})

      assert NodeWatcher.node_changed(PathWatcher, {:node_deleted, @path, @zxid}) == :ok
      assert_received({:node_deleted, @path, @zxid})
    end

    test "it could be notified as a module which exports state/0" do
      # the state is ignored
      assert NodeWatcher.node_changed(CreateWatcher, {:node_data_changed, @path, @zxid}) == :ok

      assert NodeWatcher.node_changed(CreateWatcher, {:node_created, @path, @zxid}) == :ok
      assert_received({:node_created, @path, @zxid})
    end
  end
end
