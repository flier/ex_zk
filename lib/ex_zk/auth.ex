defmodule ExZk.Auth do
  defmodule Info do
    defstruct [:scheme, :data]

    @type t :: %__MODULE__{
            scheme: String.t(),
            data: binary()
          }
  end

  @digest_scheme "digest"
  @x509_scheme "x509"
  @ip_scheme "ip"

  @type info ::
          {:digest, {username :: String.t(), password :: String.t()}}
          | {:x509, subject_principal :: String.t()}
          | {:ip, addr :: String.t() | :inet.ip_address()}

  @doc """
  Create a new auth info

  ## Examples

      iex> ExZk.Auth.new({:digest, {"username", "password"}})
      %ExZk.Auth.Info{scheme: "digest", data: "username:password"}

      iex> ExZk.Auth.new({:x509, "CN=example.com"})
      %ExZk.Auth.Info{scheme: "x509", data: "CN=example.com"}

      iex> ExZk.Auth.new({:ip, "127.0.0.1"})
      %ExZk.Auth.Info{scheme: "ip", data: "127.0.0.1"}

      iex> ExZk.Auth.new({:ip, {127, 0, 0, 1}})
      %ExZk.Auth.Info{scheme: "ip", data: "127.0.0.1"}

      iex> ExZk.Auth.new({:ip, {0, 0, 0, 0, 0, 0, 0, 1}})
      %ExZk.Auth.Info{scheme: "ip", data: "::1"}
  """
  @spec new(info()) :: Info.t()

  def new({:digest, {username, password}}), do: digest(username, password)
  def new({:x509, subject_principal}), do: x509(subject_principal)
  def new({:ip, addr}), do: ip(addr)

  @doc """
  Create a new digest auth info

  ## Examples

      iex> ExZk.Auth.digest("username", "password")
      %ExZk.Auth.Info{scheme: "digest", data: "username:password"}
  """
  @spec digest(username :: String.t(), password :: String.t()) :: Info.t()
  def digest(username, password) when is_binary(username) and is_binary(password) do
    %Info{scheme: @digest_scheme, data: "#{username}:#{password}"}
  end

  @doc """
  Create a new x509 auth info

  ## Examples

      iex> ExZk.Auth.x509("CN=example.com")
      %ExZk.Auth.Info{scheme: "x509", data: "CN=example.com"}
  """
  @spec x509(subject_principal :: String.t()) :: Info.t()
  def x509(subject_principal) when is_binary(subject_principal) do
    %Info{scheme: @x509_scheme, data: subject_principal}
  end

  @doc """
  Create a new ip auth info

  ## Examples

      iex> ExZk.Auth.ip("127.0.0.1")
      %ExZk.Auth.Info{scheme: "ip", data: "127.0.0.1"}
  """
  @spec ip(addr :: String.t() | :inet.ip_address()) :: Info.t()
  def ip(addr) when is_binary(addr), do: %Info{scheme: @ip_scheme, data: addr}

  def ip(addr) when is_tuple(addr),
    do: %Info{scheme: @ip_scheme, data: to_string(:inet.ntoa(addr))}
end
