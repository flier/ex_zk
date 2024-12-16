defmodule ExZk.Defs do
  import ExZk.TypedEnum

  defenum(OpCode,
    notification: 0,
    create: 1,
    delete: 2,
    exists: 3,
    get_data: 4,
    set_data: 5,
    get_acl: 6,
    set_acl: 7,
    get_children: 8,
    sync: 9,
    ping: 11,
    get_children2: 12,
    check: 13,
    multi: 14,
    create2: 15,
    reconfig: 16,
    check_watches: 17,
    remove_watches: 18,
    create_container: 19,
    delete_container: 20,
    create_ttl: 21,
    multi_read: 22,
    auth: 100,
    set_watches: 101,
    sasl: 102,
    get_ephemerals: 103,
    get_all_children_number: 104,
    set_watches2: 105,
    add_watch: 106,
    who_am_i: 107,
    create_session: -10,
    close_session: -11,
    error: -1
  )

  defenum(Perms,
    read: 1,
    write: 2,
    create: 4,
    delete: 8,
    admin: 16,
    all: 31
  )

  defenum(CreateMode,
    persistent: 0,
    ephemeral: 1,
    persistent_sequential: 2,
    ephemeral_sequential: 3,
    container: 4,
    persistent_with_ttl: 5,
    persistent_sequential_with_ttl: 6
  )

  @spec is_ephemeral(CreateMode.t()) :: boolean()
  def is_ephemeral(mode), do: mode in [:ephemeral, :ephemeral_sequential]

  @spec is_sequential(CreateMode.t()) :: boolean()
  def is_sequential(mode),
    do:
      mode in [
        :persistent_sequential,
        :ephemeral_sequential,
        :persistent_sequential_with_ttl
      ]

  @spec is_container(CreateMode.t()) :: boolean()
  def is_container(mode), do: mode == :container

  @spec is_ttl(CreateMode.t()) :: boolean()
  def is_ttl(mode), do: mode in [:persistent_with_ttl, :persistent_sequential_with_ttl]
end
