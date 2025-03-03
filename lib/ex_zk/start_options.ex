defmodule ExZk.StartOptions do
  @moduledoc """
  Options that can be passed to starts a session to Zookeeper (see `ExZk.start_link/1`).
  """

  use ExZk.Defs

  alias ExZk.Auth

  start_link_opts_schema = [
    host: [
      type: {:custom, __MODULE__, :__validate_host__, []},
      default: @default_host,
      doc: """
      the host where the Zookeeper server is running.
      If you are using a Zookeeper URI, you cannot use this option.
      Defaults to `#{@default_host}`".
      """,
      type_doc: "`t:String.t/0`",
      type_spec: quote(do: String.t())
    ],
    port: [
      type: :non_neg_integer,
      default: @default_port,
      doc: """
      the port on which the Zookeeper server is running.
      If you are using a Zookeeper URI, you cannot use this option.
      Defaults to `#{@default_port}`.
      """,
      type_doc: "`t::inet.port_number/0`",
      type_spec: quote(do: :inet.port_number())
    ],
    username: [
      type: {:or, [:string, nil]},
      doc: """
      the username to connect to Zookeeper.
      Defaults to `nil`, meaning no username is used.
      """,
      type_doc: "`t:String.t/0`",
      type_spec: quote(do: String.t() | nil)
    ],
    password: [
      type: {:or, [:string, :mfa]},
      doc: """
      the password used to connect to Zookeeper.
      Defaults to `nil`, meaning no password is used.
      """,
      type_doc: "`t:ExZk.password/0`",
      type_spec: quote(do: ExZk.password() | nil)
    ],
    timeout: [
      type: :timeout,
      default: @default_timeout,
      doc: """
      connect timeout (in milliseconds) directly passed to the network layer.
      """
    ],
    sync_connect: [
      type: :boolean,
      default: false,
      doc: """
      decides whether ExZk should initiate the network connection to the Zookeeper server *before*
      or *after* returning from `start_link/1`. This option also changes some reconnection
      semantics; read the "Reconnections" page in the documentation for more information.
      """
    ],
    exit_on_disconnection: [
      type: :boolean,
      default: false,
      doc: """
      if `true`, the ExZk session will exit if it fails to connect or disconnects from Zookeeper.
      Note that setting this option to `true` means that the `:backoff_initial` and
      `:backoff_max` options will be ignored.
      """
    ],
    backoff_initial: [
      type: :timeout,
      default: @default_backoff_initial,
      doc: """
      the initial backoff time (in milliseconds), which is the time that the Zookeeper process
      will wait before attempting to reconnect to Redis after a disconnection or failed first
      connection. See the "Reconnections" page in the docs for more information.
      """
    ],
    backoff_max: [
      type: :timeout,
      default: @default_backoff_max,
      doc: """
      the maximum length (in milliseconds) of the time interval used between reconnection
      attempts. See the "Reconnections" page in the docs for more information.
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
    transport_module: [
      type: :mod_arg,
      doc: """
      `ExZk.Socket` use the transport module for network communication.
      """
    ],
    socket_opts: [
      type: {:list, :any},
      default: [],
      doc: """
      specifies a list of options that are passed to the network layer when connecting to
      the Zookeeper server. Some socket options (like `:active` or `:binary`) will be
      overridden by ExZk so that it functions properly.

      If `ssl: true`, then these are added to the default: `[verify: :verify_peer, depth: 3]`.
      If the `CAStore` dependency is available, the `:cacertfile` option is added
      to the SSL options by default as well.
      """,
      type_doc: "list of `t::gen_tcp.option/0`",
      type_spec: quote(do: list(:gen_tcp.option()))
    ],
    session_timeout: [
      type: :timeout,
      default: @default_session_timeout,
      doc: """
      Zookeeper session timeout
      """
    ],
    readonly: [
      type: :boolean,
      doc: """
      if `true`, the session will be read-only
      """
    ],
    auth_info: [
      type: {:custom, __MODULE__, :__validate_auth_info__, []},
      doc: """
      authentication information for the session
      """,
      type_doc: "list of `t:ExZk.Auth.Info.t/0`",
      type_spec: quote(do: list(Auth.Info.t()))
    ],
    disable_auto_watch_reset: [
      type: :boolean,
      default: false,
      doc: """
      This controls whether automatic watch resetting is enabled.
      Clients automatically reset watches during session reconnect,
      this option allows the client to turn off this behavior
      by setting the option :disable_auto_watch_reset to true
      """
    ]
  ]

  @ex_zk_start_link_opts_schema NimbleOptions.new!(start_link_opts_schema)
  @ex_zk_start_link_opts_typespc NimbleOptions.option_typespec(start_link_opts_schema)

  @spec options_docs(:ex_zk) :: String.t()
  def options_docs(:ex_zk), do: NimbleOptions.docs(@ex_zk_start_link_opts_schema)

  def options_typespec(:ex_zk), do: @ex_zk_start_link_opts_typespc

  @doc """
  Validate start options

  ## Examples

      iex> import ExZk.StartOptions
      iex> {:ok, _} = validate(host: "localhost", port: 2181)
      iex> {:ok, _} = validate(host: {127, 0, 0, 1})
      iex> {:ok, _} = validate(host: {0, 0, 0, 0, 0, 0, 0, 1})
      iex> {:error, %NimbleOptions.ValidationError{
      ...>    message: "invalid value for :host option: invalid IP address: {127, 0}",
      ...> }} = validate(host: {127, 0})
      iex> {:error, %NimbleOptions.ValidationError{
      ...>    message: "invalid value for :host option: host must be a string or IP address",
      ...> }} = validate(host: 123)
      iex> {:ok, _} = validate(name: "test")
      iex> {:ok, _} = validate(name: {:global, "test"})
      iex> {:ok, _} = validate(name: {:via, :supervisor, "test"})
      iex> {:error, %NimbleOptions.ValidationError{
      ...>    message: "invalid value for :name option: name must be a binary, {:global, name} or {:via, module, name}",
      ...> }} = validate(name: nil)
      iex> {:ok, _} = validate(auth_info: {:digest, {"user", "pass"}})
      iex> {:ok, _} = validate(auth_info: {:ip, "127.0.0.1"})
      iex> {:ok, _} = validate(auth_info: {:ip, {127, 0, 0, 1}})
      iex> {:ok, _} = validate(auth_info: {:ip, ":1"})
      iex> {:ok, _} = validate(auth_info: {:ip, {0, 0, 0, 0, 0, 0, 0, 1}})
      iex> {:error, %NimbleOptions.ValidationError{
      ...>   message: "invalid value for :auth_info option: invalid IP address: {0, 0}",
      ...> }} = validate(auth_info: {:ip, {0, 0}})
      iex> {:ok, _} = validate(auth_info: {:x509, "CN=localhost,OU=ZooKeeper,O=Apache,L=Unknown,ST=Unknown,C=Unknown"})
      iex> {:ok, _} = validate(auth_info: [{:digest, {"user", "pass"}}, {:ip, "127.0.0.1"}])
      iex> {:error, %NimbleOptions.ValidationError{
      ...>    message: "invalid value for :auth_info option: auth_info must be {:digest, {username, password}}, {:ip, addr} or {:x509, subject}",
      ...> }} = validate(auth_info: nil)

  """
  def validate(opts), do: NimbleOptions.validate(opts, @ex_zk_start_link_opts_schema)

  def __validate_host__(host) when is_binary(host), do: {:ok, host}

  def __validate_host__(host) when is_tuple(host) do
    if :inet.is_ip_address(host) do
      {:ok, host}
    else
      {:error, "invalid IP address: #{inspect(host)}"}
    end
  end

  def __validate_host__(_), do: {:error, "host must be a string or IP address"}

  def __validate_name__(name) when is_binary(name), do: {:ok, name}
  def __validate_name__({:global, name}) when is_binary(name), do: {:ok, name}
  def __validate_name__({:via, mod, name}) when is_atom(mod) and is_binary(name), do: {:ok, name}

  def __validate_name__(_),
    do: {:error, "name must be a binary, {:global, name} or {:via, module, name}"}

  def __validate_auth_info__(auth_info) when is_list(auth_info) do
    if Enum.all?(auth_info, &__validate_auth_info__(&1)) do
      {:ok, auth_info}
    else
      {:error, auth_info}
    end
  end

  def __validate_auth_info__({:digest, {username, password}})
      when is_binary(username) and is_binary(password),
      do: {:ok, {:digest, {username, password}}}

  def __validate_auth_info__({:ip, addr}) when is_binary(addr), do: {:ok, {:ip, addr}}

  def __validate_auth_info__({:ip, addr}) when is_tuple(addr) do
    if :inet.is_ip_address(addr) do
      {:ok, addr}
    else
      {:error, "invalid IP address: #{inspect(addr)}"}
    end
  end

  def __validate_auth_info__({:x509, subject}) when is_binary(subject),
    do: {:ok, {:x509, subject}}

  def __validate_auth_info__(_),
    do:
      {:error,
       "auth_info must be {:digest, {username, password}}, {:ip, addr} or {:x509, subject}"}
end
