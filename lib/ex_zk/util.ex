defmodule ExZk.Util do
  use ExZk.Defs

  alias ExZk.{Error, Multi, Session}

  @type session :: Session.session()

  @doc """
  Recursively delete the node with the given path.

  Important: All versions, of all nodes, under the given node are deleted.
  """
  @spec delete_recursive(session(), Path.t(), batch_size :: non_neg_integer(), timeout() | nil) ::
          :ok | {:error, Error.t() | [Error.t()]}
  def delete_recursive(
        session,
        path,
        batch_size \\ @default_batch_size,
        timeout \\ @default_timeout
      )

  def delete_recursive(session, path, 0, timeout),
    do:
      list_subtree(session, path, :cfs)
      |> Stream.map(&Session.delete(session, &1, @any_version, timeout))
      |> Enum.reduce(:ok, &merge_results(&1, &2))

  def delete_recursive(session, path, batch_size, timeout)
      when batch_size > 0 do
    list_subtree(session, path, :cfs)
    |> Stream.chunk_every(batch_size)
    |> Stream.map(&delete_in_batch(session, &1, timeout))
    |> Enum.reduce(:ok, &merge_results(&1, &2))
  end

  defp delete_in_batch(session, tree, timeout),
    do: Session.multi(session, tree |> Enum.map(&Multi.Op.delete/1), timeout)

  defp merge_results(:ok, :ok), do: :ok
  defp merge_results(:ok, {:error, err}), do: {:error, err}
  defp merge_results({:ok, _}, {:error, err}), do: {:error, err}
  defp merge_results({:ok, _}, :ok), do: :ok
  defp merge_results({:error, err}, :ok), do: {:error, err}
  defp merge_results({:error, err}, {:error, errs}) when is_list(errs), do: {:error, [err | errs]}
  defp merge_results({:error, err}, {:error, errs}), do: {:error, [err, errs]}

  @doc """
  BFS Traversal of the system under pathRoot, with the entries in the list, in the same order as that of the traversal.
  """
  @spec list_subtree(session(), Path.t(), strategy :: :bfs | :dfs | :cfs, watch :: boolean()) ::
          Enumerable.t() | {:error, reason :: term()}
  def list_subtree(session, dir, strategy \\ :bfs, watch \\ false) do
    with {:ok, _data, _stat} <- Session.get_data(session, dir, watch) do
      case strategy do
        :bfs -> Stream.concat([dir], list_subtree_bfs(session, dir, watch))
        :dfs -> Stream.concat([dir], list_subtree_dfs(session, dir, watch))
        :cfs -> Stream.concat(list_subtree_cfs(session, dir, watch), [dir])
      end
    end
  end

  defp list_subtree_bfs(session, root, watch) do
    Stream.unfold(:queue.from_list([root]), fn
      dirs ->
        case :queue.out(dirs) do
          {:empty, _} ->
            nil

          {{:value, dir}, dirs} ->
            list_subtree_bfs_children(session, dirs, dir, watch)
        end
    end)
    |> Stream.concat()
  end

  defp list_subtree_bfs_children(session, dirs, dir, watch) do
    case Session.get_children(session, dir, watch) do
      {:ok, children} ->
        children = children |> Enum.sort() |> Enum.map(&Path.join(dir, &1))
        dirs = dirs |> :queue.join(:queue.from_list(children))

        {children, dirs}

      {:error, _err} ->
        {[], dirs}
    end
  end

  defp list_subtree_dfs(session, dir, watch) do
    case Session.get_children(session, dir, watch) do
      {:ok, children} ->
        children
        |> Enum.sort()
        |> Stream.map(&Path.join(dir, &1))
        |> Stream.flat_map(fn path ->
          [path] |> Stream.concat(list_subtree_dfs(session, path, watch))
        end)

      {:error, _err} ->
        []
    end
  end

  defp list_subtree_cfs(session, dir, watch) do
    case Session.get_children(session, dir, watch) do
      {:ok, children} ->
        children
        |> Enum.sort()
        |> Stream.map(&Path.join(dir, &1))
        |> Stream.flat_map(fn path ->
          list_subtree_cfs(session, path, watch) |> Stream.concat([path])
        end)

      {:error, _err} ->
        []
    end
  end
end
