defmodule ExZk.Txn do
  defmodule Digest do
    defstruct [:version, :tree_digest]

    @type t() :: %__MODULE__{
            version: integer(),
            tree_digest: integer()
          }
  end

  defmodule Header do
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

  defmodule CreateV0 do
    alias ExZk.Data.ACL

    defstruct [
      :path,
      :data,
      :acl,
      :ephemeral
    ]

    @type t() :: %__MODULE__{
            path: Path.t(),
            data: binary(),
            acl: [ACL.t()],
            ephemeral: boolean()
          }
  end

  defmodule Create do
    alias ExZk.Data
    alias ExZk.Data.ACL

    defstruct [
      :path,
      :data,
      :acl,
      :ephemeral,
      :parent_cversion
    ]

    @type t() :: %__MODULE__{
            path: Path.t(),
            data: binary(),
            acl: [ACL.t()],
            ephemeral: boolean(),
            parent_cversion: Data.version()
          }
  end

  defmodule CreateTTL do
    alias ExZk.Data
    alias ExZk.Data.ACL

    defstruct [
      :path,
      :data,
      :acl,
      :parent_cversion,
      :ttl
    ]

    @type t() :: %__MODULE__{
            path: Path.t(),
            data: binary(),
            acl: [ACL.t()],
            parent_cversion: Data.version(),
            ttl: non_neg_integer()
          }
  end

  defmodule CreateContainer do
    alias ExZk.Data
    alias ExZk.Data.ACL

    defstruct [
      :path,
      :data,
      :acl,
      :parent_cversion
    ]

    @type t() :: %__MODULE__{
            path: Path.t(),
            data: binary(),
            acl: [ACL.t()],
            parent_cversion: Data.version()
          }
  end

  defmodule Delete do
    defstruct [:path]

    @type t() :: %__MODULE__{
            path: Path.t()
          }
  end

  defmodule SetData do
    alias ExZk.Data

    defstruct [:path, :data, :version]

    @type t() :: %__MODULE__{
            path: Path.t(),
            data: binary(),
            version: Data.version()
          }
  end

  defmodule CheckVersion do
    alias ExZk.Data

    defstruct [:path, :version]

    @type t() :: %__MODULE__{
            path: Path.t(),
            version: Data.version()
          }
  end

  defmodule SetACL do
    alias ExZk.Data
    alias ExZk.Data.ACL

    defstruct [:path, :acl, :version]

    @type t() :: %__MODULE__{
            path: Path.t(),
            acl: [ACL.t()],
            version: Data.version()
          }
  end

  defmodule SetMaxChildren do
    defstruct [:path, :max]

    @type t() :: %__MODULE__{
            path: Path.t(),
            max: integer()
          }
  end

  defmodule CreateSession do
    defstruct [:timeout]

    @type t() :: %__MODULE__{
            timeout: integer()
          }
  end

  defmodule CloseSession do
    defstruct [:paths_to_delete]

    @type t() :: %__MODULE__{
            paths_to_delete: [Path.t()]
          }
  end

  defmodule Error do
    defstruct [:err]

    @type t() :: %__MODULE__{
            err: integer()
          }
  end

  defmodule Txn do
    defstruct [:type, :data]

    @type t() :: %__MODULE__{
            type: integer(),
            data: binary()
          }
  end

  defmodule MultiTxn do
    defstruct [:txns]

    @type t() :: %__MODULE__{
            txns: [Txn.t()]
          }
  end
end
