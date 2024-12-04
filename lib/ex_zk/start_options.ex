defmodule ExZk.StartOptions do
  @moduledoc false

  @default_port 2181
  @default_timeout 5_000

  start_link_opts_schema = [
    host: [
      type: {:custom, __MODULE__, :__validate_host__, []},
      doc: """
      the host where the Zookeeper server is running. If you are using a Zookeeper URI, you cannot
      use this option. Defaults to `"localhost`".
      """,
      type_doc: "`t:String.t/0`",
      type_spec: quote(do: String.t())
    ],
    port: [
      type: :non_neg_integer,
      default: @default_port,
      doc: """
      the port on which the Zookeeper server is running. If you are using a Zookeeper URI, you cannot
      use this option. Defaults to `6379`.
      """,
      type_doc: "`t::inet.port_number/0`",
      type_spec: quote(do: :inet.port_number())
    ],
    username: [
      type: {:or, [:string, nil]},
      doc: """
      the username to connect to Zookeeper. Defaults to `nil`, meaning no username is used.
      """,
      type_doc: "`t:String.t/0`",
      type_spec: quote(do: String.t() | nil)
    ],
    password: [
      type: {:or, [:string, :mfa]},
      doc: """
      the password used to connect to Zookeeper. Defaults to `nil`, meaning no password is used.
      """,
      type_doc: "`t:ExZk.password/0`",
      type_spec: quote(do: ExZk.password())
    ],
    timeout: [
      type: :timeout,
      default: @default_timeout,
      doc: """
      connection timeout (in milliseconds) directly passed to the network layer.
      """
    ],
    ssl: [
      type: :boolean,
      default: false,
      doc: """
      if `true`, connect through SSL, otherwise through TCP. The `:socket_opts` option applies
      to both SSL and TCP, so it can be used for things like certificates. See `:ssl.connect/4`.
      """
    ],
    name: [
      type: {:custom, __MODULE__, :__validate_name__, []},
      doc: """
      `ExZk.Session` is bound to the same registration rules as a `GenServer`. See the `GenServer`
      documentation for more information.
      """,
      type_doc: "`t:ExZk.name/0`",
      type_spec: quote(do: ExZk.name())
    ],
    socket_opts: [
      type: {:list, :any},
      default: [],
      doc: """
      specifies a list of options that are passed to the network layer when connecting to
      the Redis server. Some socket options (like `:active` or `:binary`) will be
      overridden by ExZk so that it functions properly.

      If `ssl: true`, then these are added to the default: `[verify: :verify_peer, depth: 3]`.
      If the `CAStore` dependency is available, the `:cacertfile` option is added
      to the SSL options by default as well.
      """,
      type_doc: "list of `t::gen_tcp.option/0`",
      type_spec: quote(do: list(:gen_tcp.option()))
    ]
  ]

  @ex_zk_start_link_opts_schema NimbleOptions.new!(start_link_opts_schema)
  @ex_zk_start_link_opts_typespc NimbleOptions.option_typespec(start_link_opts_schema)

  @spec options_docs(:ex_zk) :: String.t()
  def options_docs(:ex_zk), do: NimbleOptions.docs(@ex_zk_start_link_opts_schema)

  def options_typespec(:ex_zk), do: @ex_zk_start_link_opts_typespc

  def __validate_host__(host) when is_binary(host), do: {:ok, host}
  def __validate_host__({:local, path} = value) when is_binary(path), do: {:ok, value}

  def __validate_name__(name) when is_binary(name), do: {:ok, name}
  def __validate_name__({:global, name}) when is_binary(name), do: {:ok, name}
  def __validate_name__({:via, mod, name}) when is_atom(mod) and is_binary(name), do: {:ok, name}
end
