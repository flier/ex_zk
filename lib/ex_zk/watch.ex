defmodule ExZk.Watcher do
  import ExZk.TypedEnum

  alias ExZk.{NodeWatcher, WatchedEvent}

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

  @type type :: :data | :exists | :child | :persistent | :persistent_recursive

  defguard is_watcher_type(type)
           when type in [:data, :exists, :child, :persistent, :persistent_recursive]

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
  require ExZk.Watcher.Event.Type

  alias ExZk.{WatchedEvent, Watcher.Event.Type}

  @type t :: Process.dest() | module() | function() | {module(), atom()}

  @type zxid :: integer()

  @moduledoc """
  Callback module for watching node changes
  """
  @callback node_changed(WatchedEvent.t()) :: :ok

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
  @spec node_changed(t(), WatchedEvent.t()) :: :ok
  def node_changed(watcher, event)

  def node_changed(watcher, %WatchedEvent{type: type, path: path, zxid: zxid})
      when is_pid(watcher) and Type.is_type(type) and is_binary(path) and is_integer(zxid) do
    send(watcher, {type, path, zxid})

    :ok
  end

  def node_changed(func, %WatchedEvent{type: type, path: path, zxid: zxid})
      when is_function(func, 1),
      do: func.({type, path, zxid})

  def node_changed(module_or_name, %WatchedEvent{type: type, path: path, zxid: zxid})
      when is_atom(module_or_name) and Type.is_type(type) and is_binary(path) and is_integer(zxid) do
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

  def node_changed({module, func}, %WatchedEvent{type: type, path: path, zxid: zxid})
      when is_atom(module) and is_atom(func) and Type.is_type(type) and is_binary(path) and
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

defmodule ExZk.WatchRegistration do
  @moduledoc """
  Register a watcher for a particular path.
  """

  alias ExZk.{Defs.ErrCode, NodeWatcher, Watcher}

  defstruct [:type, :path, :watcher]

  @type t :: %__MODULE__{
          type: Watcher.type(),
          path: Path.t(),
          watcher: NodeWatcher.t()
        }

  @spec data_watch_registration(Path.t(), NodeWatcher.t()) :: t()
  def data_watch_registration(path, watcher),
    do: %__MODULE__{type: :data, path: path, watcher: watcher}

  @spec exists_watch_registration(Path.t(), NodeWatcher.t()) :: t()
  def exists_watch_registration(path, watcher),
    do: %__MODULE__{type: :exists, path: path, watcher: watcher}

  @spec child_watch_registration(Path.t(), NodeWatcher.t()) :: t()
  def child_watch_registration(path, watcher),
    do: %__MODULE__{type: :child, path: path, watcher: watcher}

  @spec persistent_watch_registration(Path.t(), NodeWatcher.t(), [{:recursive, boolean()}]) :: t()
  def persistent_watch_registration(path, watcher, opts \\ []),
    do: %__MODULE__{
      type:
        if(Keyword.get(opts, :recursive, false), do: :persistent_recursive, else: :persistent),
      path: path,
      watcher: watcher
    }
end

defmodule ExZk.WatchDeregistration do
  @moduledoc """
  Handles the special case of removing watches which has registered for a server path
  """

  import ExZk.Watcher.Type

  alias ExZk.{NodeWatcher, Watcher}

  defstruct [:type, :path, :watcher]

  @type t :: %__MODULE__{
          type: Watcher.Type.t(),
          path: Path.t(),
          watcher: NodeWatcher.t() | nil
        }

  @spec new(Watcher.Type.t(), Path.t(), NodeWatcher.t() | nil) :: t()
  def new(type \\ :any, path, watcher \\ nil) when is_type(type),
    do: %__MODULE__{type: type, path: path, watcher: watcher}

  @spec children_watch_deregistration(Path.t(), NodeWatcher.t() | nil) :: t()
  def children_watch_deregistration(path, watcher \\ nil), do: new(:children, path, watcher)

  @spec data_watch_deregistration(Path.t(), NodeWatcher.t() | nil) :: t()
  def data_watch_deregistration(path, watcher \\ nil), do: new(:data, path, watcher)

  @spec persistent_watch_deregistration(Path.t(), NodeWatcher.t() | nil, [{:recursive, boolean()}]) ::
          t()
  def persistent_watch_deregistration(path, watcher \\ nil, opts \\ []) do
    type =
      if Keyword.get(opts, :recursive, false) do
        :persistent_recursive
      else
        :persistent
      end

    new(type, path, watcher)
  end

  @spec any_watch_deregistration(Path.t(), NodeWatcher.t() | nil) :: t()
  def any_watch_deregistration(path, watcher \\ nil), do: new(:any, path, watcher)
end

defmodule ExZk.WatchManager do
  @moduledoc """
  Manage watchers and handle events generated by the `ExZk.Session`.
  """

  import ExZk.Watcher
  import ExZk.Watcher.Event.Type

  alias ExZk.WatchedEvent

  alias ExZk.{
    Defs.ErrCode,
    NodeWatcher,
    WatchDeregistration,
    Watcher,
    Watcher.Event,
    WatchRegistration
  }

  defstruct watches: %{},
            task_sup: nil,
            default_watcher: nil

  @type t :: %__MODULE__{
          watches: watches_by_type(),
          task_sup: pid(),
          default_watcher: NodeWatcher.t() | nil
        }

  @type watches_by_type :: %{Watcher.type() => watches()}
  @type watches :: %{String.t() => watchers()}
  @type watchers :: MapSet.t(NodeWatcher.t())

  ####
  ## Public API
  ##

  @spec new(NodeWatcher.t() | nil) ::
          {:ok, t()} | {:error, reason :: term()} | {:shutdown, reason :: term()}
  def new(default_watcher) do
    with {:ok, task_sup} <- Task.Supervisor.start_link() do
      {:ok, %__MODULE__{watches: %{}, task_sup: task_sup, default_watcher: default_watcher}}
    end
  end

  @doc """
  Returns true if the watch manager is empty
  """
  @spec empty?(t()) :: boolean
  def empty?(%__MODULE__{watches: watches}), do: map_size(watches) == 0

  @doc """
  Returns the number of watching paths in the watch manager
  """
  @spec count(t()) :: non_neg_integer
  def count(%__MODULE__{watches: watches}),
    do:
      watches
      |> Map.values()
      |> Stream.flat_map(fn watches -> watches |> Map.values() |> Stream.map(&MapSet.size/1) end)
      |> Enum.sum()

  @doc """
  Returns all the watching paths in the watch manager
  """
  @spec watches(t()) :: Enumerable.t({Watcher.type(), Path.t()})
  def watches(%__MODULE__{watches: watches}) do
    watches
    |> Map.to_list()
    |> Enum.sort_by(fn {type, _} -> type end)
    |> Stream.flat_map(fn {type, watches} ->
      watches |> Map.keys() |> Enum.sort() |> Stream.map(&{type, &1})
    end)
  end

  @doc """
  Returns all the watching paths of a particular type
  """
  @spec watches(t(), Watcher.type()) :: [Path.t()]
  def watches(%__MODULE__{watches: watches}, type),
    do: watches |> Map.get(type, []) |> Map.keys()

  defguard should_watch?(type, err)
           when (type in [:exists, :persistent, :persistent_recursive] and
                   err in [:ok, :no_node]) or
                  err == :ok

  @doc """
  Register a watcher for a path
  """
  @spec register(t(), WatchRegistration.t(), ErrCode.t()) :: t()
  def register(watch_manager, watch_registration, err)

  def register(
        %__MODULE__{watches: watches} = wm,
        %WatchRegistration{type: type, path: path, watcher: watcher},
        err
      )
      when is_watcher_type(type) and should_watch?(type, err) do
    path = IO.chardata_to_string(path)

    {_current_value, watches} =
      Map.get_and_update(watches, type, fn
        nil ->
          {nil, %{path => MapSet.new([watcher])}}

        watches ->
          {watches, add_watcher(watches, path, watcher)}
      end)

    %{wm | watches: watches}
  end

  def register(%__MODULE__{} = wm, _watch_registration, _err), do: wm

  @doc """
  Unregister a watcher
  """
  @spec unregister(t(), WatchDeregistration.t() | nil) :: {[NodeWatcher.t()], t()}
  def unregister(watch_manager, watch_deregistration)

  def unregister(%__MODULE__{} = wm, nil), do: {[], wm}

  def unregister(%__MODULE__{} = wm, %WatchDeregistration{
        type: :children,
        path: path,
        watcher: watcher
      }),
      do: remove_watches(wm, [:child], path, watcher)

  def unregister(%__MODULE__{} = wm, %WatchDeregistration{
        type: :data,
        path: path,
        watcher: watcher
      }),
      do: remove_watches(wm, [:data, :exists], path, watcher)

  def unregister(%__MODULE__{} = wm, %WatchDeregistration{
        type: type,
        path: path,
        watcher: watcher
      })
      when type in [:persistent, :persistent_recursive],
      do: remove_watches(wm, [type], path, watcher)

  def unregister(%__MODULE__{} = wm, %WatchDeregistration{
        type: :any,
        path: path,
        watcher: watcher
      }),
      do:
        remove_watches(
          wm,
          [:child, :data, :exists, :persistent, :persistent_recursive],
          path,
          watcher
        )

  @spec materialize(t(), Event.Type.t(), Path.t()) :: {[NodeWatcher.t()], t()}
  def materialize(watch_manager, type, path)

  def materialize(
        %__MODULE__{watches: watches, default_watcher: default_watcher} = wm,
        :none,
        _path
      ) do
    {removed, watches} = watches |> Map.split([:data, :exists, :child])

    watchers = if default_watcher, do: [default_watcher], else: []
    watchers = extract_watchers([removed, watches], MapSet.new(watchers))

    {watchers, %{wm | watches: watches}}
  end

  def materialize(%__MODULE__{} = wm, type, path)
      when type in [:node_created, :node_data_changed],
      do: take_watchers(wm, [:data, :exists], path, true)

  def materialize(%__MODULE__{} = wm, :node_children_changed, path),
    do: take_watchers(wm, [:child], path, false)

  def materialize(%__MODULE__{} = wm, :node_deleted, path),
    do: take_watchers(wm, [:data, :exists, :child], path, true)

  def materialize(%__MODULE__{} = wm, type, _path) when is_type(type), do: {[], wm}

  @spec process_event(t(), WatchedEvent.t()) :: t()
  def process_event(
        %__MODULE__{task_sup: task_sup} = wm,
        %WatchedEvent{type: type, path: path} = evt
      ) do
    {watchers, wm} = materialize(wm, type, path)

    Task.Supervisor.async_stream_nolink(task_sup, watchers, fn watcher ->
      if is_atom(watcher) && function_exported?(watcher, :process_event, 1) do
        watcher.process_event(evt)
      else
        NodeWatcher.node_changed(watcher, evt)
      end
    end)
    |> Stream.run()

    wm
  end

  ####
  ## Private methods
  ##

  defp add_watcher(watches, path, watcher),
    do: watches |> Map.update(path, MapSet.new([watcher]), &MapSet.put(&1, watcher))

  @spec remove_watches(t(), [Watcher.type()], Path.t(), NodeWatcher.t() | nil) ::
          {[NodeWatcher.t()], t()}
  defp remove_watches(%__MODULE__{watches: watches} = wm, types, path, watcher)
       when is_list(types) do
    {watchers, watches} =
      types
      |> Enum.flat_map_reduce(watches, fn type, watches ->
        case remove_watches_by_type(watches, type, path, watcher) do
          {nil, watches} ->
            {[], watches}

          {w, watches} ->
            {w
             |> Map.values()
             |> Stream.filter(fn w -> !is_nil(w) end)
             |> Enum.reduce(MapSet.new(), &MapSet.union(&1, &2))
             |> MapSet.to_list(), watches}
        end
      end)

    {watchers |> Enum.uniq(), %{wm | watches: watches}}
  end

  @spec remove_watches_by_type(watches_by_type(), Watcher.type(), Path.t(), NodeWatcher.t() | nil) ::
          {watchers() | nil, watches_by_type()}
  defp remove_watches_by_type(watches, type, path, watcher) when is_watcher_type(type) do
    Map.get_and_update(watches, type, fn
      nil ->
        :pop

      watches ->
        {watchers, w} = remove_watcher_by_path(watches, IO.chardata_to_string(path), watcher)

        if map_size(w) == 0, do: :pop, else: {%{path => watchers}, w}
    end)
  end

  @spec remove_watcher_by_path(watches(), Path.t(), NodeWatcher.t() | nil) ::
          {watchers() | nil, watches()}
  defp remove_watcher_by_path(watches, path, watcher)
  defp remove_watcher_by_path(watches, path, nil), do: Map.pop(watches, path)

  defp remove_watcher_by_path(watches, path, watcher) do
    watches
    |> Map.get_and_update(
      path,
      fn
        nil ->
          :pop

        watchers ->
          w = MapSet.delete(watchers, watcher)

          if MapSet.size(w) == 0, do: :pop, else: {MapSet.new([watchers]), w}
      end
    )
  end

  defp extract_watchers(watches, watchers) when is_list(watches) do
    watches
    |> Enum.flat_map(&Map.values/1)
    |> Enum.flat_map(&Map.values/1)
    |> Enum.reduce(watchers, &MapSet.union(&1, &2))
    |> MapSet.to_list()
  end

  defp take_watchers(%__MODULE__{watches: watches} = wm, types, path, recursive) do
    {watchers, watches} = take_watchers(watches, types, path)

    watchers =
      watches
      |> Map.get(:persistent, %{})
      |> Map.get(path, MapSet.new())
      |> MapSet.union(MapSet.new(watchers))

    watchers =
      if recursive do
        persistent_recursive_watches =
          watches
          |> Map.get(:persistent_recursive, %{})

        Path.split(path)
        |> Stream.unfold(fn
          [] ->
            nil

          parts ->
            {_, rest} = List.pop_at(parts, -1)

            {Path.join(parts), rest}
        end)
        |> Stream.map(&(persistent_recursive_watches |> Map.get(&1, MapSet.new())))
        |> Enum.reduce(watchers, &MapSet.union(&1, &2))
      else
        watchers
      end

    {watchers |> MapSet.to_list(), %{wm | watches: watches}}
  end

  defp take_watchers(watches, types, path) when is_map(watches) and is_list(types) do
    {watchers, watches} =
      types |> Enum.flat_map_reduce(watches, &take_watchers(&2, &1, path))

    {watchers |> Enum.uniq(), watches}
  end

  defp take_watchers(watches, type, path) when is_map(watches) and is_watcher_type(type) do
    {watchers, watches} =
      Map.get_and_update(watches, type, fn
        nil -> :pop
        watches -> Map.pop(watches, path)
      end)

    {_, watches} =
      Map.get_and_update(watches, type, fn
        nil -> :pop
        w when map_size(w) == 0 -> :pop
        w -> {nil, w}
      end)

    {watchers || MapSet.new(), watches}
  end
end
