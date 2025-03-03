defmodule ExZk.Format do
  @moduledoc """
  Used for formatting things to print or log or anything like that.
  """

  @doc """
  Returns a string of the form `host:port`

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

  @doc """
  Returns a string of session identifier

  ## Examples

      iex> import ExZk.Format
      iex> format_session_id(0)
      "-"
      iex> format_session_id(0x123456)
      "00123456"
  """
  @spec format_session_id(session_id :: integer()) :: String.t()
  def format_session_id(session_id) when session_id in [nil, 0], do: "-"

  def format_session_id(session_id) when is_integer(session_id),
    do: session_id |> Integer.to_string(16) |> String.pad_leading(8, "0")
end
