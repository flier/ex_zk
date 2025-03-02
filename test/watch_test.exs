defmodule StateWatcherTest do
  use ExUnit.Case, async: true

  use ExZk.Defs

  alias ExZk.StateWatcher

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
end

defmodule NodeWatcherTest do
  use ExUnit.Case, async: true

  use ExZk.Defs

  alias ExZk.{NodeWatcher, WatchedEvent}

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

  @path "/foo/bar"
  @zxid 123

  describe "a node watcher" do
    test "it could be notified as a process" do
      assert NodeWatcher.node_changed(self(), %WatchedEvent{
               type: :node_created,
               path: @path,
               zxid: @zxid
             }) == :ok

      assert_received({:node_created, @path, @zxid})
    end

    test "it could be notified as a named process" do
      Process.register(self(), :watcher)

      try do
        assert NodeWatcher.node_changed(:watcher, %WatchedEvent{
                 type: :node_created,
                 path: @path,
                 zxid: @zxid
               }) == :ok
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
               %WatchedEvent{type: :node_children_changed, path: @path, zxid: @zxid}
             ) == :ok

      assert_received({:node_children_changed, @path, @zxid})
    end

    test "it could be notified as a function" do
      assert NodeWatcher.node_changed(&PathWatcher.node_changed/1, %WatchedEvent{
               type: :node_created,
               path: @path,
               zxid: @zxid
             }) ==
               :ok

      assert_received({:node_created, @path, @zxid})
    end

    test "it could be notified as a {module, function}" do
      assert NodeWatcher.node_changed({PathWatcher, :node_changed}, %WatchedEvent{
               type: :node_deleted,
               path: @path,
               zxid: @zxid
             }) ==
               :ok

      assert_received({:node_deleted, @path, @zxid})
    end

    test "it could be notified as a module which exports node_changed/1" do
      assert NodeWatcher.node_changed(PathWatcher, %WatchedEvent{
               type: :node_data_changed,
               path: @path,
               zxid: @zxid
             }) == :ok

      assert_received({:node_data_changed, @path, @zxid})

      assert NodeWatcher.node_changed(PathWatcher, %WatchedEvent{
               type: :node_deleted,
               path: @path,
               zxid: @zxid
             }) == :ok

      assert_received({:node_deleted, @path, @zxid})
    end

    test "it could be notified as a module which exports state/0" do
      # the state is ignored
      assert NodeWatcher.node_changed(CreateWatcher, %WatchedEvent{
               type: :node_data_changed,
               path: @path,
               zxid: @zxid
             }) == :ok

      assert NodeWatcher.node_changed(CreateWatcher, %WatchedEvent{
               type: :node_created,
               path: @path,
               zxid: @zxid
             }) == :ok

      assert_received({:node_created, @path, @zxid})
    end
  end
end

defmodule WatchManagerTest do
  use ExUnit.Case, async: true

  alias ExZk.{WatchedEvent, WatchManager}

  import ExZk.{WatchDeregistration, WatchManager, WatchRegistration}

  @path "/foo/bar"
  @dir Path.dirname(@path)
  @zxid 123

  @data_watch_registration data_watch_registration(@path, :watcher)
  @child_watch_registration child_watch_registration(@path, :watcher)
  @exists_watch_registration exists_watch_registration(@path, :watcher)
  @persistent_watch_registration persistent_watch_registration(@path, :watcher)

  @persistent_recursive_watch_registration persistent_watch_registration(
                                             @path,
                                             :watcher,
                                             recursive: true
                                           )

  @persistent_recursive_dir_watch_registration persistent_watch_registration(
                                                 @dir,
                                                 :dir_watcher,
                                                 recursive: true
                                               )

  @persistent_recursive_node_watch_registration persistent_watch_registration(
                                                  @path,
                                                  :node_watcher,
                                                  recursive: true
                                                )

  @data_watch_deregistration data_watch_deregistration(@path, :watcher)
  @children_watch_deregistration children_watch_deregistration(@path, :watcher)
  @persistent_watch_deregistration persistent_watch_deregistration(@path, :watcher)
  @persistent_recursive_watch_deregistration persistent_watch_deregistration(@path, :watcher,
                                               recursive: true
                                             )
  @any_watch_deregistration any_watch_deregistration(@path, :watcher)

  setup do
    with {:ok, wm} <- ExZk.WatchManager.new(nil) do
      {:ok,
       watch_manager: wm,
       watch_manager_with_watchers:
         wm
         |> register(@data_watch_registration, :ok)
         |> register(@exists_watch_registration, :ok)
         |> register(@child_watch_registration, :ok)
         |> register(@persistent_watch_registration, :ok)
         |> register(@persistent_recursive_dir_watch_registration, :ok)
         |> register(@persistent_recursive_node_watch_registration, :ok)}
    end
  end

  describe "a watch registration" do
    test "it can be created by type" do
      assert data_watch_registration(@path, :watcher) == @data_watch_registration
      assert child_watch_registration(@path, :watcher) == @child_watch_registration
      assert exists_watch_registration(@path, :watcher) == @exists_watch_registration
      assert persistent_watch_registration(@path, :watcher) == @persistent_watch_registration

      assert persistent_watch_registration(@path, :watcher, recursive: true) ==
               @persistent_recursive_watch_registration
    end
  end

  describe "a watch manager" do
    test "it can be watched depends on the type and error code" do
      assert should_watch?(:data, :ok) == true
      assert should_watch?(:data, :no_node) == false

      assert should_watch?(:exists, :ok) == true
      assert should_watch?(:exists, :no_node) == true
      assert should_watch?(:exists, :no_auth) == false

      assert should_watch?(:persistent, :no_node) == true
      assert should_watch?(:persistent_recursive, :no_node) == true
    end
  end

  describe "the watch_registration will" do
    test "register a watcher", %{watch_manager: wm} do
      assert empty?(wm)
      assert count(wm) == 0

      wm =
        wm
        |> register(@data_watch_registration, :ok)
        |> register(@exists_watch_registration, :no_node)
        |> register(@child_watch_registration, :ok)
        |> register(@persistent_watch_registration, :no_node)
        |> register(@persistent_recursive_watch_registration, :ok)

      assert count(wm) == 5

      assert watches(wm) |> Enum.to_list() == [
               {:child, @path},
               {:data, @path},
               {:exists, @path},
               {:persistent, @path},
               {:persistent_recursive, @path}
             ]

      assert watches(wm, :data) |> Enum.to_list() == [@path]
      assert watches(wm, :child) |> Enum.to_list() == [@path]
      assert watches(wm, :exists) |> Enum.to_list() == [@path]
      assert watches(wm, :persistent) |> Enum.to_list() == [@path]
      assert watches(wm, :persistent_recursive) |> Enum.to_list() == [@path]
    end

    test "register multiple watchers on the same path", %{watch_manager: wm} do
      wm =
        wm
        |> register(@data_watch_registration, :ok)
        |> register(%{@data_watch_registration | watcher: :watcher2}, :ok)
        |> register(%{@data_watch_registration | watcher: :watcher3}, :ok)

      assert count(wm) == 3

      assert watches(wm) |> Enum.to_list() == [{:data, @path}]
    end

    test "ignore the duplicate watchers on the same path", %{watch_manager: wm} do
      wm =
        wm
        |> register(@data_watch_registration, :ok)
        |> register(@data_watch_registration, :ok)
        |> register(@exists_watch_registration, :no_node)

      assert count(wm) == 2

      assert watches(wm) |> Enum.to_list() == [{:data, @path}, {:exists, @path}]
    end

    test "be ignored when it is nil", %{watch_manager: wm} do
      assert wm |> register(nil, :ok) |> empty?()
    end

    test "be ignored when error is returned", %{
      watch_manager: wm
    } do
      assert wm
             |> register(@data_watch_registration, :no_node)
             |> empty?()
    end
  end

  describe "the watch_deregistration will" do
    test "unregister the child watcher on the given path when type is :children, :persistent or :persistent_recursive",
         %{
           watch_manager: wm
         } do
      assert match?(
               {[:watcher], %WatchManager{watches: w}} when w == %{},
               wm
               |> register(@child_watch_registration, :ok)
               |> unregister(@children_watch_deregistration)
             )

      assert match?(
               {[:watcher], %WatchManager{watches: w}} when w == %{},
               wm
               |> register(@persistent_watch_registration, :ok)
               |> unregister(@persistent_watch_deregistration)
             )

      assert match?(
               {[:watcher], %WatchManager{watches: w}} when w == %{},
               wm
               |> register(@persistent_recursive_watch_registration, :ok)
               |> unregister(@persistent_recursive_watch_deregistration)
             )
    end

    test "unregister the data and exists watcher on the given path when type is :data", %{
      watch_manager: wm
    } do
      assert match?(
               {[:watcher], %WatchManager{watches: w}} when w == %{},
               wm
               |> register(@data_watch_registration, :ok)
               |> register(@exists_watch_registration, :ok)
               |> unregister(@data_watch_deregistration)
             )
    end

    test "unregister the all watcher on the given path when type is :any", %{
      watch_manager: wm
    } do
      assert match?(
               {[:watcher], %WatchManager{watches: w}} when w == %{},
               wm
               |> register(@child_watch_registration, :ok)
               |> register(@data_watch_registration, :ok)
               |> register(@exists_watch_registration, :ok)
               |> register(@persistent_watch_registration, :ok)
               |> register(@persistent_recursive_watch_registration, :ok)
               |> unregister(@any_watch_deregistration)
             )
    end

    test "unregister all watchers on the given path when the watcher is nil",
         %{watch_manager: wm} do
      assert {[:watcher, :watcher2, :watcher3],
              %WatchManager{
                watches: %{
                  child: %{@path => child_watchers}
                }
              }} =
               wm
               |> register(@data_watch_registration, :ok)
               |> register(%{@data_watch_registration | watcher: :watcher2}, :ok)
               |> register(%{@data_watch_registration | watcher: :watcher3}, :ok)
               |> register(@child_watch_registration, :ok)
               |> unregister(%{@data_watch_deregistration | watcher: nil})

      assert child_watchers == MapSet.new([:watcher])
    end

    test "be ignored when the type is not matched", %{
      watch_manager: wm
    } do
      assert {[],
              %WatchManager{
                watches: %{
                  data: %{@path => data_watchers}
                }
              }} =
               wm
               |> register(@data_watch_registration, :ok)
               |> unregister(@children_watch_deregistration)

      assert data_watchers == MapSet.new([:watcher])
    end

    test "be ignored when it is nil", %{watch_manager: wm} do
      assert {[],
              %WatchManager{
                watches: %{
                  data: %{@path => data_watchers}
                }
              }} =
               wm
               |> register(@data_watch_registration, :ok)
               |> unregister(nil)

      assert data_watchers == MapSet.new([:watcher])
    end

    test "be ignored when the path is not matched", %{
      watch_manager: wm
    } do
      assert {[],
              %WatchManager{
                watches: %{
                  data: %{@path => data_watchers}
                }
              }} =
               wm
               |> register(@data_watch_registration, :ok)
               |> unregister(%{@data_watch_deregistration | path: "/foo"})

      assert data_watchers == MapSet.new([:watcher])
    end
  end

  describe "materialize the watchers on the given event" do
    test "will got nothing when watchers are not registered", %{watch_manager: wm} do
      assert {[], %WatchManager{}} = materialize(wm, :node_created, @path)
    end

    test "will got nothing when the path is not matched", %{watch_manager_with_watchers: wm} do
      assert {[], %WatchManager{}} = materialize(wm, :node_children_changed, @dir)
    end

    test "will got :data, :exists and :persistent watchers on the :node_created or :node_data_changed event",
         %{watch_manager_with_watchers: wm} do
      for type <- [:node_created, :node_data_changed] do
        assert {[:watcher, :dir_watcher, :node_watcher], %WatchManager{watches: watches}} =
                 wm |> materialize(type, @path)

        assert watches == %{
                 child: %{@path => MapSet.new([:watcher])},
                 persistent: %{@path => MapSet.new([:watcher])},
                 persistent_recursive: %{
                   @dir => MapSet.new([:dir_watcher]),
                   @path => MapSet.new([:node_watcher])
                 }
               }
      end
    end

    test "will got :child and :persistent watchers on the :node_children_changed event",
         %{watch_manager_with_watchers: wm} do
      assert {[:watcher], %WatchManager{watches: watches}} =
               wm |> materialize(:node_children_changed, @path)

      assert watches == %{
               persistent: %{@path => MapSet.new([:watcher])},
               data: %{@path => MapSet.new([:watcher])},
               exists: %{@path => MapSet.new([:watcher])},
               persistent_recursive: %{
                 @dir => MapSet.new([:dir_watcher]),
                 @path => MapSet.new([:node_watcher])
               }
             }
    end

    test "will got :child, :data, :exists, and :persistent watchers on the :node_deleted event",
         %{watch_manager_with_watchers: wm} do
      assert {[:watcher, :dir_watcher, :node_watcher], %WatchManager{watches: watches}} =
               wm |> materialize(:node_deleted, @path)

      assert watches == %{
               persistent: %{@path => MapSet.new([:watcher])},
               persistent_recursive: %{
                 @dir => MapSet.new([:dir_watcher]),
                 @path => MapSet.new([:node_watcher])
               }
             }
    end
  end

  describe "some watchers" do
    test "will got :data, :exists and :persistent watchers on the :node_created or :node_data_changed event",
         %{watch_manager: wm} do
      wm =
        wm
        |> register(data_watch_registration(@path, self()), :ok)
        |> register(exists_watch_registration(@path, self()), :ok)
        |> register(child_watch_registration(@path, self()), :ok)
        |> register(persistent_watch_registration(@path, self()), :ok)
        |> register(persistent_watch_registration(@dir, self(), recursive: true), :ok)
        |> register(persistent_watch_registration(@path, self(), recursive: true), :ok)

      for type <- [:node_created, :node_data_changed] do
        assert match?(
                 %WatchManager{
                   watches: %{child: %{}, persistent: %{}, persistent_recursive: %{}} = wm
                 }
                 when not is_map_key(wm, :data) and not is_map_key(wm, :exists),
                 wm |> process_event(%WatchedEvent{type: type, path: @path, zxid: @zxid})
               )

        assert_receive {^type, @path, @zxid}
      end
    end

    test "will got :child and :persistent watchers on the :node_children_changed event",
         %{watch_manager: wm} do
      wm =
        wm
        |> register(data_watch_registration(@path, self()), :ok)
        |> register(exists_watch_registration(@path, self()), :ok)
        |> register(child_watch_registration(@path, self()), :ok)
        |> register(persistent_watch_registration(@path, self()), :ok)
        |> register(persistent_watch_registration(@dir, self(), recursive: true), :ok)
        |> register(persistent_watch_registration(@path, self(), recursive: true), :ok)

      assert match?(
               %WatchManager{
                 watches:
                   %{data: %{}, exists: %{}, persistent: %{}, persistent_recursive: %{}} = wm
               }
               when not is_map_key(wm, :child),
               wm
               |> process_event(%WatchedEvent{
                 type: :node_children_changed,
                 path: @path,
                 zxid: @zxid
               })
             )

      assert_receive {:node_children_changed, @path, @zxid}
    end

    test "will got :child, :data, :exists, and :persistent watchers on the :node_deleted event",
         %{watch_manager: wm} do
      wm =
        wm
        |> register(data_watch_registration(@path, self()), :ok)
        |> register(exists_watch_registration(@path, self()), :ok)
        |> register(child_watch_registration(@path, self()), :ok)
        |> register(persistent_watch_registration(@path, self()), :ok)
        |> register(persistent_watch_registration(@dir, self(), recursive: true), :ok)
        |> register(persistent_watch_registration(@path, self(), recursive: true), :ok)

      assert match?(
               %WatchManager{
                 watches: %{persistent: %{}, persistent_recursive: %{}} = wm
               }
               when not is_map_key(wm, :child) and not is_map_key(wm, :data) and
                      not is_map_key(wm, :exists),
               wm
               |> process_event(%WatchedEvent{
                 type: :node_deleted,
                 path: @path,
                 zxid: @zxid
               })
             )

      assert_receive {:node_deleted, @path, @zxid}
    end
  end
end
