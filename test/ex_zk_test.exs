defmodule ExZkTest do
  use ExUnit.Case, async: true

  doctest ExZk
  doctest ExZk.Connector
  doctest ExZk.Defs.ACL
  doctest ExZk.Defs.Id
  doctest ExZk.Defs.Perms
  doctest ExZk.Jute
  doctest ExZk.Jute.Binding
  doctest ExZk.Jute.Parser
  doctest ExZk.Session
  doctest ExZk.Socket
  doctest ExZk.TypedEnum
  doctest ExZk.URI
  doctest ExZk.Wire

  doctest ExZk.Data
  doctest ExZk.Proto
  doctest ExZk.Txn
end
