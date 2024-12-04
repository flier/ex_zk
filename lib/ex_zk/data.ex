defmodule ExZk.Data do
  @type timestamp() :: non_neg_integer()

  @type zxid() :: non_neg_integer()

  @type version() :: integer()

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
    alias ExZk.Data.Id

    defstruct [
      :perms,
      :id
    ]

    @type t() :: %__MODULE__{
            perms: integer(),
            id: Id.t()
          }
  end

  defmodule Stat do
    @moduledoc """
    information shared with the client
    """

    alias ExZk.Data

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
            czxid: Data.zxid(),
            mzxid: Data.zxid(),
            ctime: Data.timestamp(),
            mtime: Data.timestamp(),
            version: Data.version(),
            cversion: Data.version(),
            aversion: Data.version(),
            ephemeral_owner: integer(),
            data_length: integer(),
            num_children: integer(),
            pzxid: Data.zxid()
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
