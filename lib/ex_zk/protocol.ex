defmodule ExZk.Data do
  @moduledoc false

  defmodule Id do
    @moduledoc false

    defstruct [
      :scheme,
      :id
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :ustring
             ],
             buf
           ) do
        {:ok,
         [
           scheme,
           id
         ], rest} ->
          {:ok,
           %Id{
             scheme: scheme,
             id: id
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule ACL do
    @moduledoc false

    defstruct [
      :perms,
      :id
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int,
               Id
             ],
             buf
           ) do
        {:ok,
         [
           perms,
           id
         ], rest} ->
          {:ok,
           %ACL{
             perms: perms,
             id: id
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule Stat do
    @moduledoc false

    defstruct [
      :czxid,
      :mzxid,
      :ctime,
      :mtime,
      :version,
      :cversion,
      :aversion,
      :ephemeral_owner,
      :data_length,
      :num_children,
      :pzxid
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :long,
               :long,
               :long,
               :long,
               :int,
               :int,
               :int,
               :long,
               :int,
               :int,
               :long
             ],
             buf
           ) do
        {:ok,
         [
           czxid,
           mzxid,
           ctime,
           mtime,
           version,
           cversion,
           aversion,
           ephemeral_owner,
           data_length,
           num_children,
           pzxid
         ], rest} ->
          {:ok,
           %Stat{
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
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule StatPersisted do
    @moduledoc false

    defstruct [
      :czxid,
      :mzxid,
      :ctime,
      :mtime,
      :version,
      :cversion,
      :aversion,
      :ephemeral_owner,
      :pzxid
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :long,
               :long,
               :long,
               :long,
               :int,
               :int,
               :int,
               :long,
               :long
             ],
             buf
           ) do
        {:ok,
         [
           czxid,
           mzxid,
           ctime,
           mtime,
           version,
           cversion,
           aversion,
           ephemeral_owner,
           pzxid
         ], rest} ->
          {:ok,
           %StatPersisted{
             czxid: czxid,
             mzxid: mzxid,
             ctime: ctime,
             mtime: mtime,
             version: version,
             cversion: cversion,
             aversion: aversion,
             ephemeral_owner: ephemeral_owner,
             pzxid: pzxid
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule ClientInfo do
    @moduledoc false

    defstruct [
      :auth_scheme,
      :user
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :ustring
             ],
             buf
           ) do
        {:ok,
         [
           auth_scheme,
           user
         ], rest} ->
          {:ok,
           %ClientInfo{
             auth_scheme: auth_scheme,
             user: user
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end

defmodule ExZk.Proto do
  @moduledoc false

  defmodule ConnectRequest do
    @moduledoc false

    defstruct [
      :protocol_version,
      :last_zxid_seen,
      :time_out,
      :session_id,
      :passwd,
      :read_only
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int,
               :long,
               :int,
               :long,
               :buffer,
               :boolean
             ],
             buf
           ) do
        {:ok,
         [
           protocol_version,
           last_zxid_seen,
           time_out,
           session_id,
           passwd,
           read_only
         ], rest} ->
          {:ok,
           %ConnectRequest{
             protocol_version: protocol_version,
             last_zxid_seen: last_zxid_seen,
             time_out: time_out,
             session_id: session_id,
             passwd: passwd,
             read_only: read_only
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule ConnectResponse do
    @moduledoc false

    defstruct [
      :protocol_version,
      :time_out,
      :session_id,
      :passwd,
      :read_only
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int,
               :int,
               :long,
               :buffer,
               :boolean
             ],
             buf
           ) do
        {:ok,
         [
           protocol_version,
           time_out,
           session_id,
           passwd,
           read_only
         ], rest} ->
          {:ok,
           %ConnectResponse{
             protocol_version: protocol_version,
             time_out: time_out,
             session_id: session_id,
             passwd: passwd,
             read_only: read_only
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetWatches do
    @moduledoc false

    defstruct [
      :relative_zxid,
      :data_watches,
      :exist_watches,
      :child_watches
    ]

    @type t() :: %__MODULE__{
            relative_zxid: integer(),
            data_watches: list(String.t()),
            exist_watches: list(String.t()),
            child_watches: list(String.t())
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :long,
               {:vector, :ustring},
               {:vector, :ustring},
               {:vector, :ustring}
             ],
             buf
           ) do
        {:ok,
         [
           relative_zxid,
           data_watches,
           exist_watches,
           child_watches
         ], rest} ->
          {:ok,
           %SetWatches{
             relative_zxid: relative_zxid,
             data_watches: data_watches,
             exist_watches: exist_watches,
             child_watches: child_watches
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetWatches2 do
    @moduledoc false

    defstruct [
      :relative_zxid,
      :data_watches,
      :exist_watches,
      :child_watches,
      :persistent_watches,
      :persistent_recursive_watches
    ]

    @type t() :: %__MODULE__{
            relative_zxid: integer(),
            data_watches: list(String.t()),
            exist_watches: list(String.t()),
            child_watches: list(String.t()),
            persistent_watches: list(String.t()),
            persistent_recursive_watches: list(String.t())
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :long,
               {:vector, :ustring},
               {:vector, :ustring},
               {:vector, :ustring},
               {:vector, :ustring},
               {:vector, :ustring}
             ],
             buf
           ) do
        {:ok,
         [
           relative_zxid,
           data_watches,
           exist_watches,
           child_watches,
           persistent_watches,
           persistent_recursive_watches
         ], rest} ->
          {:ok,
           %SetWatches2{
             relative_zxid: relative_zxid,
             data_watches: data_watches,
             exist_watches: exist_watches,
             child_watches: child_watches,
             persistent_watches: persistent_watches,
             persistent_recursive_watches: persistent_recursive_watches
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule RequestHeader do
    @moduledoc false

    defstruct [
      :xid,
      :type
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           xid,
           type
         ], rest} ->
          {:ok,
           %RequestHeader{
             xid: xid,
             type: type
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule MultiHeader do
    @moduledoc false

    defstruct [
      :type,
      :done,
      :err
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int,
               :boolean,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           type,
           done,
           err
         ], rest} ->
          {:ok,
           %MultiHeader{
             type: type,
             done: done,
             err: err
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule AuthPacket do
    @moduledoc false

    defstruct [
      :type,
      :scheme,
      :auth
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int,
               :ustring,
               :buffer
             ],
             buf
           ) do
        {:ok,
         [
           type,
           scheme,
           auth
         ], rest} ->
          {:ok,
           %AuthPacket{
             type: type,
             scheme: scheme,
             auth: auth
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule ReplyHeader do
    @moduledoc false

    defstruct [
      :xid,
      :zxid,
      :err
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int,
               :long,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           xid,
           zxid,
           err
         ], rest} ->
          {:ok,
           %ReplyHeader{
             xid: xid,
             zxid: zxid,
             err: err
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetDataRequest do
    @moduledoc false

    defstruct [
      :path,
      :watch
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :boolean
             ],
             buf
           ) do
        {:ok,
         [
           path,
           watch
         ], rest} ->
          {:ok,
           %GetDataRequest{
             path: path,
             watch: watch
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetDataRequest do
    @moduledoc false

    defstruct [
      :path,
      :data,
      :version
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :buffer,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           data,
           version
         ], rest} ->
          {:ok,
           %SetDataRequest{
             path: path,
             data: data,
             version: version
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule ReconfigRequest do
    @moduledoc false

    defstruct [
      :joining_servers,
      :leaving_servers,
      :new_members,
      :cur_config_id
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :ustring,
               :ustring,
               :long
             ],
             buf
           ) do
        {:ok,
         [
           joining_servers,
           leaving_servers,
           new_members,
           cur_config_id
         ], rest} ->
          {:ok,
           %ReconfigRequest{
             joining_servers: joining_servers,
             leaving_servers: leaving_servers,
             new_members: new_members,
             cur_config_id: cur_config_id
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetDataResponse do
    @moduledoc false

    defstruct [
      :stat
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               ExZk.Data.Stat
             ],
             buf
           ) do
        {:ok,
         [
           stat
         ], rest} ->
          {:ok,
           %SetDataResponse{
             stat: stat
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetSASLRequest do
    @moduledoc false

    defstruct [
      :token
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :buffer
             ],
             buf
           ) do
        {:ok,
         [
           token
         ], rest} ->
          {:ok,
           %GetSASLRequest{
             token: token
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetSASLRequest do
    @moduledoc false

    defstruct [
      :token
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :buffer
             ],
             buf
           ) do
        {:ok,
         [
           token
         ], rest} ->
          {:ok,
           %SetSASLRequest{
             token: token
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetSASLResponse do
    @moduledoc false

    defstruct [
      :token
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :buffer
             ],
             buf
           ) do
        {:ok,
         [
           token
         ], rest} ->
          {:ok,
           %SetSASLResponse{
             token: token
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CreateRequest do
    @moduledoc false

    defstruct [
      :path,
      :data,
      :acl,
      :flags
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: list(ExZk.Data.ACL.t()),
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :buffer,
               {:vector, ExZk.Data.ACL},
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           data,
           acl,
           flags
         ], rest} ->
          {:ok,
           %CreateRequest{
             path: path,
             data: data,
             acl: acl,
             flags: flags
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CreateTTLRequest do
    @moduledoc false

    defstruct [
      :path,
      :data,
      :acl,
      :flags,
      :ttl
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: list(ExZk.Data.ACL.t()),
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :buffer,
               {:vector, ExZk.Data.ACL},
               :int,
               :long
             ],
             buf
           ) do
        {:ok,
         [
           path,
           data,
           acl,
           flags,
           ttl
         ], rest} ->
          {:ok,
           %CreateTTLRequest{
             path: path,
             data: data,
             acl: acl,
             flags: flags,
             ttl: ttl
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule DeleteRequest do
    @moduledoc false

    defstruct [
      :path,
      :version
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           version
         ], rest} ->
          {:ok,
           %DeleteRequest{
             path: path,
             version: version
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetChildrenRequest do
    @moduledoc false

    defstruct [
      :path,
      :watch
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :boolean
             ],
             buf
           ) do
        {:ok,
         [
           path,
           watch
         ], rest} ->
          {:ok,
           %GetChildrenRequest{
             path: path,
             watch: watch
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetAllChildrenNumberRequest do
    @moduledoc false

    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring
             ],
             buf
           ) do
        {:ok,
         [
           path
         ], rest} ->
          {:ok,
           %GetAllChildrenNumberRequest{
             path: path
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetChildren2Request do
    @moduledoc false

    defstruct [
      :path,
      :watch
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :boolean
             ],
             buf
           ) do
        {:ok,
         [
           path,
           watch
         ], rest} ->
          {:ok,
           %GetChildren2Request{
             path: path,
             watch: watch
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CheckVersionRequest do
    @moduledoc false

    defstruct [
      :path,
      :version
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           version
         ], rest} ->
          {:ok,
           %CheckVersionRequest{
             path: path,
             version: version
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetMaxChildrenRequest do
    @moduledoc false

    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring
             ],
             buf
           ) do
        {:ok,
         [
           path
         ], rest} ->
          {:ok,
           %GetMaxChildrenRequest{
             path: path
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetMaxChildrenResponse do
    @moduledoc false

    defstruct [
      :max
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int
             ],
             buf
           ) do
        {:ok,
         [
           max
         ], rest} ->
          {:ok,
           %GetMaxChildrenResponse{
             max: max
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetMaxChildrenRequest do
    @moduledoc false

    defstruct [
      :path,
      :max
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           max
         ], rest} ->
          {:ok,
           %SetMaxChildrenRequest{
             path: path,
             max: max
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SyncRequest do
    @moduledoc false

    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring
             ],
             buf
           ) do
        {:ok,
         [
           path
         ], rest} ->
          {:ok,
           %SyncRequest{
             path: path
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SyncResponse do
    @moduledoc false

    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring
             ],
             buf
           ) do
        {:ok,
         [
           path
         ], rest} ->
          {:ok,
           %SyncResponse{
             path: path
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetACLRequest do
    @moduledoc false

    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring
             ],
             buf
           ) do
        {:ok,
         [
           path
         ], rest} ->
          {:ok,
           %GetACLRequest{
             path: path
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetACLRequest do
    @moduledoc false

    defstruct [
      :path,
      :acl,
      :version
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            acl: list(ExZk.Data.ACL.t()),
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               {:vector, ExZk.Data.ACL},
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           acl,
           version
         ], rest} ->
          {:ok,
           %SetACLRequest{
             path: path,
             acl: acl,
             version: version
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetACLResponse do
    @moduledoc false

    defstruct [
      :stat
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               ExZk.Data.Stat
             ],
             buf
           ) do
        {:ok,
         [
           stat
         ], rest} ->
          {:ok,
           %SetACLResponse{
             stat: stat
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule AddWatchRequest do
    @moduledoc false

    defstruct [
      :path,
      :mode
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           mode
         ], rest} ->
          {:ok,
           %AddWatchRequest{
             path: path,
             mode: mode
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule WatcherEvent do
    @moduledoc false

    defstruct [
      :type,
      :state,
      :path
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int,
               :int,
               :ustring
             ],
             buf
           ) do
        {:ok,
         [
           type,
           state,
           path
         ], rest} ->
          {:ok,
           %WatcherEvent{
             type: type,
             state: state,
             path: path
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule ErrorResponse do
    @moduledoc false

    defstruct [
      :err
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int
             ],
             buf
           ) do
        {:ok,
         [
           err
         ], rest} ->
          {:ok,
           %ErrorResponse{
             err: err
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CreateResponse do
    @moduledoc false

    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring
             ],
             buf
           ) do
        {:ok,
         [
           path
         ], rest} ->
          {:ok,
           %CreateResponse{
             path: path
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule Create2Response do
    @moduledoc false

    defstruct [
      :path,
      :stat
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               ExZk.Data.Stat
             ],
             buf
           ) do
        {:ok,
         [
           path,
           stat
         ], rest} ->
          {:ok,
           %Create2Response{
             path: path,
             stat: stat
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule ExistsRequest do
    @moduledoc false

    defstruct [
      :path,
      :watch
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :boolean
             ],
             buf
           ) do
        {:ok,
         [
           path,
           watch
         ], rest} ->
          {:ok,
           %ExistsRequest{
             path: path,
             watch: watch
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule ExistsResponse do
    @moduledoc false

    defstruct [
      :stat
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               ExZk.Data.Stat
             ],
             buf
           ) do
        {:ok,
         [
           stat
         ], rest} ->
          {:ok,
           %ExistsResponse{
             stat: stat
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetDataResponse do
    @moduledoc false

    defstruct [
      :data,
      :stat
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :buffer,
               ExZk.Data.Stat
             ],
             buf
           ) do
        {:ok,
         [
           data,
           stat
         ], rest} ->
          {:ok,
           %GetDataResponse{
             data: data,
             stat: stat
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetChildrenResponse do
    @moduledoc false

    defstruct [
      :children
    ]

    @type t() :: %__MODULE__{
            children: list(String.t())
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               {:vector, :ustring}
             ],
             buf
           ) do
        {:ok,
         [
           children
         ], rest} ->
          {:ok,
           %GetChildrenResponse{
             children: children
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetAllChildrenNumberResponse do
    @moduledoc false

    defstruct [
      :total_number
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int
             ],
             buf
           ) do
        {:ok,
         [
           total_number
         ], rest} ->
          {:ok,
           %GetAllChildrenNumberResponse{
             total_number: total_number
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetChildren2Response do
    @moduledoc false

    defstruct [
      :children,
      :stat
    ]

    @type t() :: %__MODULE__{
            children: list(String.t()),
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               {:vector, :ustring},
               ExZk.Data.Stat
             ],
             buf
           ) do
        {:ok,
         [
           children,
           stat
         ], rest} ->
          {:ok,
           %GetChildren2Response{
             children: children,
             stat: stat
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetACLResponse do
    @moduledoc false

    defstruct [
      :acl,
      :stat
    ]

    @type t() :: %__MODULE__{
            acl: list(ExZk.Data.ACL.t()),
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               {:vector, ExZk.Data.ACL},
               ExZk.Data.Stat
             ],
             buf
           ) do
        {:ok,
         [
           acl,
           stat
         ], rest} ->
          {:ok,
           %GetACLResponse{
             acl: acl,
             stat: stat
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CheckWatchesRequest do
    @moduledoc false

    defstruct [
      :path,
      :type
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           type
         ], rest} ->
          {:ok,
           %CheckWatchesRequest{
             path: path,
             type: type
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule RemoveWatchesRequest do
    @moduledoc false

    defstruct [
      :path,
      :type
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           type
         ], rest} ->
          {:ok,
           %RemoveWatchesRequest{
             path: path,
             type: type
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetEphemeralsRequest do
    @moduledoc false

    defstruct [
      :prefix_path
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring
             ],
             buf
           ) do
        {:ok,
         [
           prefix_path
         ], rest} ->
          {:ok,
           %GetEphemeralsRequest{
             prefix_path: prefix_path
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule GetEphemeralsResponse do
    @moduledoc false

    defstruct [
      :ephemerals
    ]

    @type t() :: %__MODULE__{
            ephemerals: list(String.t())
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               {:vector, :ustring}
             ],
             buf
           ) do
        {:ok,
         [
           ephemerals
         ], rest} ->
          {:ok,
           %GetEphemeralsResponse{
             ephemerals: ephemerals
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule WhoAmIResponse do
    @moduledoc false

    defstruct [
      :client_info
    ]

    @type t() :: %__MODULE__{
            client_info: list(ExZk.Data.ClientInfo.t())
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               {:vector, ExZk.Data.ClientInfo}
             ],
             buf
           ) do
        {:ok,
         [
           client_info
         ], rest} ->
          {:ok,
           %WhoAmIResponse{
             client_info: client_info
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end

defmodule ExZk.Txn do
  @moduledoc false

  defmodule TxnDigest do
    @moduledoc false

    defstruct [
      :version,
      :tree_digest
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int,
               :long
             ],
             buf
           ) do
        {:ok,
         [
           version,
           tree_digest
         ], rest} ->
          {:ok,
           %TxnDigest{
             version: version,
             tree_digest: tree_digest
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule TxnHeader do
    @moduledoc false

    defstruct [
      :client_id,
      :cxid,
      :zxid,
      :time,
      :type
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :long,
               :int,
               :long,
               :long,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           client_id,
           cxid,
           zxid,
           time,
           type
         ], rest} ->
          {:ok,
           %TxnHeader{
             client_id: client_id,
             cxid: cxid,
             zxid: zxid,
             time: time,
             type: type
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CreateTxnV0 do
    @moduledoc false

    defstruct [
      :path,
      :data,
      :acl,
      :ephemeral
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: list(ExZk.Data.ACL.t()),
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :buffer,
               {:vector, ExZk.Data.ACL},
               :boolean
             ],
             buf
           ) do
        {:ok,
         [
           path,
           data,
           acl,
           ephemeral
         ], rest} ->
          {:ok,
           %CreateTxnV0{
             path: path,
             data: data,
             acl: acl,
             ephemeral: ephemeral
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CreateTxn do
    @moduledoc false

    defstruct [
      :path,
      :data,
      :acl,
      :ephemeral,
      :parent_c_version
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: list(ExZk.Data.ACL.t()),
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :buffer,
               {:vector, ExZk.Data.ACL},
               :boolean,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           data,
           acl,
           ephemeral,
           parent_c_version
         ], rest} ->
          {:ok,
           %CreateTxn{
             path: path,
             data: data,
             acl: acl,
             ephemeral: ephemeral,
             parent_c_version: parent_c_version
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CreateTTLTxn do
    @moduledoc false

    defstruct [
      :path,
      :data,
      :acl,
      :parent_c_version,
      :ttl
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: list(ExZk.Data.ACL.t()),
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :buffer,
               {:vector, ExZk.Data.ACL},
               :int,
               :long
             ],
             buf
           ) do
        {:ok,
         [
           path,
           data,
           acl,
           parent_c_version,
           ttl
         ], rest} ->
          {:ok,
           %CreateTTLTxn{
             path: path,
             data: data,
             acl: acl,
             parent_c_version: parent_c_version,
             ttl: ttl
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CreateContainerTxn do
    @moduledoc false

    defstruct [
      :path,
      :data,
      :acl,
      :parent_c_version
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: list(ExZk.Data.ACL.t()),
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :buffer,
               {:vector, ExZk.Data.ACL},
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           data,
           acl,
           parent_c_version
         ], rest} ->
          {:ok,
           %CreateContainerTxn{
             path: path,
             data: data,
             acl: acl,
             parent_c_version: parent_c_version
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule DeleteTxn do
    @moduledoc false

    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring
             ],
             buf
           ) do
        {:ok,
         [
           path
         ], rest} ->
          {:ok,
           %DeleteTxn{
             path: path
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetDataTxn do
    @moduledoc false

    defstruct [
      :path,
      :data,
      :version
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :buffer,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           data,
           version
         ], rest} ->
          {:ok,
           %SetDataTxn{
             path: path,
             data: data,
             version: version
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CheckVersionTxn do
    @moduledoc false

    defstruct [
      :path,
      :version
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           version
         ], rest} ->
          {:ok,
           %CheckVersionTxn{
             path: path,
             version: version
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetACLTxn do
    @moduledoc false

    defstruct [
      :path,
      :acl,
      :version
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            acl: list(ExZk.Data.ACL.t()),
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               {:vector, ExZk.Data.ACL},
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           acl,
           version
         ], rest} ->
          {:ok,
           %SetACLTxn{
             path: path,
             acl: acl,
             version: version
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule SetMaxChildrenTxn do
    @moduledoc false

    defstruct [
      :path,
      :max
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :ustring,
               :int
             ],
             buf
           ) do
        {:ok,
         [
           path,
           max
         ], rest} ->
          {:ok,
           %SetMaxChildrenTxn{
             path: path,
             max: max
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CreateSessionTxn do
    @moduledoc false

    defstruct [
      :time_out
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int
             ],
             buf
           ) do
        {:ok,
         [
           time_out
         ], rest} ->
          {:ok,
           %CreateSessionTxn{
             time_out: time_out
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule CloseSessionTxn do
    @moduledoc false

    defstruct [
      :paths2_delete
    ]

    @type t() :: %__MODULE__{
            paths2_delete: list(String.t())
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               {:vector, :ustring}
             ],
             buf
           ) do
        {:ok,
         [
           paths2_delete
         ], rest} ->
          {:ok,
           %CloseSessionTxn{
             paths2_delete: paths2_delete
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule ErrorTxn do
    @moduledoc false

    defstruct [
      :err
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int
             ],
             buf
           ) do
        {:ok,
         [
           err
         ], rest} ->
          {:ok,
           %ErrorTxn{
             err: err
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule Txn do
    @moduledoc false

    defstruct [
      :type,
      :data
    ]

    @type t() :: %__MODULE__{
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               :int,
               :buffer
             ],
             buf
           ) do
        {:ok,
         [
           type,
           data
         ], rest} ->
          {:ok,
           %Txn{
             type: type,
             data: data
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule MultiTxn do
    @moduledoc false

    defstruct [
      :txns
    ]

    @type t() :: %__MODULE__{
            txns: list(ExZk.Txn.Txn.t())
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

    @spec unpack(buf :: binary()) :: {:ok, t(), rest :: binary()} | {:error, :nomatch}
    def unpack(buf) do
      case ExZk.Wire.unpack(
             [
               {:vector, ExZk.Txn.Txn}
             ],
             buf
           ) do
        {:ok,
         [
           txns
         ], rest} ->
          {:ok,
           %MultiTxn{
             txns: txns
           }, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end