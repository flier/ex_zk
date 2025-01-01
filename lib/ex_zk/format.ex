defmodule ExZk.Format do
  @moduledoc """
  Used for formatting things to print or log or anything like that.

  ## Examples

      iex> import ExZk.Format
      iex> format_host_and_port("localhost", 2181)
      "localhost:2181"
      iex> format_host_and_port(~c"localhost", 2181)
      "localhost:2181"
      iex> format_host_and_port({127, 0, 0, 1}, 2181)
      "127.0.0.1:2181"
      iex> format_host_and_port({0,0,0,0,0,0,0,1}, 2181)
      "[::1]:2181"
      iex> format_host_and_port({0}, 2181)
      ** (ArgumentError) invalid host: {0}
  """

  @spec format_host_and_port(host, :inet.port_number()) :: String.t()
        when host: charlist() | binary() | :inet.ip_address()
  def format_host_and_port(host, port)

  def format_host_and_port(host, port) when is_binary(host) and is_integer(port),
    do: "#{host}:#{port}"

  def format_host_and_port(host, port) when is_list(host),
    do: format_host_and_port(IO.chardata_to_string(host), port)

  def format_host_and_port(ip_addr, port) when is_tuple(ip_addr) do
    case :inet.ntoa(ip_addr) do
      {:error, :einval} ->
        raise ArgumentError, "invalid host: #{inspect(ip_addr)}"

      addr ->
        format_host_and_port(
          if(:inet.is_ipv6_address(ip_addr), do: "[#{addr}]", else: addr),
          port
        )
    end
  end
end
