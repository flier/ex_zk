defmodule ExZk.Watcher do
  import ExZk.TypedEnum

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
end
