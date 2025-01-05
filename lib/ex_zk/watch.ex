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

  @callback process_event(event :: WatchedEvent.t()) :: :ok

  defmacro __using__(_opts) do
    quote do
      @behaviour ExZk.Watcher
    end
  end
end

defmodule ExZk.WatchedEvent do
  alias ExZk.Watcher.Event.{KeeperState, Type}

  defstruct [:state, :type, :path, :zxid]

  @type t :: %__MODULE__{
          state: KeeperState.t(),
          type: Type.t(),
          path: Path.t(),
          zxid: zxid()
        }

  @type zxid :: integer()
end

defmodule ExZk.StateWatcher do
  @moduledoc """
  StateWatcher tracks session state updates.
  """

  import ExZk.Watcher.Event.KeeperState
  alias ExZk.Watcher.Event.KeeperState

  @type t :: Process.dest() | module() | function() | {module(), atom()}

  @doc """
  The session state has changed
  """
  @callback session_state_changed(KeeperState.t()) :: :ok

  @callback session_disconnected :: :ok
  @callback session_sync_connected :: :ok
  @callback session_auth_failed :: :ok
  @callback session_connected_readonly :: :ok
  @callback session_sasl_authenticated :: :ok
  @callback session_closed :: :ok
  @callback session_expired :: :ok

  @optional_callbacks session_disconnected: 0,
                      session_sync_connected: 0,
                      session_auth_failed: 0,
                      session_connected_readonly: 0,
                      session_sasl_authenticated: 0,
                      session_closed: 0,
                      session_expired: 0

  @doc false
  @spec state_changed(t(), KeeperState.t()) :: :ok
  def state_changed(watcher, state)

  def state_changed(watcher, state) when is_pid(watcher) and is_keeper_state(state) do
    send(watcher, {:session_state, state})

    :ok
  end

  def state_changed(func, state) when is_function(func, 1) and is_keeper_state(state),
    do: func.(state)

  def state_changed(module_or_name, state)
      when is_atom(module_or_name) and is_keeper_state(state) do
    cond do
      function_exported?(module_or_name, state_function(state), 0) ->
        apply(module_or_name, state_function(state), [])

      function_exported?(module_or_name, :session_state_changed, 1) ->
        module_or_name.session_state_changed(state)

      true ->
        send(module_or_name, {:session_state, state})

        :ok
    end
  end

  def state_changed({module, func}, state)
      when is_atom(module) and is_atom(func) and is_keeper_state(state),
      do: apply(module, func, [state])

  @doc false
  def state_function(state), do: "session_#{Atom.to_string(state)}" |> String.to_atom()

  defmacro __using__(_opts) do
    quote do
      @behaviour ExZk.StateWatcher

      @doc false
      def session_state_changed(state) do
        if function_exported?(__MODULE__, ExZk.StateWatcher.state_function(state), 0) do
          apply(__MODULE__, ExZk.StateWatcher.state_function(state), [])
        else
          :ok
        end
      end

      defoverridable session_state_changed: 1
    end
  end
end

defmodule ExZk.NodeWatcher do
  import ExZk.Watcher.Event.Type
  alias ExZk.Watcher.Event.Type

  @type t :: Process.dest() | module() | function() | {module(), atom()}

  @type zxid :: integer()
  @type event :: {Type.t(), Path.t(), zxid()}

  @moduledoc """
  Callback module for watching node changes
  """
  @callback node_changed(event()) :: :ok

  @doc """
  A node has been created
  """
  @callback node_created(Path.t(), zxid()) :: :ok

  @doc """
  A node has been deleted
  """
  @callback node_deleted(Path.t(), zxid()) :: :ok

  @doc """
  A node data has been changed
  """
  @callback node_data_changed(Path.t(), zxid()) :: :ok

  @doc """
  A node children has been changed
  """
  @callback node_children_changed(Path.t(), zxid()) :: :ok

  @optional_callbacks node_created: 2,
                      node_deleted: 2,
                      node_data_changed: 2,
                      node_children_changed: 2

  @doc false
  @spec node_changed(t(), event()) :: :ok
  def node_changed(watcher, event)

  def node_changed(watcher, {type, path, zxid})
      when is_pid(watcher) and is_type(type) and is_binary(path) and is_integer(zxid) do
    send(watcher, {type, path, zxid})

    :ok
  end

  def node_changed(func, {type, path, zxid}) when is_function(func, 1),
    do: func.({type, path, zxid})

  def node_changed(module_or_name, {type, path, zxid})
      when is_atom(module_or_name) and is_type(type) and is_binary(path) and is_integer(zxid) do
    cond do
      function_exported?(module_or_name, type, 2) ->
        apply(module_or_name, type, [path, zxid])

      function_exported?(module_or_name, :node_changed, 1) ->
        module_or_name.node_changed({type, path, zxid})

      true ->
        send(module_or_name, {type, path, zxid})

        :ok
    end
  end

  def node_changed({module, func}, {type, path, zxid})
      when is_atom(module) and is_atom(func) and is_type(type) and is_binary(path) and
             is_integer(zxid),
      do: apply(module, func, [{type, path, zxid}])

  defmacro __using__(_opts) do
    quote do
      @behaviour ExZk.NodeWatcher

      def node_changed({type, path, zxid}) do
        if function_exported?(__MODULE__, type, 2) do
          apply(__MODULE__, type, [path, zxid])
        else
          :ok
        end
      end

      defoverridable node_changed: 1
    end
  end
end

defmodule ExZk.WatchManager do
  alias ExZk.NodeWatcher

  defstruct data_watches: %{},
            exist_watches: %{},
            child_watches: %{},
            persistent_watches: %{},
            persistent_recursive_watches: %{}

  @type t :: %__MODULE__{
          data_watches: %{String.t() => MapSet.t(NodeWatcher.t())},
          exist_watches: %{String.t() => MapSet.t(NodeWatcher.t())},
          child_watches: %{String.t() => MapSet.t(NodeWatcher.t())},
          persistent_watches: %{String.t() => MapSet.t(NodeWatcher.t())},
          persistent_recursive_watches: %{String.t() => MapSet.t(NodeWatcher.t())}
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
      wm.data_watches |> Map.keys() |> Stream.map(&{:data, &1}),
      wm.exist_watches |> Map.keys() |> Stream.map(&{:exists, &1}),
      wm.child_watches |> Map.keys() |> Stream.map(&{:child, &1}),
      wm.persistent_watches |> Map.keys() |> Stream.map(&{:persistent, &1}),
      wm.persistent_recursive_watches |> Map.keys() |> Stream.map(&{:persistent_recursive, &1})
    ]
    |> Stream.concat()
  end

  @type watcher ::
          {:child, NodeWatcher.t()}
          | {:data, NodeWatcher.t()}
          | {:exists, NodeWatcher.t()}
          | {:persistent, NodeWatcher.t()}
          | {:persistent_recursive, NodeWatcher.t()}

  @spec register(t(), Path.t(), watcher()) :: map()
  def register(watch_manager, path, watcher)

  def register(%__MODULE__{data_watches: data_watches}, path, {:data, watcher}) do
    data_watches
    |> Map.update(IO.chardata_to_string(path), MapSet.new([watcher]), &MapSet.put(&1, watcher))
  end

  def register(%__MODULE__{exist_watches: exist_watches}, path, {:exists, watcher}) do
    exist_watches
    |> Map.update(IO.chardata_to_string(path), MapSet.new([watcher]), &MapSet.put(&1, watcher))
  end

  def register(%__MODULE__{child_watches: child_watches}, path, {:child, watcher}) do
    child_watches
    |> Map.update(IO.chardata_to_string(path), MapSet.new([watcher]), &MapSet.put(&1, watcher))
  end

  def register(%__MODULE__{persistent_watches: persistent_watches}, path, {:persistent, watcher}) do
    persistent_watches
    |> Map.update(IO.chardata_to_string(path), MapSet.new([watcher]), &MapSet.put(&1, watcher))
  end

  def register(
        %__MODULE__{persistent_recursive_watches: persistent_recursive_watches},
        path,
        {:persistent_recursive, watcher}
      ) do
    persistent_recursive_watches
    |> Map.update(
      IO.chardata_to_string(path),
      MapSet.new([watcher]),
      &MapSet.put(&1, watcher)
    )
  end
end
