defmodule ExZk.Defs do
  import ExZk.TypedEnum

  alias ExZk.Data.{ACL, Id}

  defenum(ErrCode,
    ok: 0,
    system_error: -1,
    runtime_inconsistency: -2,
    data_inconsistency: -3,
    connection_loss: -4,
    marshalling_error: -5,
    unimplemented: -6,
    operation_timeout: -7,
    bad_arguments: -8,
    unknown_session: -12,
    new_config_no_quorum: -13,
    reconfig_in_progress: -14,
    api_error: -100,
    no_node: -101,
    no_auth: -102,
    bad_version: -103,
    no_children_for_ephemerals: -108,
    node_exists: -110,
    not_empty: -111,
    session_expired: -112,
    invalid_callback: -113,
    invalid_acl: -114,
    auth_failed: -115,
    session_moved: -118,
    not_readonly: -119,
    ephemeral_on_local_session: -120,
    no_watcher: -121,
    request_timeout: -122,
    reconfig_disabled: -123,
    session_closed_require_sasl_auth: -124,
    quota_exceeded: -125,
    throttled_op: -127
  )

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

  defmodule Ids do
    @doc """
    This Id represents anyone.
    """
    @spec anyone_id :: Id.t()
    def anyone_id, do: %Id{scheme: "world", id: "anyone"}

    @doc """
    This Id is only usable to set ACLs.

    It will get substituted with the Id's the client authenticated with.
    """
    @spec auth_ids :: Id.t()
    def auth_ids, do: %Id{scheme: "auth"}

    @doc """
    Create a new Id.
    """
    @spec id(scheme :: String.t(), id :: String.t()) :: Id.t()
    def id(scheme, id), do: %Id{scheme: scheme, id: id}

    @doc """
    This is a completely open ACL.
    """
    @spec open_acl :: ACL.t()
    def open_acl, do: acl({:all, anyone_id()})

    @doc """
    This ACL gives the creators authentication id's all permissions.
    """
    @spec creator_all_acl :: ACL.t()
    def creator_all_acl, do: acl({:all, auth_ids()})

    @doc """
    This ACL gives the world the ability to read.
    """
    @spec read_acl :: ACL.t()
    def read_acl, do: acl({:read, anyone_id()})

    @doc """
    Create a new ACL.
    """
    @spec acl({Perms.t(), Id.t()}) :: ACL.t()
    def acl({perms, id}), do: %ACL{perms: Perms.value!(perms), id: id}
  end
end
