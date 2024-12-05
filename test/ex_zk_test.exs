defmodule ExZkTest do
  use ExUnit.Case
  doctest ExZk
  doctest ExZk.Connection
  doctest ExZk.Connector
  doctest ExZk.Data
  doctest ExZk.Proto
  doctest ExZk.Socket
  doctest ExZk.Txn
  doctest ExZk.URI

  @server "127.0.0.1:2181"
  @path "/test"

  setup context do
    :ok
  end

  describe "given a connection to a zk server" do
  end
end
