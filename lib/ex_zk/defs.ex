defmodule ExZk.Defs do
  import ExZk.TypedEnum

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

  defenum(Perm,
    read: 1,
    write: 2,
    create: 4,
    delete: 8,
    admin: 16,
    all: 31
  )

  defmodule Perms do
    @type t :: [Perm.t()]

    @doc """
    Convert an integer to a list of permissions.

    ## Example

        iex> alias ExZk.Defs.Perms
        iex> Perms.cast(31)
        [:all]
        iex> Perms.cast(3)
        [:read, :write]
        iex> Perms.cast(0)
        []

    """
    @spec cast(integer()) :: t()
    def cast(31), do: [:all]

    def cast(perms) when is_integer(perms) do
      <<admin::1, delete::1, create::1, write::1, read::1>> = <<perms::5>>

      [
        if(read == 1, do: :read),
        if(write == 1, do: :write),
        if(create == 1, do: :create),
        if(delete == 1, do: :delete),
        if(admin == 1, do: :admin)
      ]
      |> Enum.filter(&(&1 != nil))
    end

    @doc """
    Convert a list of permissions to an integer.

    ## Example

        iex> alias ExZk.Defs.Perms
        iex> Perms.value!([:read, :write])
        3
    """
    @spec value!(t()) :: integer()
    def value!(perms), do: perms |> Enum.map(&Perm.value!/1) |> Enum.sum()

    @doc """
    Parse a string into a list of permissions.

    ## Example

        iex> alias ExZk.Defs.Perms
        iex> Perms.parse("r")
        [:read]
        iex> Perms.parse("rw")
        [:read, :write]
    """
    @spec parse(String.t()) :: t()
    def parse(s), do: parse(s, [])

    defp parse(<<>>, perms), do: perms |> Stream.filter(&(&1 != nil)) |> Enum.reverse()

    defp parse(<<c::utf8, rest::binary>>, perms) do
      perm =
        case c do
          ?r -> :read
          ?w -> :write
          ?c -> :create
          ?d -> :delete
          ?a -> :admin
          _ -> nil
        end

      parse(rest, [perm | perms])
    end
  end

  defmodule Id do
    alias ExZk.Data.Id

    @type t :: Id.t()

    @doc """
    This Id represents anyone.
    """
    @spec anyone :: Id.t()
    def anyone, do: %Id{scheme: "world", id: "anyone"}

    @doc """
    This Id is only usable to set ACLs.

    It will get substituted with the Id's the client authenticated with.
    """
    @spec auth :: Id.t()
    def auth, do: %Id{scheme: "auth"}

    @doc """
    Create a new Id.
    """
    @spec new(scheme :: String.t(), id :: String.t()) :: t()
    def new(scheme, id), do: %Id{scheme: scheme, id: id}
  end

  defmodule ACL do
    alias ExZk.Data.ACL
    alias ExZk.Defs.Id

    @type t :: ACL.t()

    @doc """
    Create a new ACL.

    ## Example

        iex> import ExZk.Defs.Id
        iex> alias ExZk.Data.{ACL, Id}
        iex> ExZk.Defs.ACL.new(:all, anyone())
        %ACL{perms: 31, id: %Id{scheme: "world", id: "anyone"}}
        iex> ExZk.Defs.ACL.new(7, anyone())
        %ACL{perms: 7, id: %Id{scheme: "world", id: "anyone"}}
        iex> ExZk.Defs.ACL.new([:read, :write, :delete], anyone())
        %ACL{perms: 11, id: %Id{scheme: "world", id: "anyone"}}

    """
    @spec new(Perm.t() | Perms.t(), Id.t()) :: t()
    def new(perms, id) when is_atom(perms), do: %ACL{perms: Perm.value!(perms), id: id}
    def new(perms, id) when is_list(perms), do: %ACL{perms: Perms.value!(perms), id: id}
    def new(perms, id) when is_integer(perms), do: %ACL{perms: perms, id: id}

    @doc """
    This is a completely open ACL.
    """
    @spec open :: t()
    def open, do: new(:all, Id.anyone())

    @doc """
    This ACL gives the creators authentication id's all permissions.
    """
    @spec creator_all :: t()
    def creator_all, do: new(:all, Id.auth())

    @doc """
    This ACL gives the world the ability to read.
    """
    @spec read :: t()
    def read, do: new(:read, Id.anyone())

    @doc """
    Parse an ACL string.

    ## Example

        iex> import ExZk.Defs.ACL
        iex> alias ExZk.Data.{ACL, Id}
        iex> parse_acls("world:anyone:r")
        [%ACL{perms: 1, id: %Id{scheme: "world", id: "anyone"}}]
        iex> parse_acls("world:anyone:rw")
        [%ACL{perms: 3, id: %Id{scheme: "world", id: "anyone"}}]
        iex> parse_acls("world:anyone:r,auth::rw")
        [%ACL{perms: 1, id: %Id{scheme: "world", id: "anyone"}}, %ACL{perms: 3, id: %Id{scheme: "auth"}}]
    """
    @spec parse_acls(String.t()) :: [ACL.t()]
    def parse_acls(s) do
      s
      |> String.split(",", trim: true)
      |> Enum.map(&parse/1)
      |> Enum.filter(&(!is_nil(&1)))
    end

    @doc """
    Parse an ACL string.

    ## Example

        iex> import ExZk.Defs.ACL
        iex> alias ExZk.Data.{ACL, Id}
        iex> parse("world:anyone:r")
        %ACL{perms: 1, id: %Id{scheme: "world", id: "anyone"}}
        iex> parse("world:anyone:rw")
        %ACL{perms: 3, id: %Id{scheme: "world", id: "anyone"}}
        iex> parse("world::")
        %ACL{perms: 31, id: %Id{scheme: "world", id: ""}}
        iex> parse("world:anyone")
        %ACL{perms: 31, id: %Id{scheme: "world", id: "anyone"}}
        iex> parse("digest:user:pass:rw")
        %ACL{perms: 3, id: %Id{scheme: "digest", id: "user:pass"}}
    """
    @spec parse(String.t()) :: ACL.t()
    def parse(s) do
      case s |> String.split(":") do
        [scheme, id] ->
          new(:all, Id.new(scheme, id))

        [scheme, id, ""] ->
          new(:all, Id.new(scheme, id))

        [scheme, id, perms] ->
          new(Perms.parse(perms), Id.new(scheme, id))

        [scheme | rest] ->
          {perms, rest} = List.pop_at(rest, -1)

          new(Perms.parse(perms), Id.new(scheme, rest |> Enum.join(":")))
      end
    end
  end
end
