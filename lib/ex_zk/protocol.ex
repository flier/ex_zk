defmodule ExZk.Data do
  @moduledoc false

  defmodule Id do
    defstruct scheme: "",
              id: ""

    @type t :: %__MODULE__{
            scheme: String.t(),
            id: String.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(Id.t()) :: binary()
      def pack(%Id{
            scheme: scheme,
            id: id
          }) do
        ExZk.Wire.pack([
          {:ustring, scheme},
          {:ustring, id}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(Id.t(), data :: binary()) ::
              {:ok, Id.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%Id{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 scheme: :ustring,
                 id: :ustring
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule ACL do
    defstruct perms: 0,
              id: %Id{}

    @type t :: %__MODULE__{
            perms: integer(),
            id: Id.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(ACL.t()) :: binary()
      def pack(%ACL{
            perms: perms,
            id: id
          }) do
        ExZk.Wire.pack([
          {:int, perms},
          {Id, id}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(ACL.t(), data :: binary()) ::
              {:ok, ACL.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%ACL{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 perms: :int,
                 id: Id
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule Stat do
    @moduledoc """
    information shared with the client
    """

    defstruct czxid: 0,
              mzxid: 0,
              ctime: 0,
              mtime: 0,
              version: 0,
              cversion: 0,
              aversion: 0,
              ephemeral_owner: 0,
              data_length: 0,
              num_children: 0,
              pzxid: 0

    @type t :: %__MODULE__{
            czxid: integer(),
            mzxid: integer(),
            ctime: integer(),
            mtime: integer(),
            version: integer(),
            cversion: integer(),
            aversion: integer(),
            ephemeral_owner: integer(),
            data_length: integer(),
            num_children: integer(),
            pzxid: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(Stat.t()) :: binary()
      def pack(%Stat{
            czxid: czxid,
            mzxid: mzxid,
            ctime: ctime,
            mtime: mtime,
            version: version,
            cversion: cversion,
            aversion: aversion,
            ephemeral_owner: ephemeral_owner,
            data_length: data_length,
            num_children: num_children,
            pzxid: pzxid
          }) do
        ExZk.Wire.pack([
          {:long, czxid},
          {:long, mzxid},
          {:long, ctime},
          {:long, mtime},
          {:int, version},
          {:int, cversion},
          {:int, aversion},
          {:long, ephemeral_owner},
          {:int, data_length},
          {:int, num_children},
          {:long, pzxid}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(Stat.t(), data :: binary()) ::
              {:ok, Stat.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%Stat{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 czxid: :long,
                 mzxid: :long,
                 ctime: :long,
                 mtime: :long,
                 version: :int,
                 cversion: :int,
                 aversion: :int,
                 ephemeral_owner: :long,
                 data_length: :int,
                 num_children: :int,
                 pzxid: :long
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule StatPersisted do
    @moduledoc """
    information explicitly stored by the server persistently
    """

    defstruct czxid: 0,
              mzxid: 0,
              ctime: 0,
              mtime: 0,
              version: 0,
              cversion: 0,
              aversion: 0,
              ephemeral_owner: 0,
              pzxid: 0

    @type t :: %__MODULE__{
            czxid: integer(),
            mzxid: integer(),
            ctime: integer(),
            mtime: integer(),
            version: integer(),
            cversion: integer(),
            aversion: integer(),
            ephemeral_owner: integer(),
            pzxid: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(StatPersisted.t()) :: binary()
      def pack(%StatPersisted{
            czxid: czxid,
            mzxid: mzxid,
            ctime: ctime,
            mtime: mtime,
            version: version,
            cversion: cversion,
            aversion: aversion,
            ephemeral_owner: ephemeral_owner,
            pzxid: pzxid
          }) do
        ExZk.Wire.pack([
          {:long, czxid},
          {:long, mzxid},
          {:long, ctime},
          {:long, mtime},
          {:int, version},
          {:int, cversion},
          {:int, aversion},
          {:long, ephemeral_owner},
          {:long, pzxid}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(StatPersisted.t(), data :: binary()) ::
              {:ok, StatPersisted.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%StatPersisted{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 czxid: :long,
                 mzxid: :long,
                 ctime: :long,
                 mtime: :long,
                 version: :int,
                 cversion: :int,
                 aversion: :int,
                 ephemeral_owner: :long,
                 pzxid: :long
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule ClientInfo do
    defstruct auth_scheme: "",
              user: ""

    @type t :: %__MODULE__{
            auth_scheme: String.t(),
            user: String.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(ClientInfo.t()) :: binary()
      def pack(%ClientInfo{
            auth_scheme: auth_scheme,
            user: user
          }) do
        ExZk.Wire.pack([
          {:ustring, auth_scheme},
          {:ustring, user}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(ClientInfo.t(), data :: binary()) ::
              {:ok, ClientInfo.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%ClientInfo{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 auth_scheme: :ustring,
                 user: :ustring
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end
end

defmodule ExZk.Proto do
  @moduledoc false

  defmodule ConnectRequest do
    defstruct protocol_version: 0,
              last_zxid_seen: 0,
              time_out: 0,
              session_id: 0,
              passwd: "",
              read_only: false

    @type t :: %__MODULE__{
            protocol_version: integer(),
            last_zxid_seen: integer(),
            time_out: integer(),
            session_id: integer(),
            passwd: binary(),
            read_only: boolean()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(ConnectRequest.t()) :: binary()
      def pack(%ConnectRequest{
            protocol_version: protocol_version,
            last_zxid_seen: last_zxid_seen,
            time_out: time_out,
            session_id: session_id,
            passwd: passwd,
            read_only: read_only
          }) do
        ExZk.Wire.pack([
          {:int, protocol_version},
          {:long, last_zxid_seen},
          {:int, time_out},
          {:long, session_id},
          {:buffer, passwd},
          {:boolean, read_only}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(ConnectRequest.t(), data :: binary()) ::
              {:ok, ConnectRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%ConnectRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 protocol_version: :int,
                 last_zxid_seen: :long,
                 time_out: :int,
                 session_id: :long,
                 passwd: :buffer,
                 read_only: :boolean
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule ConnectResponse do
    defstruct protocol_version: 0,
              time_out: 0,
              session_id: 0,
              passwd: "",
              read_only: false

    @type t :: %__MODULE__{
            protocol_version: integer(),
            time_out: integer(),
            session_id: integer(),
            passwd: binary(),
            read_only: boolean()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(ConnectResponse.t()) :: binary()
      def pack(%ConnectResponse{
            protocol_version: protocol_version,
            time_out: time_out,
            session_id: session_id,
            passwd: passwd,
            read_only: read_only
          }) do
        ExZk.Wire.pack([
          {:int, protocol_version},
          {:int, time_out},
          {:long, session_id},
          {:buffer, passwd},
          {:boolean, read_only}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(ConnectResponse.t(), data :: binary()) ::
              {:ok, ConnectResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%ConnectResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 protocol_version: :int,
                 time_out: :int,
                 session_id: :long,
                 passwd: :buffer,
                 read_only: :boolean
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetWatches do
    defstruct relative_zxid: 0,
              data_watches: [],
              exist_watches: [],
              child_watches: []

    @type t :: %__MODULE__{
            relative_zxid: integer(),
            data_watches: [String.t()],
            exist_watches: [String.t()],
            child_watches: [String.t()]
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetWatches.t()) :: binary()
      def pack(%SetWatches{
            relative_zxid: relative_zxid,
            data_watches: data_watches,
            exist_watches: exist_watches,
            child_watches: child_watches
          }) do
        ExZk.Wire.pack([
          {:long, relative_zxid},
          {{:vector, :ustring}, data_watches},
          {{:vector, :ustring}, exist_watches},
          {{:vector, :ustring}, child_watches}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetWatches.t(), data :: binary()) ::
              {:ok, SetWatches.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetWatches{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 relative_zxid: :long,
                 data_watches: {:vector, :ustring},
                 exist_watches: {:vector, :ustring},
                 child_watches: {:vector, :ustring}
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetWatches2 do
    defstruct relative_zxid: 0,
              data_watches: [],
              exist_watches: [],
              child_watches: [],
              persistent_watches: [],
              persistent_recursive_watches: []

    @type t :: %__MODULE__{
            relative_zxid: integer(),
            data_watches: [String.t()],
            exist_watches: [String.t()],
            child_watches: [String.t()],
            persistent_watches: [String.t()],
            persistent_recursive_watches: [String.t()]
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetWatches2.t()) :: binary()
      def pack(%SetWatches2{
            relative_zxid: relative_zxid,
            data_watches: data_watches,
            exist_watches: exist_watches,
            child_watches: child_watches,
            persistent_watches: persistent_watches,
            persistent_recursive_watches: persistent_recursive_watches
          }) do
        ExZk.Wire.pack([
          {:long, relative_zxid},
          {{:vector, :ustring}, data_watches},
          {{:vector, :ustring}, exist_watches},
          {{:vector, :ustring}, child_watches},
          {{:vector, :ustring}, persistent_watches},
          {{:vector, :ustring}, persistent_recursive_watches}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetWatches2.t(), data :: binary()) ::
              {:ok, SetWatches2.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetWatches2{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 relative_zxid: :long,
                 data_watches: {:vector, :ustring},
                 exist_watches: {:vector, :ustring},
                 child_watches: {:vector, :ustring},
                 persistent_watches: {:vector, :ustring},
                 persistent_recursive_watches: {:vector, :ustring}
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule RequestHeader do
    defstruct xid: 0,
              type: 0

    @type t :: %__MODULE__{
            xid: integer(),
            type: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(RequestHeader.t()) :: binary()
      def pack(%RequestHeader{
            xid: xid,
            type: type
          }) do
        ExZk.Wire.pack([
          {:int, xid},
          {:int, type}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(RequestHeader.t(), data :: binary()) ::
              {:ok, RequestHeader.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%RequestHeader{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 xid: :int,
                 type: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule MultiHeader do
    defstruct type: 0,
              done: false,
              err: 0

    @type t :: %__MODULE__{
            type: integer(),
            done: boolean(),
            err: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(MultiHeader.t()) :: binary()
      def pack(%MultiHeader{
            type: type,
            done: done,
            err: err
          }) do
        ExZk.Wire.pack([
          {:int, type},
          {:boolean, done},
          {:int, err}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(MultiHeader.t(), data :: binary()) ::
              {:ok, MultiHeader.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%MultiHeader{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 type: :int,
                 done: :boolean,
                 err: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule AuthPacket do
    defstruct type: 0,
              scheme: "",
              auth: ""

    @type t :: %__MODULE__{
            type: integer(),
            scheme: String.t(),
            auth: binary()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(AuthPacket.t()) :: binary()
      def pack(%AuthPacket{
            type: type,
            scheme: scheme,
            auth: auth
          }) do
        ExZk.Wire.pack([
          {:int, type},
          {:ustring, scheme},
          {:buffer, auth}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(AuthPacket.t(), data :: binary()) ::
              {:ok, AuthPacket.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%AuthPacket{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 type: :int,
                 scheme: :ustring,
                 auth: :buffer
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule ReplyHeader do
    defstruct xid: 0,
              zxid: 0,
              err: 0

    @type t :: %__MODULE__{
            xid: integer(),
            zxid: integer(),
            err: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(ReplyHeader.t()) :: binary()
      def pack(%ReplyHeader{
            xid: xid,
            zxid: zxid,
            err: err
          }) do
        ExZk.Wire.pack([
          {:int, xid},
          {:long, zxid},
          {:int, err}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(ReplyHeader.t(), data :: binary()) ::
              {:ok, ReplyHeader.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%ReplyHeader{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 xid: :int,
                 zxid: :long,
                 err: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetDataRequest do
    defstruct path: "",
              watch: false

    @type t :: %__MODULE__{
            path: String.t(),
            watch: boolean()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetDataRequest.t()) :: binary()
      def pack(%GetDataRequest{
            path: path,
            watch: watch
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:boolean, watch}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetDataRequest.t(), data :: binary()) ::
              {:ok, GetDataRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetDataRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 watch: :boolean
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetDataRequest do
    defstruct path: "",
              data: "",
              version: 0

    @type t :: %__MODULE__{
            path: String.t(),
            data: binary(),
            version: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetDataRequest.t()) :: binary()
      def pack(%SetDataRequest{
            path: path,
            data: data,
            version: version
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:buffer, data},
          {:int, version}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetDataRequest.t(), data :: binary()) ::
              {:ok, SetDataRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetDataRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 data: :buffer,
                 version: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule ReconfigRequest do
    defstruct joining_servers: "",
              leaving_servers: "",
              new_members: "",
              cur_config_id: 0

    @type t :: %__MODULE__{
            joining_servers: String.t(),
            leaving_servers: String.t(),
            new_members: String.t(),
            cur_config_id: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(ReconfigRequest.t()) :: binary()
      def pack(%ReconfigRequest{
            joining_servers: joining_servers,
            leaving_servers: leaving_servers,
            new_members: new_members,
            cur_config_id: cur_config_id
          }) do
        ExZk.Wire.pack([
          {:ustring, joining_servers},
          {:ustring, leaving_servers},
          {:ustring, new_members},
          {:long, cur_config_id}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(ReconfigRequest.t(), data :: binary()) ::
              {:ok, ReconfigRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%ReconfigRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 joining_servers: :ustring,
                 leaving_servers: :ustring,
                 new_members: :ustring,
                 cur_config_id: :long
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetDataResponse do
    defstruct stat: %ExZk.Data.Stat{}

    @type t :: %__MODULE__{
            stat: ExZk.Data.Stat.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetDataResponse.t()) :: binary()
      def pack(%SetDataResponse{
            stat: stat
          }) do
        ExZk.Wire.pack([
          {ExZk.Data.Stat, stat}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetDataResponse.t(), data :: binary()) ::
              {:ok, SetDataResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetDataResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 stat: ExZk.Data.Stat
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetSASLRequest do
    defstruct token: ""

    @type t :: %__MODULE__{
            token: binary()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetSASLRequest.t()) :: binary()
      def pack(%GetSASLRequest{
            token: token
          }) do
        ExZk.Wire.pack([
          {:buffer, token}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetSASLRequest.t(), data :: binary()) ::
              {:ok, GetSASLRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetSASLRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 token: :buffer
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetSASLRequest do
    defstruct token: ""

    @type t :: %__MODULE__{
            token: binary()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetSASLRequest.t()) :: binary()
      def pack(%SetSASLRequest{
            token: token
          }) do
        ExZk.Wire.pack([
          {:buffer, token}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetSASLRequest.t(), data :: binary()) ::
              {:ok, SetSASLRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetSASLRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 token: :buffer
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetSASLResponse do
    defstruct token: ""

    @type t :: %__MODULE__{
            token: binary()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetSASLResponse.t()) :: binary()
      def pack(%SetSASLResponse{
            token: token
          }) do
        ExZk.Wire.pack([
          {:buffer, token}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetSASLResponse.t(), data :: binary()) ::
              {:ok, SetSASLResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetSASLResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 token: :buffer
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CreateRequest do
    defstruct path: "",
              data: "",
              acl: [],
              flags: 0

    @type t :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: [ExZk.Data.ACL.t()],
            flags: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CreateRequest.t()) :: binary()
      def pack(%CreateRequest{
            path: path,
            data: data,
            acl: acl,
            flags: flags
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:buffer, data},
          {{:vector, ExZk.Data.ACL}, acl},
          {:int, flags}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CreateRequest.t(), data :: binary()) ::
              {:ok, CreateRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CreateRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 data: :buffer,
                 acl: {:vector, ExZk.Data.ACL},
                 flags: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CreateTTLRequest do
    defstruct path: "",
              data: "",
              acl: [],
              flags: 0,
              ttl: 0

    @type t :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: [ExZk.Data.ACL.t()],
            flags: integer(),
            ttl: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CreateTTLRequest.t()) :: binary()
      def pack(%CreateTTLRequest{
            path: path,
            data: data,
            acl: acl,
            flags: flags,
            ttl: ttl
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:buffer, data},
          {{:vector, ExZk.Data.ACL}, acl},
          {:int, flags},
          {:long, ttl}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CreateTTLRequest.t(), data :: binary()) ::
              {:ok, CreateTTLRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CreateTTLRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 data: :buffer,
                 acl: {:vector, ExZk.Data.ACL},
                 flags: :int,
                 ttl: :long
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule DeleteRequest do
    defstruct path: "",
              version: 0

    @type t :: %__MODULE__{
            path: String.t(),
            version: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(DeleteRequest.t()) :: binary()
      def pack(%DeleteRequest{
            path: path,
            version: version
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:int, version}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(DeleteRequest.t(), data :: binary()) ::
              {:ok, DeleteRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%DeleteRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 version: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetChildrenRequest do
    defstruct path: "",
              watch: false

    @type t :: %__MODULE__{
            path: String.t(),
            watch: boolean()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetChildrenRequest.t()) :: binary()
      def pack(%GetChildrenRequest{
            path: path,
            watch: watch
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:boolean, watch}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetChildrenRequest.t(), data :: binary()) ::
              {:ok, GetChildrenRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetChildrenRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 watch: :boolean
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetAllChildrenNumberRequest do
    defstruct path: ""

    @type t :: %__MODULE__{
            path: String.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetAllChildrenNumberRequest.t()) :: binary()
      def pack(%GetAllChildrenNumberRequest{
            path: path
          }) do
        ExZk.Wire.pack([
          {:ustring, path}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetAllChildrenNumberRequest.t(), data :: binary()) ::
              {:ok, GetAllChildrenNumberRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetAllChildrenNumberRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetChildren2Request do
    defstruct path: "",
              watch: false

    @type t :: %__MODULE__{
            path: String.t(),
            watch: boolean()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetChildren2Request.t()) :: binary()
      def pack(%GetChildren2Request{
            path: path,
            watch: watch
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:boolean, watch}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetChildren2Request.t(), data :: binary()) ::
              {:ok, GetChildren2Request.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetChildren2Request{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 watch: :boolean
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CheckVersionRequest do
    defstruct path: "",
              version: 0

    @type t :: %__MODULE__{
            path: String.t(),
            version: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CheckVersionRequest.t()) :: binary()
      def pack(%CheckVersionRequest{
            path: path,
            version: version
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:int, version}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CheckVersionRequest.t(), data :: binary()) ::
              {:ok, CheckVersionRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CheckVersionRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 version: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetMaxChildrenRequest do
    defstruct path: ""

    @type t :: %__MODULE__{
            path: String.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetMaxChildrenRequest.t()) :: binary()
      def pack(%GetMaxChildrenRequest{
            path: path
          }) do
        ExZk.Wire.pack([
          {:ustring, path}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetMaxChildrenRequest.t(), data :: binary()) ::
              {:ok, GetMaxChildrenRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetMaxChildrenRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetMaxChildrenResponse do
    defstruct max: 0

    @type t :: %__MODULE__{
            max: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetMaxChildrenResponse.t()) :: binary()
      def pack(%GetMaxChildrenResponse{
            max: max
          }) do
        ExZk.Wire.pack([
          {:int, max}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetMaxChildrenResponse.t(), data :: binary()) ::
              {:ok, GetMaxChildrenResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetMaxChildrenResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 max: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetMaxChildrenRequest do
    defstruct path: "",
              max: 0

    @type t :: %__MODULE__{
            path: String.t(),
            max: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetMaxChildrenRequest.t()) :: binary()
      def pack(%SetMaxChildrenRequest{
            path: path,
            max: max
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:int, max}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetMaxChildrenRequest.t(), data :: binary()) ::
              {:ok, SetMaxChildrenRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetMaxChildrenRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 max: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SyncRequest do
    defstruct path: ""

    @type t :: %__MODULE__{
            path: String.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SyncRequest.t()) :: binary()
      def pack(%SyncRequest{
            path: path
          }) do
        ExZk.Wire.pack([
          {:ustring, path}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SyncRequest.t(), data :: binary()) ::
              {:ok, SyncRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SyncRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SyncResponse do
    defstruct path: ""

    @type t :: %__MODULE__{
            path: String.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SyncResponse.t()) :: binary()
      def pack(%SyncResponse{
            path: path
          }) do
        ExZk.Wire.pack([
          {:ustring, path}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SyncResponse.t(), data :: binary()) ::
              {:ok, SyncResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SyncResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetACLRequest do
    defstruct path: ""

    @type t :: %__MODULE__{
            path: String.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetACLRequest.t()) :: binary()
      def pack(%GetACLRequest{
            path: path
          }) do
        ExZk.Wire.pack([
          {:ustring, path}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetACLRequest.t(), data :: binary()) ::
              {:ok, GetACLRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetACLRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetACLRequest do
    defstruct path: "",
              acl: [],
              version: 0

    @type t :: %__MODULE__{
            path: String.t(),
            acl: [ExZk.Data.ACL.t()],
            version: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetACLRequest.t()) :: binary()
      def pack(%SetACLRequest{
            path: path,
            acl: acl,
            version: version
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {{:vector, ExZk.Data.ACL}, acl},
          {:int, version}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetACLRequest.t(), data :: binary()) ::
              {:ok, SetACLRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetACLRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 acl: {:vector, ExZk.Data.ACL},
                 version: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetACLResponse do
    defstruct stat: %ExZk.Data.Stat{}

    @type t :: %__MODULE__{
            stat: ExZk.Data.Stat.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetACLResponse.t()) :: binary()
      def pack(%SetACLResponse{
            stat: stat
          }) do
        ExZk.Wire.pack([
          {ExZk.Data.Stat, stat}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetACLResponse.t(), data :: binary()) ::
              {:ok, SetACLResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetACLResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 stat: ExZk.Data.Stat
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule AddWatchRequest do
    defstruct path: "",
              mode: 0

    @type t :: %__MODULE__{
            path: String.t(),
            mode: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(AddWatchRequest.t()) :: binary()
      def pack(%AddWatchRequest{
            path: path,
            mode: mode
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:int, mode}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(AddWatchRequest.t(), data :: binary()) ::
              {:ok, AddWatchRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%AddWatchRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 mode: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule WatcherEvent do
    defstruct type: 0,
              state: 0,
              path: ""

    @type t :: %__MODULE__{
            type: integer(),
            state: integer(),
            path: String.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(WatcherEvent.t()) :: binary()
      def pack(%WatcherEvent{
            type: type,
            state: state,
            path: path
          }) do
        ExZk.Wire.pack([
          {:int, type},
          {:int, state},
          {:ustring, path}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(WatcherEvent.t(), data :: binary()) ::
              {:ok, WatcherEvent.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%WatcherEvent{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 type: :int,
                 state: :int,
                 path: :ustring
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule ErrorResponse do
    defstruct err: 0

    @type t :: %__MODULE__{
            err: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(ErrorResponse.t()) :: binary()
      def pack(%ErrorResponse{
            err: err
          }) do
        ExZk.Wire.pack([
          {:int, err}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(ErrorResponse.t(), data :: binary()) ::
              {:ok, ErrorResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%ErrorResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 err: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CreateResponse do
    defstruct path: ""

    @type t :: %__MODULE__{
            path: String.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CreateResponse.t()) :: binary()
      def pack(%CreateResponse{
            path: path
          }) do
        ExZk.Wire.pack([
          {:ustring, path}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CreateResponse.t(), data :: binary()) ::
              {:ok, CreateResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CreateResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule Create2Response do
    defstruct path: "",
              stat: %ExZk.Data.Stat{}

    @type t :: %__MODULE__{
            path: String.t(),
            stat: ExZk.Data.Stat.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(Create2Response.t()) :: binary()
      def pack(%Create2Response{
            path: path,
            stat: stat
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {ExZk.Data.Stat, stat}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(Create2Response.t(), data :: binary()) ::
              {:ok, Create2Response.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%Create2Response{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 stat: ExZk.Data.Stat
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule ExistsRequest do
    defstruct path: "",
              watch: false

    @type t :: %__MODULE__{
            path: String.t(),
            watch: boolean()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(ExistsRequest.t()) :: binary()
      def pack(%ExistsRequest{
            path: path,
            watch: watch
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:boolean, watch}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(ExistsRequest.t(), data :: binary()) ::
              {:ok, ExistsRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%ExistsRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 watch: :boolean
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule ExistsResponse do
    defstruct stat: %ExZk.Data.Stat{}

    @type t :: %__MODULE__{
            stat: ExZk.Data.Stat.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(ExistsResponse.t()) :: binary()
      def pack(%ExistsResponse{
            stat: stat
          }) do
        ExZk.Wire.pack([
          {ExZk.Data.Stat, stat}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(ExistsResponse.t(), data :: binary()) ::
              {:ok, ExistsResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%ExistsResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 stat: ExZk.Data.Stat
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetDataResponse do
    defstruct data: "",
              stat: %ExZk.Data.Stat{}

    @type t :: %__MODULE__{
            data: binary(),
            stat: ExZk.Data.Stat.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetDataResponse.t()) :: binary()
      def pack(%GetDataResponse{
            data: data,
            stat: stat
          }) do
        ExZk.Wire.pack([
          {:buffer, data},
          {ExZk.Data.Stat, stat}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetDataResponse.t(), data :: binary()) ::
              {:ok, GetDataResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetDataResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 data: :buffer,
                 stat: ExZk.Data.Stat
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetChildrenResponse do
    defstruct children: []

    @type t :: %__MODULE__{
            children: [String.t()]
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetChildrenResponse.t()) :: binary()
      def pack(%GetChildrenResponse{
            children: children
          }) do
        ExZk.Wire.pack([
          {{:vector, :ustring}, children}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetChildrenResponse.t(), data :: binary()) ::
              {:ok, GetChildrenResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetChildrenResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 children: {:vector, :ustring}
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetAllChildrenNumberResponse do
    defstruct total_number: 0

    @type t :: %__MODULE__{
            total_number: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetAllChildrenNumberResponse.t()) :: binary()
      def pack(%GetAllChildrenNumberResponse{
            total_number: total_number
          }) do
        ExZk.Wire.pack([
          {:int, total_number}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetAllChildrenNumberResponse.t(), data :: binary()) ::
              {:ok, GetAllChildrenNumberResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetAllChildrenNumberResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 total_number: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetChildren2Response do
    defstruct children: [],
              stat: %ExZk.Data.Stat{}

    @type t :: %__MODULE__{
            children: [String.t()],
            stat: ExZk.Data.Stat.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetChildren2Response.t()) :: binary()
      def pack(%GetChildren2Response{
            children: children,
            stat: stat
          }) do
        ExZk.Wire.pack([
          {{:vector, :ustring}, children},
          {ExZk.Data.Stat, stat}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetChildren2Response.t(), data :: binary()) ::
              {:ok, GetChildren2Response.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetChildren2Response{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 children: {:vector, :ustring},
                 stat: ExZk.Data.Stat
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetACLResponse do
    defstruct acl: [],
              stat: %ExZk.Data.Stat{}

    @type t :: %__MODULE__{
            acl: [ExZk.Data.ACL.t()],
            stat: ExZk.Data.Stat.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetACLResponse.t()) :: binary()
      def pack(%GetACLResponse{
            acl: acl,
            stat: stat
          }) do
        ExZk.Wire.pack([
          {{:vector, ExZk.Data.ACL}, acl},
          {ExZk.Data.Stat, stat}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetACLResponse.t(), data :: binary()) ::
              {:ok, GetACLResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetACLResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 acl: {:vector, ExZk.Data.ACL},
                 stat: ExZk.Data.Stat
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CheckWatchesRequest do
    defstruct path: "",
              type: 0

    @type t :: %__MODULE__{
            path: String.t(),
            type: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CheckWatchesRequest.t()) :: binary()
      def pack(%CheckWatchesRequest{
            path: path,
            type: type
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:int, type}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CheckWatchesRequest.t(), data :: binary()) ::
              {:ok, CheckWatchesRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CheckWatchesRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 type: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule RemoveWatchesRequest do
    defstruct path: "",
              type: 0

    @type t :: %__MODULE__{
            path: String.t(),
            type: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(RemoveWatchesRequest.t()) :: binary()
      def pack(%RemoveWatchesRequest{
            path: path,
            type: type
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:int, type}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(RemoveWatchesRequest.t(), data :: binary()) ::
              {:ok, RemoveWatchesRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%RemoveWatchesRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 type: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetEphemeralsRequest do
    defstruct prefix_path: ""

    @type t :: %__MODULE__{
            prefix_path: String.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetEphemeralsRequest.t()) :: binary()
      def pack(%GetEphemeralsRequest{
            prefix_path: prefix_path
          }) do
        ExZk.Wire.pack([
          {:ustring, prefix_path}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetEphemeralsRequest.t(), data :: binary()) ::
              {:ok, GetEphemeralsRequest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetEphemeralsRequest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 prefix_path: :ustring
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule GetEphemeralsResponse do
    defstruct ephemerals: []

    @type t :: %__MODULE__{
            ephemerals: [String.t()]
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(GetEphemeralsResponse.t()) :: binary()
      def pack(%GetEphemeralsResponse{
            ephemerals: ephemerals
          }) do
        ExZk.Wire.pack([
          {{:vector, :ustring}, ephemerals}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(GetEphemeralsResponse.t(), data :: binary()) ::
              {:ok, GetEphemeralsResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%GetEphemeralsResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 ephemerals: {:vector, :ustring}
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule WhoAmIResponse do
    defstruct client_info: []

    @type t :: %__MODULE__{
            client_info: [ExZk.Data.ClientInfo.t()]
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(WhoAmIResponse.t()) :: binary()
      def pack(%WhoAmIResponse{
            client_info: client_info
          }) do
        ExZk.Wire.pack([
          {{:vector, ExZk.Data.ClientInfo}, client_info}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(WhoAmIResponse.t(), data :: binary()) ::
              {:ok, WhoAmIResponse.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%WhoAmIResponse{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 client_info: {:vector, ExZk.Data.ClientInfo}
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end
end

defmodule ExZk.Txn do
  @moduledoc false

  defmodule TxnDigest do
    defstruct version: 0,
              tree_digest: 0

    @type t :: %__MODULE__{
            version: integer(),
            tree_digest: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(TxnDigest.t()) :: binary()
      def pack(%TxnDigest{
            version: version,
            tree_digest: tree_digest
          }) do
        ExZk.Wire.pack([
          {:int, version},
          {:long, tree_digest}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(TxnDigest.t(), data :: binary()) ::
              {:ok, TxnDigest.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%TxnDigest{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 version: :int,
                 tree_digest: :long
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule TxnHeader do
    defstruct client_id: 0,
              cxid: 0,
              zxid: 0,
              time: 0,
              type: 0

    @type t :: %__MODULE__{
            client_id: integer(),
            cxid: integer(),
            zxid: integer(),
            time: integer(),
            type: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(TxnHeader.t()) :: binary()
      def pack(%TxnHeader{
            client_id: client_id,
            cxid: cxid,
            zxid: zxid,
            time: time,
            type: type
          }) do
        ExZk.Wire.pack([
          {:long, client_id},
          {:int, cxid},
          {:long, zxid},
          {:long, time},
          {:int, type}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(TxnHeader.t(), data :: binary()) ::
              {:ok, TxnHeader.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%TxnHeader{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 client_id: :long,
                 cxid: :int,
                 zxid: :long,
                 time: :long,
                 type: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CreateTxnV0 do
    defstruct path: "",
              data: "",
              acl: [],
              ephemeral: false

    @type t :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: [ExZk.Data.ACL.t()],
            ephemeral: boolean()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CreateTxnV0.t()) :: binary()
      def pack(%CreateTxnV0{
            path: path,
            data: data,
            acl: acl,
            ephemeral: ephemeral
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:buffer, data},
          {{:vector, ExZk.Data.ACL}, acl},
          {:boolean, ephemeral}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CreateTxnV0.t(), data :: binary()) ::
              {:ok, CreateTxnV0.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CreateTxnV0{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 data: :buffer,
                 acl: {:vector, ExZk.Data.ACL},
                 ephemeral: :boolean
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CreateTxn do
    defstruct path: "",
              data: "",
              acl: [],
              ephemeral: false,
              parent_c_version: 0

    @type t :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: [ExZk.Data.ACL.t()],
            ephemeral: boolean(),
            parent_c_version: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CreateTxn.t()) :: binary()
      def pack(%CreateTxn{
            path: path,
            data: data,
            acl: acl,
            ephemeral: ephemeral,
            parent_c_version: parent_c_version
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:buffer, data},
          {{:vector, ExZk.Data.ACL}, acl},
          {:boolean, ephemeral},
          {:int, parent_c_version}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CreateTxn.t(), data :: binary()) ::
              {:ok, CreateTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CreateTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 data: :buffer,
                 acl: {:vector, ExZk.Data.ACL},
                 ephemeral: :boolean,
                 parent_c_version: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CreateTTLTxn do
    defstruct path: "",
              data: "",
              acl: [],
              parent_c_version: 0,
              ttl: 0

    @type t :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: [ExZk.Data.ACL.t()],
            parent_c_version: integer(),
            ttl: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CreateTTLTxn.t()) :: binary()
      def pack(%CreateTTLTxn{
            path: path,
            data: data,
            acl: acl,
            parent_c_version: parent_c_version,
            ttl: ttl
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:buffer, data},
          {{:vector, ExZk.Data.ACL}, acl},
          {:int, parent_c_version},
          {:long, ttl}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CreateTTLTxn.t(), data :: binary()) ::
              {:ok, CreateTTLTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CreateTTLTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 data: :buffer,
                 acl: {:vector, ExZk.Data.ACL},
                 parent_c_version: :int,
                 ttl: :long
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CreateContainerTxn do
    defstruct path: "",
              data: "",
              acl: [],
              parent_c_version: 0

    @type t :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: [ExZk.Data.ACL.t()],
            parent_c_version: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CreateContainerTxn.t()) :: binary()
      def pack(%CreateContainerTxn{
            path: path,
            data: data,
            acl: acl,
            parent_c_version: parent_c_version
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:buffer, data},
          {{:vector, ExZk.Data.ACL}, acl},
          {:int, parent_c_version}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CreateContainerTxn.t(), data :: binary()) ::
              {:ok, CreateContainerTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CreateContainerTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 data: :buffer,
                 acl: {:vector, ExZk.Data.ACL},
                 parent_c_version: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule DeleteTxn do
    defstruct path: ""

    @type t :: %__MODULE__{
            path: String.t()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(DeleteTxn.t()) :: binary()
      def pack(%DeleteTxn{
            path: path
          }) do
        ExZk.Wire.pack([
          {:ustring, path}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(DeleteTxn.t(), data :: binary()) ::
              {:ok, DeleteTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%DeleteTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetDataTxn do
    defstruct path: "",
              data: "",
              version: 0

    @type t :: %__MODULE__{
            path: String.t(),
            data: binary(),
            version: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetDataTxn.t()) :: binary()
      def pack(%SetDataTxn{
            path: path,
            data: data,
            version: version
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:buffer, data},
          {:int, version}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetDataTxn.t(), data :: binary()) ::
              {:ok, SetDataTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetDataTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 data: :buffer,
                 version: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CheckVersionTxn do
    defstruct path: "",
              version: 0

    @type t :: %__MODULE__{
            path: String.t(),
            version: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CheckVersionTxn.t()) :: binary()
      def pack(%CheckVersionTxn{
            path: path,
            version: version
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:int, version}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CheckVersionTxn.t(), data :: binary()) ::
              {:ok, CheckVersionTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CheckVersionTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 version: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetACLTxn do
    defstruct path: "",
              acl: [],
              version: 0

    @type t :: %__MODULE__{
            path: String.t(),
            acl: [ExZk.Data.ACL.t()],
            version: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetACLTxn.t()) :: binary()
      def pack(%SetACLTxn{
            path: path,
            acl: acl,
            version: version
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {{:vector, ExZk.Data.ACL}, acl},
          {:int, version}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetACLTxn.t(), data :: binary()) ::
              {:ok, SetACLTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetACLTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 acl: {:vector, ExZk.Data.ACL},
                 version: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule SetMaxChildrenTxn do
    defstruct path: "",
              max: 0

    @type t :: %__MODULE__{
            path: String.t(),
            max: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(SetMaxChildrenTxn.t()) :: binary()
      def pack(%SetMaxChildrenTxn{
            path: path,
            max: max
          }) do
        ExZk.Wire.pack([
          {:ustring, path},
          {:int, max}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(SetMaxChildrenTxn.t(), data :: binary()) ::
              {:ok, SetMaxChildrenTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%SetMaxChildrenTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 path: :ustring,
                 max: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CreateSessionTxn do
    defstruct time_out: 0

    @type t :: %__MODULE__{
            time_out: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CreateSessionTxn.t()) :: binary()
      def pack(%CreateSessionTxn{
            time_out: time_out
          }) do
        ExZk.Wire.pack([
          {:int, time_out}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CreateSessionTxn.t(), data :: binary()) ::
              {:ok, CreateSessionTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CreateSessionTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 time_out: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule CloseSessionTxn do
    defstruct paths2_delete: []

    @type t :: %__MODULE__{
            paths2_delete: [String.t()]
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(CloseSessionTxn.t()) :: binary()
      def pack(%CloseSessionTxn{
            paths2_delete: paths2_delete
          }) do
        ExZk.Wire.pack([
          {{:vector, :ustring}, paths2_delete}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(CloseSessionTxn.t(), data :: binary()) ::
              {:ok, CloseSessionTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%CloseSessionTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 paths2_delete: {:vector, :ustring}
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule ErrorTxn do
    defstruct err: 0

    @type t :: %__MODULE__{
            err: integer()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(ErrorTxn.t()) :: binary()
      def pack(%ErrorTxn{
            err: err
          }) do
        ExZk.Wire.pack([
          {:int, err}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(ErrorTxn.t(), data :: binary()) ::
              {:ok, ErrorTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%ErrorTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 err: :int
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule Txn do
    defstruct type: 0,
              data: ""

    @type t :: %__MODULE__{
            type: integer(),
            data: binary()
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(Txn.t()) :: binary()
      def pack(%Txn{
            type: type,
            data: data
          }) do
        ExZk.Wire.pack([
          {:int, type},
          {:buffer, data}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(Txn.t(), data :: binary()) ::
              {:ok, Txn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%Txn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 type: :int,
                 data: :buffer
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end

  defmodule MultiTxn do
    defstruct txns: []

    @type t :: %__MODULE__{
            txns: [ExZk.Txn.Txn.t()]
          }

    defimpl ExZk.Wire.Pack do
      @spec pack(MultiTxn.t()) :: binary()
      def pack(%MultiTxn{
            txns: txns
          }) do
        ExZk.Wire.pack([
          {{:vector, ExZk.Txn.Txn}, txns}
        ])
      end
    end

    defimpl ExZk.Wire.Unpack do
      @spec unpack(MultiTxn.t(), data :: binary()) ::
              {:ok, MultiTxn.t(), rest :: binary()} | {:error, :nomatch}
      def unpack(%MultiTxn{} = value, data) when is_binary(data) do
        with {:ok, fields, rest} <-
               ExZk.Wire.unpack(data,
                 txns: {:vector, ExZk.Txn.Txn}
               ) do
          {:ok, Map.merge(value, Enum.into(fields, %{})), rest}
        end
      end
    end
  end
end
