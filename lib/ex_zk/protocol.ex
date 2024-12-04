defmodule ExZk.Protocol do
  @type session_id() :: integer()

  defmodule Connect do
    defmodule Request do
      alias ExZk.Data
      alias ExZk.Protocol

      defstruct [
        :protocol_version,
        :last_zxid_seen,
        :timeout,
        :session_id,
        :password,
        :read_only
      ]

      @type t :: %__MODULE__{
              protocol_version: integer(),
              last_zxid_seen: Data.zxid(),
              timeout: integer(),
              session_id: Protocol.session_id(),
              password: binary(),
              read_only: boolean()
            }
    end

    defmodule Response do
      alias ExZk.Protocol

      defstruct [
        :protocol_version,
        :timeout,
        :session_id,
        :password,
        :read_only
      ]

      @type t() :: %__MODULE__{
              protocol_version: integer(),
              timeout: integer(),
              session_id: Protocol.session_id(),
              password: binary(),
              read_only: boolean()
            }
    end
  end

  defmodule SetWatches do
    alias ExZk.Data

    defstruct [
      :relative_zxid,
      :data_watches,
      :exist_watches,
      :child_watches
    ]

    @type t :: %__MODULE__{
            relative_zxid: Data.zxid(),
            data_watches: [Path.t()],
            exist_watches: [Path.t()],
            child_watches: [Path.t()]
          }
  end

  defmodule SetWatches2 do
    alias ExZk.Data

    defstruct [
      :relative_zxid,
      :data_watches,
      :exist_watches,
      :child_watches,
      :persistent_watches,
      :persistent_recursive_watches
    ]

    @type t :: %__MODULE__{
            relative_zxid: Data.zxid(),
            data_watches: [Path.t()],
            exist_watches: [Path.t()],
            child_watches: [Path.t()],
            persistent_watches: [Path.t()],
            persistent_recursive_watches: [Path.t()]
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
    alias ExZk.Data

    defstruct [
      :xid,
      :zxid,
      :err
    ]

    @type t() :: %__MODULE__{
            xid: integer(),
            zxid: Data.zxid(),
            err: integer()
          }
  end

  defmodule GetData do
    defmodule Request do
      defstruct [
        :path,
        :watch
      ]

      @type t() :: %__MODULE__{
              path: Path.t(),
              watch: boolean()
            }
    end

    defmodule Response do
      alias ExZk.Data.Stat

      defstruct [:data, :stat]

      @type t() :: %__MODULE__{
              data: binary(),
              stat: Stat.t()
            }
    end
  end

  defmodule SetData do
    defmodule Request do
      alias ExZk.Data

      defstruct [
        :path,
        :data,
        :version
      ]

      @type t() :: %__MODULE__{
              path: Path.t(),
              data: binary(),
              version: Data.version()
            }
    end

    defmodule Resonse do
      alias ExZk.Data.Stat

      defstruct [:stat]

      @type t() :: %__MODULE__{
              stat: Stat.t()
            }
    end
  end

  defmodule GetSASL do
    defmodule Request do
      defstruct [:token]

      @type t() :: %__MODULE__{
              token: binary()
            }
    end
  end

  defmodule SetSASL do
    defmodule Request do
      defstruct [:token]

      @type t() :: %__MODULE__{
              token: binary()
            }
    end

    defmodule Response do
      defstruct [:token]

      @type t() :: %__MODULE__{
              token: binary()
            }
    end
  end

  defmodule Create do
    defmodule Request do
      alias ExZk.Data.ACL

      defstruct [
        :path,
        :data,
        :acl,
        :flags
      ]

      @type t() :: %__MODULE__{
              path: Path.t(),
              data: binary(),
              acl: [ACL.t()],
              flags: integer()
            }
    end

    defmodule Response do
      defstruct [:path]

      @type t() :: %__MODULE__{
              path: Path.t()
            }
    end
  end

  defmodule CreateTTL do
    defmodule Request do
      alias ExZk.Data.ACL

      defstruct [
        :path,
        :data,
        :acl,
        :flags,
        :ttl
      ]

      @type t() :: %__MODULE__{
              path: Path.t(),
              data: binary(),
              acl: [ACL.t()],
              flags: integer(),
              ttl: integer() | nil
            }
    end

    defmodule Response do
      defstruct [:path]

      @type t() :: %__MODULE__{
              path: Path.t()
            }
    end
  end

  defmodule Create2 do
    defmodule Response do
      alias ExZk.Data.Stat

      defstruct [:path, :stat]

      @type t() :: %__MODULE__{
              path: Path.t(),
              stat: Stat.t()
            }
    end
  end

  defmodule Delete do
    defmodule Request do
      alias ExZk.Data

      defstruct [
        :path,
        :version
      ]

      @type t() :: %__MODULE__{
              path: Path.t(),
              version: Data.version()
            }
    end
  end

  defmodule GetChildren do
    defmodule Request do
      defstruct [:path, :watch]

      @type t() :: %__MODULE__{
              path: Path.t(),
              watch: boolean()
            }
    end

    defmodule Response do
      defstruct [:children]

      @type t() :: %__MODULE__{
              children: [Path.t()]
            }
    end
  end

  defmodule GetAllChildrenNumber do
    defmodule Request do
      defstruct [:path]

      @type t() :: %__MODULE__{
              path: Path.t()
            }
    end

    defmodule Response do
      defstruct [:total_number]

      @type t() :: %__MODULE__{
              total_number: integer()
            }
    end
  end

  defmodule GetChildren2 do
    defmodule Request do
      defstruct [:path, :watch]

      @type t() :: %__MODULE__{
              path: Path.t(),
              watch: boolean()
            }
    end

    defmodule Response do
      alias ExZk.Data.Stat

      defstruct [:children, :stat]

      @type t() :: %__MODULE__{
              children: [Path.t()],
              stat: Stat.t()
            }
    end
  end

  defmodule CheckVersion do
    defmodule Request do
      alias ExZk.Data

      defstruct [:path, :version]

      @type t() :: %__MODULE__{
              path: Path.t(),
              version: Data.version()
            }
    end
  end

  defmodule GetMaxChildren do
    defmodule Request do
      defstruct [:path]

      @type t() :: %__MODULE__{
              path: Path.t()
            }
    end

    defmodule Response do
      defstruct [:max]

      @type t() :: %__MODULE__{
              max: integer()
            }
    end
  end

  defmodule SetMaxChildren do
    defmodule Request do
      defstruct [:path, :max]

      @type t() :: %__MODULE__{
              path: Path.t(),
              max: integer()
            }
    end
  end

  defmodule Sync do
    defmodule Request do
      defstruct [:path]

      @type t() :: %__MODULE__{
              path: Path.t()
            }
    end

    defmodule Response do
      defstruct [:path]

      @type t() :: %__MODULE__{
              path: Path.t()
            }
    end
  end

  defmodule GetACL do
    defmodule Request do
      defstruct [:path]

      @type t() :: %__MODULE__{
              path: Path.t()
            }
    end

    defmodule Response do
      alias ExZk.Data.{ACL, Stat}

      defstruct [:acl, :stat]

      @type t() :: %__MODULE__{
              acl: [ACL.t()],
              stat: Stat.t()
            }
    end
  end

  defmodule SetACL do
    defmodule Request do
      alias ExZk.Data.ACL

      defstruct [:path, :acl, :version]

      @type t() :: %__MODULE__{
              path: Path.t(),
              acl: [ACL.t()],
              version: ExZk.Data.version()
            }
    end

    defmodule Response do
      alias ExZk.Data.Stat

      defstruct [:stat]

      @type t() :: %__MODULE__{
              stat: Stat.t()
            }
    end
  end

  defmodule AddWatch do
    defmodule Request do
      defstruct [:path, :mode]

      @type t() :: %__MODULE__{
              path: String.t(),
              mode: integer()
            }
    end
  end

  defmodule WatcherEvent do
    defstruct [
      :type,
      :state,
      :path
    ]

    @type t :: %__MODULE__{
            type: integer(),
            state: integer(),
            path: String.t()
          }
  end

  defmodule Error do
    defmodule Response do
      defstruct [:err]

      @type t() :: %__MODULE__{
              err: integer()
            }
    end
  end

  defmodule Exists do
    defmodule Request do
      defstruct [:path, :watch]

      @type t() :: %__MODULE__{
              path: Path.t(),
              watch: boolean()
            }
    end

    defmodule Response do
      alias ExZk.Data.Stat

      defstruct [:stat]

      @type t() :: %__MODULE__{
              stat: Stat.t()
            }
    end
  end

  defmodule CheckWatches do
    defmodule Request do
      defstruct [:path, :type]

      @type t() :: %__MODULE__{
              path: Path.t(),
              type: integer()
            }
    end
  end

  defmodule RemoveWatches do
    defmodule Request do
      defstruct [:path, :type]

      @type t() :: %__MODULE__{
              path: Path.t(),
              type: integer()
            }
    end
  end

  defmodule GetEphemerals do
    defmodule Request do
      defstruct [:prefix_path]

      @type t() :: %__MODULE__{
              prefix_path: Path.t()
            }
    end

    defmodule Response do
      defstruct [:ephemerals]

      @type t() :: %__MODULE__{
              ephemerals: [Path.t()]
            }
    end
  end

  defmodule WhoAmI do
    defmodule Response do
      alias ExZk.Data.ClientInfo

      defstruct [:client_info]

      @type t() :: %__MODULE__{
              client_info: ClientInfo.t()
            }
    end
  end
end
