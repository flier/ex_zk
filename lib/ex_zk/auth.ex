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

  def new({:digest, {username, password}}) when is_binary(username) and is_binary(password),
    do: digest(username, password)

  def new({:x509, subject_principal}) when is_binary(subject_principal),
    do: x509(subject_principal)

  def new({:ip, addr}) when is_binary(addr), do: ip(addr)
  def new({:ip, addr}) when is_tuple(addr), do: ip(addr)

  @spec digest(username :: String.t(), password :: String.t()) :: Info.t()
  def digest(username, password) when is_binary(username) and is_binary(password) do
    %Info{scheme: @digest_scheme, data: "#{username}:#{password}"}
  end

  @spec x509(subject_principal :: String.t()) :: Info.t()
  def x509(subject_principal) when is_binary(subject_principal) do
    %Info{scheme: @x509_scheme, data: subject_principal}
  end

  @spec ip(addr :: String.t() | :inet.ip_address()) :: Info.t()
  def ip(addr) when is_binary(addr), do: %Info{scheme: @ip_scheme, data: addr}

  def ip(addr) when is_tuple(addr),
    do: %Info{scheme: @ip_scheme, data: to_string(:inet.ntoa(addr))}
end
