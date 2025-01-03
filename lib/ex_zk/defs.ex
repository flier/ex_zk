defmodule ExZk.Defs do
  import ExZk.TypedEnum

  defmacro __using__(_) do
    quote do
      @notification_xid -1
      @ping_xid -2
      @auth_packet_xid -4
      @set_watches_xid -8

      @any_version -1

      @default_host "localhost"
      @default_port 2181
      @default_server "#{@default_host}:#{@default_port}"

      @default_timeout 5000
      @default_session_timeout 18_000
      @default_batch_size 1000
    end
  end

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
    @type t :: [Perm.t()] | :all

    @all 0b0001_1111

    @doc """
    Convert an integer to a list of permissions.

    ## Example

        iex> alias ExZk.Defs.Perms
        iex> Perms.cast(31)
        :all
        iex> Perms.cast(3)
        [:read, :write]
        iex> Perms.cast(0)
        []

    """
    @spec cast(integer()) :: t()
    def cast(@all), do: :all

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

        iex> ExZk.Defs.Perms.value!([])
        0
        iex> ExZk.Defs.Perms.value!(:read)
        1
        iex> ExZk.Defs.Perms.value!([:read, :write])
        3
        iex> ExZk.Defs.Perms.value!(:all)
        31
    """
    @spec value!(t()) :: integer()
    def value!(:all), do: @all
    def value!(perm) when is_atom(perm), do: value!([perm])
    def value!(perms) when is_list(perms), do: perms |> Enum.map(&Perm.value!/1) |> Enum.sum()

    @doc """
    Parse a string into a list of permissions.

    ## Example

        iex> ExZk.Defs.Perms.parse("r")
        [:read]

        iex> ExZk.Defs.Perms.parse("rw")
        [:read, :write]

        iex> ExZk.Defs.Perms.parse("rwcda")
        [:read, :write, :create, :delete, :admin]
    """
    @spec parse(String.t()) :: t()
    def parse(s), do: parse(s, [])

    defp parse(<<>>, perms), do: perms |> Enum.reverse()

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

      if perm do
        parse(rest, [perm | perms])
      else
        parse(rest, perms)
      end
    end

    @doc """
    Convert a list of permissions to a string.

    ## Example

        iex> ExZk.Defs.Perms.to_string(:all)
        "rwcda"

        iex> ExZk.Defs.Perms.to_string(:read)
        "r"

        iex> ExZk.Defs.Perms.to_string([:read, :write])
        "rw"

        iex> ExZk.Defs.Perms.to_string([:read, :write, :create, :delete, :admin])
        "rwcda"
    """
    @spec to_string(Perm.t() | Perms.t()) :: String.t()
    def to_string(:all), do: "rwcda"
    def to_string(perm) when is_atom(perm), do: Perms.to_string([perm])

    def to_string(perms) do
      perms
      |> Enum.map_join(fn
        :read -> "r"
        :write -> "w"
        :create -> "c"
        :delete -> "d"
        :admin -> "a"
      end)
    end
  end

  defmodule Id do
    alias ExZk.Data.Id

    @type t :: Id.t()

    @doc """
    This Id represents anyone.

    ## Example

        iex> ExZk.Defs.Id.anyone() |> to_string()
        "world:anyone"
    """
    @spec anyone :: Id.t()
    def anyone, do: %Id{scheme: "world", id: "anyone"}

    @doc """
    This Id is only usable to set ACLs.

    It will get substituted with the Id's the client authenticated with.

    ## Example

        iex> ExZk.Defs.Id.auth() |> to_string()
        "auth:"
    """
    @spec auth :: Id.t()
    def auth, do: %Id{scheme: "auth"}

    @doc """
    Create a new Id.

    ## Example

        iex> ExZk.Defs.Id.new("world", "anyone") |> to_string()
        "world:anyone"

    """
    @spec new(scheme :: String.t(), id :: String.t()) :: t()
    def new(scheme, id), do: %Id{scheme: scheme, id: id}

    defimpl String.Chars, for: Id do
      def to_string(%Id{scheme: scheme, id: id}), do: "#{scheme}:#{id}"
    end
  end

  defmodule ACL do
    alias ExZk.Data.ACL
    alias ExZk.Defs.Id

    @type t :: ACL.t()

    @doc """
    Create a new ACL.

    ## Example

        iex> ExZk.Defs.ACL.new(:all, ExZk.Defs.Id.anyone()) |> to_string()
        "world:anyone:rwcda"

        iex> ExZk.Defs.ACL.new(3, ExZk.Defs.Id.anyone()) |> to_string()
        "world:anyone:rw"

        iex> ExZk.Defs.ACL.new([:read, :write, :delete], ExZk.Defs.Id.anyone()) |> to_string()
        "world:anyone:rwd"

    """
    @spec new(Perm.t() | Perms.t(), Id.t()) :: t()
    def new(perms, id) when is_atom(perms), do: %ACL{perms: Perm.value!(perms), id: id}
    def new(perms, id) when is_list(perms), do: %ACL{perms: Perms.value!(perms), id: id}
    def new(perms, id) when is_integer(perms), do: %ACL{perms: perms, id: id}

    @doc """
    This is a completely open ACL.

    ## Example

        iex> ExZk.Defs.ACL.open() |> to_string()
        "world:anyone:rwcda"

    """
    @spec open :: t()
    def open, do: new(:all, Id.anyone())

    @doc """
    This ACL gives the creators authentication id's all permissions.

    ## Example

        iex> ExZk.Defs.ACL.creator_all() |> to_string()
        "auth::rwcda"

    """
    @spec creator_all :: t()
    def creator_all, do: new(:all, Id.auth())

    @doc """
    This ACL gives the world the ability to read.

    ## Example

        iex> ExZk.Defs.ACL.read() |> to_string()
        "world:anyone:r"
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

    defimpl String.Chars, for: ACL do
      def to_string(%ACL{perms: perms, id: id}) do
        "#{id}:#{perms |> Perms.cast() |> Perms.to_string()}"
      end
    end
  end
end
