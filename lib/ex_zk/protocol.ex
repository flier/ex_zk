defmodule ExZk.Data do
  defmodule Id do
    defstruct [
      :scheme,
      :id
    ]

    @type t() :: %__MODULE__{
            scheme: String.t(),
            id: String.t()
          }
  end

  defmodule ACL do
    defstruct [
      :perms,
      :id
    ]

    @type t() :: %__MODULE__{
            perms: integer(),
            id: Id
          }
  end

  defmodule Stat do
    @moduledoc """
    information shared with the client
    """

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
  end

  defmodule StatPersisted do
    @moduledoc """
    information explicitly stored by the server persistently
    """

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
  end

  defmodule ClientInfo do
    defstruct [
      :auth_scheme,
      :user
    ]

    @type t() :: %__MODULE__{
            auth_scheme: String.t(),
            user: String.t()
          }
  end
end

defmodule ExZk.Proto do
  defmodule ConnectRequest do
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
  end

  defmodule ConnectResponse do
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
  end

  defmodule SetWatches do
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
  end

  defmodule SetWatches2 do
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
  end

  defmodule RequestHeader do
    defstruct [
      :xid,
      :type
    ]

    @type t() :: %__MODULE__{
            xid: integer(),
            type: integer()
          }
  end

  defmodule MultiHeader do
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
  end

  defmodule AuthPacket do
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
  end

  defmodule ReplyHeader do
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
  end

  defmodule GetDataRequest do
    defstruct [
      :path,
      :watch
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            watch: boolean()
          }
  end

  defmodule SetDataRequest do
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
  end

  defmodule ReconfigRequest do
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
  end

  defmodule SetDataResponse do
    defstruct [
      :stat
    ]

    @type t() :: %__MODULE__{
            stat: Stat
          }
  end

  defmodule GetSASLRequest do
    defstruct [
      :token
    ]

    @type t() :: %__MODULE__{
            token: binary()
          }
  end

  defmodule SetSASLRequest do
    defstruct [
      :token
    ]

    @type t() :: %__MODULE__{
            token: binary()
          }
  end

  defmodule SetSASLResponse do
    defstruct [
      :token
    ]

    @type t() :: %__MODULE__{
            token: binary()
          }
  end

  defmodule CreateRequest do
    defstruct [
      :path,
      :data,
      :acl,
      :flags
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: list(ACL),
            flags: integer()
          }
  end

  defmodule CreateTTLRequest do
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
            acl: list(ACL),
            flags: integer(),
            ttl: integer()
          }
  end

  defmodule DeleteRequest do
    defstruct [
      :path,
      :version
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            version: integer()
          }
  end

  defmodule GetChildrenRequest do
    defstruct [
      :path,
      :watch
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            watch: boolean()
          }
  end

  defmodule GetAllChildrenNumberRequest do
    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
            path: String.t()
          }
  end

  defmodule GetChildren2Request do
    defstruct [
      :path,
      :watch
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            watch: boolean()
          }
  end

  defmodule CheckVersionRequest do
    defstruct [
      :path,
      :version
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            version: integer()
          }
  end

  defmodule GetMaxChildrenRequest do
    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
            path: String.t()
          }
  end

  defmodule GetMaxChildrenResponse do
    defstruct [
      :max
    ]

    @type t() :: %__MODULE__{
            max: integer()
          }
  end

  defmodule SetMaxChildrenRequest do
    defstruct [
      :path,
      :max
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            max: integer()
          }
  end

  defmodule SyncRequest do
    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
            path: String.t()
          }
  end

  defmodule SyncResponse do
    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
            path: String.t()
          }
  end

  defmodule GetACLRequest do
    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
            path: String.t()
          }
  end

  defmodule SetACLRequest do
    defstruct [
      :path,
      :acl,
      :version
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            acl: list(ACL),
            version: integer()
          }
  end

  defmodule SetACLResponse do
    defstruct [
      :stat
    ]

    @type t() :: %__MODULE__{
            stat: Stat
          }
  end

  defmodule AddWatchRequest do
    defstruct [
      :path,
      :mode
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            mode: integer()
          }
  end

  defmodule WatcherEvent do
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
  end

  defmodule ErrorResponse do
    defstruct [
      :err
    ]

    @type t() :: %__MODULE__{
            err: integer()
          }
  end

  defmodule CreateResponse do
    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
            path: String.t()
          }
  end

  defmodule Create2Response do
    defstruct [
      :path,
      :stat
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            stat: Stat
          }
  end

  defmodule ExistsRequest do
    defstruct [
      :path,
      :watch
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            watch: boolean()
          }
  end

  defmodule ExistsResponse do
    defstruct [
      :stat
    ]

    @type t() :: %__MODULE__{
            stat: Stat
          }
  end

  defmodule GetDataResponse do
    defstruct [
      :data,
      :stat
    ]

    @type t() :: %__MODULE__{
            data: binary(),
            stat: Stat
          }
  end

  defmodule GetChildrenResponse do
    defstruct [
      :children
    ]

    @type t() :: %__MODULE__{
            children: list(String.t())
          }
  end

  defmodule GetAllChildrenNumberResponse do
    defstruct [
      :total_number
    ]

    @type t() :: %__MODULE__{
            total_number: integer()
          }
  end

  defmodule GetChildren2Response do
    defstruct [
      :children,
      :stat
    ]

    @type t() :: %__MODULE__{
            children: list(String.t()),
            stat: Stat
          }
  end

  defmodule GetACLResponse do
    defstruct [
      :acl,
      :stat
    ]

    @type t() :: %__MODULE__{
            acl: list(ACL),
            stat: Stat
          }
  end

  defmodule CheckWatchesRequest do
    defstruct [
      :path,
      :type
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            type: integer()
          }
  end

  defmodule RemoveWatchesRequest do
    defstruct [
      :path,
      :type
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            type: integer()
          }
  end

  defmodule GetEphemeralsRequest do
    defstruct [
      :prefix_path
    ]

    @type t() :: %__MODULE__{
            prefix_path: String.t()
          }
  end

  defmodule GetEphemeralsResponse do
    defstruct [
      :ephemerals
    ]

    @type t() :: %__MODULE__{
            ephemerals: list(String.t())
          }
  end

  defmodule WhoAmIResponse do
    defstruct [
      :client_info
    ]

    @type t() :: %__MODULE__{
            client_info: list(ClientInfo)
          }
  end
end

defmodule ExZk.Txn do
  defmodule TxnDigest do
    defstruct [
      :version,
      :tree_digest
    ]

    @type t() :: %__MODULE__{
            version: integer(),
            tree_digest: integer()
          }
  end

  defmodule TxnHeader do
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
  end

  defmodule CreateTxnV0 do
    defstruct [
      :path,
      :data,
      :acl,
      :ephemeral
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: list(ACL),
            ephemeral: boolean()
          }
  end

  defmodule CreateTxn do
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
            acl: list(ACL),
            ephemeral: boolean(),
            parent_c_version: integer()
          }
  end

  defmodule CreateTTLTxn do
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
            acl: list(ACL),
            parent_c_version: integer(),
            ttl: integer()
          }
  end

  defmodule CreateContainerTxn do
    defstruct [
      :path,
      :data,
      :acl,
      :parent_c_version
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            data: binary(),
            acl: list(ACL),
            parent_c_version: integer()
          }
  end

  defmodule DeleteTxn do
    defstruct [
      :path
    ]

    @type t() :: %__MODULE__{
            path: String.t()
          }
  end

  defmodule SetDataTxn do
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
  end

  defmodule CheckVersionTxn do
    defstruct [
      :path,
      :version
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            version: integer()
          }
  end

  defmodule SetACLTxn do
    defstruct [
      :path,
      :acl,
      :version
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            acl: list(ACL),
            version: integer()
          }
  end

  defmodule SetMaxChildrenTxn do
    defstruct [
      :path,
      :max
    ]

    @type t() :: %__MODULE__{
            path: String.t(),
            max: integer()
          }
  end

  defmodule CreateSessionTxn do
    defstruct [
      :time_out
    ]

    @type t() :: %__MODULE__{
            time_out: integer()
          }
  end

  defmodule CloseSessionTxn do
    defstruct [
      :paths2_delete
    ]

    @type t() :: %__MODULE__{
            paths2_delete: list(String.t())
          }
  end

  defmodule ErrorTxn do
    defstruct [
      :err
    ]

    @type t() :: %__MODULE__{
            err: integer()
          }
  end

  defmodule Txn do
    defstruct [
      :type,
      :data
    ]

    @type t() :: %__MODULE__{
            type: integer(),
            data: binary()
          }
  end

  defmodule MultiTxn do
    defstruct [
      :txns
    ]

    @type t() :: %__MODULE__{
            txns: list(Txn)
          }
  end
end