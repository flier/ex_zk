defmodule UtilTest do
  use ExUnit.Case, async: true

  use ExZk.Defs

  import Mock

  alias ExZk.Data.Stat
  alias ExZk.{Multi, Session, Util}

  @stat %Stat{}

  @bfs_nodes [
    "/foo",
    "/foo/bar",
    "/foo/baz",
    "/foo/bar/a",
    "/foo/bar/b",
    "/foo/bar/c",
    "/foo/baz/x",
    "/foo/baz/y",
    "/foo/baz/z"
  ]

  @dfs_nodes [
    "/foo",
    "/foo/bar",
    "/foo/bar/a",
    "/foo/bar/b",
    "/foo/bar/c",
    "/foo/baz",
    "/foo/baz/x",
    "/foo/baz/y",
    "/foo/baz/z"
  ]

  @cfs_nodes [
    "/foo/bar/a",
    "/foo/bar/b",
    "/foo/bar/c",
    "/foo/bar",
    "/foo/baz/x",
    "/foo/baz/y",
    "/foo/baz/z",
    "/foo/baz",
    "/foo"
  ]

  setup_with_mocks([
    {Session, [],
     [
       delete: fn :session, _path, @any_version, _timeout -> :ok end,
       get_children: fn
         :session, "/foo" -> {:ok, ["bar", "baz"]}
         :session, "/foo/bar" -> {:ok, ["a", "b", "c"]}
         :session, "/foo/bar/a" -> {:ok, []}
         :session, "/foo/bar/b" -> {:ok, []}
         :session, "/foo/bar/c" -> {:ok, []}
         :session, "/foo/baz" -> {:ok, ["x", "y", "z"]}
         :session, "/foo/baz/x" -> {:ok, []}
         :session, "/foo/baz/y" -> {:ok, []}
         :session, "/foo/baz/z" -> {:ok, []}
       end,
       get_children: fn
         :session, "/foo", _watch -> {:ok, ["bar", "baz"]}
         :session, "/foo/bar", _watch -> {:ok, ["a", "b", "c"]}
         :session, "/foo/bar/a", _watch -> {:ok, []}
         :session, "/foo/bar/b", _watch -> {:ok, []}
         :session, "/foo/bar/c", _watch -> {:ok, []}
         :session, "/foo/baz", _watch -> {:ok, ["x", "y", "z"]}
         :session, "/foo/baz/x", _watch -> {:ok, []}
         :session, "/foo/baz/y", _watch -> {:ok, []}
         :session, "/foo/baz/z", _watch -> {:ok, []}
       end,
       get_data: fn
         :session, "/foo", _watch -> {:ok, "", @stat}
       end,
       multi: fn
         :session, ops, _timeout -> {:ok, ops |> Enum.map(fn _op -> {:delete, :ok} end)}
       end
     ]}
  ]) do
    :ok
  end

  describe "given a tree of nodes" do
    test "it could be list recursively in BFS" do
      assert Util.list_subtree(:session, "/foo", :bfs) |> Enum.to_list() == @bfs_nodes

      for path <- @bfs_nodes do
        assert_called(Session.get_children(:session, path, false))
      end
    end

    test "it could be list recursively in BFS with watch" do
      assert Util.list_subtree(:session, "/foo", :bfs, true) |> Enum.to_list() ==
               @bfs_nodes

      assert_called(Session.get_data(:session, "/foo", true))

      for path <- @bfs_nodes do
        assert_called(Session.get_children(:session, path, true))
      end
    end

    test "it could be list recursively in DFS" do
      assert Util.list_subtree(:session, "/foo", :dfs) |> Enum.to_list() == @dfs_nodes

      for path <- @dfs_nodes do
        assert_called(Session.get_children(:session, path, false))
      end
    end

    test "it could be list recursively in DFS with watch" do
      assert Util.list_subtree(:session, "/foo", :dfs, true) |> Enum.to_list() ==
               @dfs_nodes

      assert_called(Session.get_data(:session, "/foo", true))

      for path <- @dfs_nodes do
        assert_called(Session.get_children(:session, path, true))
      end
    end

    test "it could be list recursively in CFS" do
      assert Util.list_subtree(:session, "/foo", :cfs) |> Enum.to_list() == @cfs_nodes

      for path <- @cfs_nodes do
        assert_called(Session.get_children(:session, path, false))
      end
    end

    test "it could be list recursively in CFS with watch" do
      assert Util.list_subtree(:session, "/foo", :cfs, true) |> Enum.to_list() ==
               @cfs_nodes

      assert_called(Session.get_data(:session, "/foo", true))

      for path <- @cfs_nodes do
        assert_called(Session.get_children(:session, path, true))
      end
    end

    test "it could be delete recursively in CFS one by one" do
      assert Util.delete_recursive(:session, "/foo", 0) == :ok

      for path <- @cfs_nodes do
        assert_called(Session.get_children(:session, path, false))
        assert_called(Session.delete(:session, path, @any_version, @default_timeout))
      end
    end

    test "it could be delete recursively in CFS in batch" do
      assert Util.delete_recursive(:session, "/foo") == :ok

      for path <- @cfs_nodes do
        assert_called(Session.get_children(:session, path, false))
      end

      assert_called(
        Session.multi(:session, @cfs_nodes |> Enum.map(&Multi.Op.delete/1), @default_timeout)
      )
    end
  end
end
