defmodule CreateTest do
  use ExUnit.Case, async: true

  import ExZk.Defs.ACL

  alias ExZk.Create
  alias ExZk.Proto.{CreateRequest, CreateTTLRequest}

  @path "/foo/bar"
  @data "hello world"
  @acls [creator_all_acl()]

  describe "it create a create request for" do
    test "a persistent node" do
      assert Create.new_request(@path, @data) ==
               {:create, %CreateRequest{path: @path, data: @data, acl: default_acls()}}
    end

    test "a persistent sequential mode" do
      assert Create.new_request(@path, @data, mode: :persistent_sequential) ==
               {:create,
                %CreateRequest{
                  path: @path,
                  data: @data,
                  acl: default_acls(),
                  flags: Create.Mode.value!(:persistent_sequential)
                }}
    end

    test "a container node" do
      assert Create.new_request(@path, @data, mode: :container) ==
               {:create_container,
                %CreateRequest{
                  path: @path,
                  data: @data,
                  acl: default_acls(),
                  flags: Create.Mode.value!(:container)
                }}
    end

    test "a node with TTL" do
      assert Create.new_request(@path, @data, mode: :persistent_with_ttl, ttl: 300) ==
               {:create_ttl,
                %CreateTTLRequest{
                  path: @path,
                  data: @data,
                  acl: default_acls(),
                  flags: Create.Mode.value!(:persistent_with_ttl),
                  ttl: 300
                }}
    end

    test "a node with ACL" do
      assert Create.new_request(@path, @data, acl: @acls) ==
               {:create, %CreateRequest{path: @path, data: @data, acl: @acls}}
    end
  end
end
