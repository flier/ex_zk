defmodule ExZk.URI do
  @moduledoc """
  This module provides functions to work with a Zookeeper URI.
  """

  ####
  ## Public API
  ##

  @doc """
  Returns start options from a Zookeeper URI.

  A **Zookeeper URI** looks like this:

      zk://[username:password@]host[:port][/path]

  ## Examples

      iex> ExZk.URI.to_start_options("zk://example.com")
      [host: "example.com"]

      iex> ExZk.URI.to_start_options("tcp://example.com")
      [host: "example.com"]

      iex> ExZk.URI.to_start_options("http://example.com")
      ** (ArgumentError) expected scheme to be zk://, tcp://, or ssl://, got: http://

      iex> ExZk.URI.to_start_options("ssl://username:password@example.com:2181/zookeeper")
      [ssl: true, path: "/zookeeper", password: "password", username: "username", port: 2181, host: "example.com"]

      iex> ExZk.URI.to_start_options("ssl://:password@example.com:2181/zookeeper")
      [ssl: true, path: "/zookeeper", password: "password", port: 2181, host: "example.com"]

      iex> ExZk.URI.to_start_options("ssl://username:@example.com:2181/zookeeper")
      ** (ArgumentError) expected password in the Zookeeper URI to be given as zk://:PASSWORD@HOST or zk://USERNAME:PASSWORD@HOST


  """
  @spec to_start_options(binary()) :: keyword()
  def to_start_options(uri) when is_binary(uri) do
    %URI{host: host, port: port, scheme: scheme} = uri = URI.parse(uri)

    unless scheme in ["zk", "tcp", "ssl"] do
      raise ArgumentError,
            "expected scheme to be zk://, tcp://, or ssl://, got: #{scheme}://"
    end

    {username, password} = username_and_password(uri)

    []
    |> put_if_not_nil(:host, host)
    |> put_if_not_nil(:port, port)
    |> put_if_not_nil(:username, username)
    |> put_if_not_nil(:password, password)
    |> put_if_not_nil(:path, path(uri))
    |> enable_ssl_if_secure_scheme(scheme)
  end

  ####
  ## Private methods
  ##

  defp username_and_password(%URI{userinfo: nil}), do: {nil, nil}

  defp username_and_password(%URI{userinfo: userinfo}),
    do: String.split(userinfo, ":", parts: 2) |> username_and_password()

  defp username_and_password(["", password]), do: {nil, password}

  defp username_and_password([_, ""]),
    do:
      raise(
        ArgumentError,
        "expected password in the Zookeeper URI to be given as zk://:PASSWORD@HOST or zk://USERNAME:PASSWORD@HOST"
      )

  defp username_and_password([username, password]), do: {username, password}

  defp path(%URI{path: path}) when path in [nil, "", "/"], do: nil
  defp path(%URI{path: "/" <> _ = path}), do: path

  defp put_if_not_nil(opts, _key, nil), do: opts
  defp put_if_not_nil(opts, key, value), do: Keyword.put(opts, key, value)

  defp enable_ssl_if_secure_scheme(opts, "ssl"), do: Keyword.put(opts, :ssl, true)
  defp enable_ssl_if_secure_scheme(opts, _scheme), do: opts
end
