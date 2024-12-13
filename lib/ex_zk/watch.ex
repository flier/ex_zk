defmodule ExZk.Watcher do
  import ExZk.TypedEnum
  alias ExZk.WatchedEvent

  defmodule Event do
    import ExZk.TypedEnum

    defenum(KeeperState,
      unknown: -1,
      disconnected: 0,
      no_sync_connected: 1,
      sync_connected: 2,
      auth_failed: 4,
      connected_readonly: 5,
      sasl_authenticated: 6,
      closed: 7,
      expired: -112
    )

    defenum(Type,
      none: -1,
      node_created: 1,
      node_deleted: 2,
      node_data_changed: 3,
      node_children_changed: 4,
      data_watch_removed: 5,
      child_watch_removed: 6,
      persistent_watch_removed: 7
    )
  end

  defenum(Type,
    children: 1,
    data: 2,
    persistent: 4,
    persistent_recursive: 5,
    any: 3
  )

  @callback process(event :: WatchedEvent.t()) :: :ok
end

defmodule ExZk.WatchedEvent do
  alias ExZk.Watcher.Event.{KeeperState, Type}

  defstruct [:state, :type, :path, :zxid]

  @type t :: %__MODULE__{
          state: KeeperState.t(),
          type: Type.t(),
          path: String.t(),
          zxid: integer()
        }
end

defmodule ExZk.WatchManager do
  defstruct data_watches: %{},
            exist_watches: %{},
            child_watches: %{},
            persistent_watches: %{},
            persistent_recursive_watches: %{}

  @type t :: %__MODULE__{
          data_watches: %{String.t() => MapSet.t()},
          exist_watches: %{String.t() => MapSet.t()},
          child_watches: %{String.t() => MapSet.t()},
          persistent_watches: %{String.t() => MapSet.t()},
          persistent_recursive_watches: %{String.t() => MapSet.t()}
        }

  def empty?(%__MODULE__{} = wm) do
    map_size(wm.data_watches) == 0 and
      map_size(wm.exist_watches) == 0 and
      map_size(wm.child_watches) == 0 and
      map_size(wm.persistent_watches) == 0 and
      map_size(wm.persistent_recursive_watches) == 0
  end

  def watches(%__MODULE__{} = wm) do
    [
      wm.data_watches |> Map.keys() |> Enum.map(&{:data, &1}),
      wm.exist_watches |> Map.keys() |> Enum.map(&{:exists, &1}),
      wm.child_watches |> Map.keys() |> Enum.map(&{:child, &1}),
      wm.persistent_watches |> Map.keys() |> Enum.map(&{:persistent, &1}),
      wm.persistent_recursive_watches |> Map.keys() |> Enum.map(&{:persistent_recursive, &1})
    ]
    |> Enum.concat()
  end

  @spec register(
          ExZk.WatchManager.t(),
          path :: String.t(),
          {:child, any()}
          | {:data, any()}
          | {:exists, any()}
          | {:persistent, any()}
          | {:persistent_recursive, any()}
        ) :: map()
  def register(%__MODULE__{data_watches: data_watches}, path, {:data, watcher}) do
    Map.update(data_watches, path, MapSet.new([watcher]), &MapSet.put(&1, watcher))
  end

  def register(%__MODULE__{exist_watches: exist_watches}, path, {:exists, watcher}) do
    Map.update(exist_watches, path, MapSet.new([watcher]), &MapSet.put(&1, watcher))
  end

  def register(%__MODULE__{child_watches: child_watches}, path, {:child, watcher}) do
    Map.update(child_watches, path, MapSet.new([watcher]), &MapSet.put(&1, watcher))
  end

  def register(%__MODULE__{persistent_watches: persistent_watches}, path, {:persistent, watcher}) do
    Map.update(persistent_watches, path, MapSet.new([watcher]), &MapSet.put(&1, watcher))
  end

  def register(
        %__MODULE__{persistent_recursive_watches: persistent_recursive_watches},
        path,
        {:persistent_recursive, watcher}
      ) do
    Map.update(
      persistent_recursive_watches,
      path,
      MapSet.new([watcher]),
      &MapSet.put(&1, watcher)
    )
  end
end
