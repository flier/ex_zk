defmodule DocTest do
  use ExUnit.Case, async: true

  doctest ExZk
  doctest ExZk.Auth
  doctest ExZk.Connector
  doctest ExZk.Create
  doctest ExZk.Defs.ACL
  doctest ExZk.Defs.Id
  doctest ExZk.Defs.Perms
  doctest ExZk.Error
  doctest ExZk.Format
  doctest ExZk.Jute
  doctest ExZk.Jute.Binding
  doctest ExZk.Jute.Parser
  doctest ExZk.Session
  doctest ExZk.Socket
  doctest ExZk.Socket.Error
  doctest ExZk.StartOptions
  doctest ExZk.TypedEnum
  doctest ExZk.URI
  doctest ExZk.Wire
  doctest ExZk.Wire.Value

  doctest ExZk.Data
  doctest ExZk.Proto
  doctest ExZk.Txn
end
