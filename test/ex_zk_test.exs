defmodule ExZkTest do
  use ExUnit.Case, async: true

  use ExZk.Defs

  import ExZk.Defs.ACL

  alias ExZk.{Create, Multi, Proto}
  alias ExZk.Data.{ClientInfo, Stat}

  @path "/foo/bar"
  @data "hello world"
  @children ["a", "b", "c"]
  @stat %Stat{}
  @version 123
  @ttl 60
  @acls default_acls()
  @client_info %ClientInfo{auth_scheme: "digest", user: "username"}
  @multi_ops [
    Multi.Op.create(@path, @data),
    Multi.Op.check(@path, @version),
    Multi.Op.delete(@path),
    Multi.Op.get_children(@path),
    Multi.Op.get_data(@path),
    Multi.Op.set_data(@path, @data)
  ]
  @multi_results [
    {:create, @path, @stat},
    {:check, true},
    {:delete, :ok},
    {:get_children, @children},
    {:get_data, @data, @stat},
    {:set_data, @stat}
  ]

  defmodule MockSession do
    @behaviour :gen_statem

    def start_link(args) do
      :gen_statem.start_link(__MODULE__, args, [])
    end

    @impl true
    def callback_mode, do: :state_functions

    @impl true
    def init(args) do
      {:ok, :connected, args}
    end

    def connected({:call, from}, :status, data) do
      {:keep_state_and_data, {:reply, from, {:connected, data}}}
    end

    def connected({:call, from}, {:send_request, opcode, request}, data) do
      case data[opcode] do
        {^request, response} ->
          {:keep_state, %{data | opcode => nil}, {:reply, from, response}}

        [{^request, response} | rest] ->
          {:keep_state, %{data | opcode => rest}, {:reply, from, response}}
      end
    end
  end

  describe "given a mock session" do
    test "it can be closed" do
      {:ok, session} = MockSession.start_link(%{})

      assert ExZk.close(session) == :ok
      assert !Process.alive?(session)
    end

    test "it can get status" do
      {:ok, session} = MockSession.start_link(%{})

      assert ExZk.status(session) == {:connected, %{}}
    end

    test "it can get children" do
      {:ok, session} =
        MockSession.start_link(%{
          get_children:
            {%Proto.GetChildrenRequest{path: @path},
             {:ok, %Proto.GetChildrenResponse{children: @children}}}
        })

      assert ExZk.get_children(session, @path) == {:ok, @children}
    end

    test "it can get children with stat" do
      {:ok, session} =
        MockSession.start_link(%{
          get_children2:
            {%Proto.GetChildren2Request{path: @path},
             {:ok, %Proto.GetChildren2Response{children: @children, stat: @stat}}}
        })

      assert ExZk.get_children2(session, @path) == {:ok, @children, @stat}
    end

    test "it can get ephemerals" do
      {:ok, session} =
        MockSession.start_link(%{
          get_ephemerals:
            {%Proto.GetEphemeralsRequest{prefix_path: @path},
             {:ok, %Proto.GetEphemeralsResponse{ephemerals: @children}}}
        })

      assert ExZk.get_ephemerals(session, @path) == {:ok, @children}
    end

    test "it can get all children number" do
      {:ok, session} =
        MockSession.start_link(%{
          get_all_children_number:
            {%Proto.GetAllChildrenNumberRequest{path: @path},
             {:ok, %Proto.GetAllChildrenNumberResponse{total_number: 123}}}
        })

      assert ExZk.get_all_children_number(session, @path) == {:ok, 123}
    end

    test "it can get data" do
      {:ok, session} =
        MockSession.start_link(%{
          get_data:
            {%Proto.GetDataRequest{path: @path},
             {:ok, %Proto.GetDataResponse{data: @data, stat: @stat}}}
        })

      assert ExZk.get_data(session, @path) == {:ok, @data, @stat}
    end

    test "it can set data" do
      {:ok, session} =
        MockSession.start_link(%{
          set_data:
            {%Proto.SetDataRequest{path: @path, data: @data, version: @any_version},
             {:ok, %Proto.SetDataResponse{stat: @stat}}}
        })

      assert ExZk.set_data(session, @path, @data) == {:ok, @stat}
    end

    test "it can set data with version" do
      {:ok, session} =
        MockSession.start_link(%{
          set_data:
            {%Proto.SetDataRequest{path: @path, data: @data, version: @version},
             {:ok, %Proto.SetDataResponse{stat: @stat}}}
        })

      assert ExZk.set_data(session, @path, @data, @version) == {:ok, @stat}
    end

    test "it can create a node" do
      {:ok, session} =
        MockSession.start_link(%{
          create:
            {%Proto.CreateRequest{path: @path, data: @data, acl: default_acls()},
             {:ok, %Proto.CreateResponse{path: @path}}}
        })

      assert ExZk.create(session, @path, @data) == {:ok, @path, nil}
    end

    test "it can create a container" do
      {:ok, session} =
        MockSession.start_link(%{
          create_container:
            {%Proto.CreateRequest{
               path: @path,
               data: @data,
               acl: default_acls(),
               flags: Create.Mode.value!(:container)
             }, {:ok, %Proto.CreateResponse{path: @path}}}
        })

      assert ExZk.create(session, @path, @data, mode: :container) == {:ok, @path, nil}
    end

    test "it can create a node with TTL" do
      {:ok, session} =
        MockSession.start_link(%{
          create_ttl:
            {%Proto.CreateTTLRequest{
               path: @path,
               data: @data,
               acl: default_acls(),
               flags: Create.Mode.value!(:persistent_with_ttl),
               ttl: @ttl
             }, {:ok, %Proto.Create2Response{path: @path, stat: @stat}}}
        })

      assert ExZk.create(session, @path, @data, ttl: @ttl) ==
               {:ok, @path, @stat}
    end

    test "it can create a sequential node" do
      {:ok, session} =
        MockSession.start_link(%{
          create:
            {%Proto.CreateRequest{
               path: @path,
               data: @data,
               acl: default_acls(),
               flags: Create.Mode.value!(:persistent_sequential)
             }, {:ok, %Proto.CreateResponse{path: @path}}}
        })

      assert ExZk.create(session, @path, @data, mode: :persistent_sequential) == {:ok, @path, nil}
    end

    test "it can delete a node" do
      {:ok, session} =
        MockSession.start_link(%{
          delete: {%Proto.DeleteRequest{path: @path, version: @any_version}, :ok}
        })

      assert ExZk.delete(session, @path) == :ok
    end

    test "it can delete a node with version" do
      {:ok, session} =
        MockSession.start_link(%{
          delete: {%Proto.DeleteRequest{path: @path, version: @version}, :ok}
        })

      assert ExZk.delete(session, @path, @version) == :ok
    end

    test "it can delete a node recursively" do
      {:ok, session} =
        MockSession.start_link(%{
          get_data:
            {%Proto.GetDataRequest{path: @path},
             {:ok, %Proto.GetDataResponse{data: @data, stat: @stat}}},
          get_children:
            Enum.concat(
              [
                {%Proto.GetChildrenRequest{path: @path},
                 {:ok, %Proto.GetChildrenResponse{children: @children}}}
              ],
              Stream.map(
                @children,
                &{%Proto.GetChildrenRequest{path: Path.join(@path, &1)},
                 {:ok, %Proto.GetChildrenResponse{children: []}}}
              )
            ),
          delete:
            Enum.concat(@children, [""])
            |> Enum.map(
              &{%Proto.DeleteRequest{path: Path.join(@path, &1), version: @any_version}, :ok}
            )
        })

      assert ExZk.delete_recursive(session, @path, 0) == :ok
    end

    test "it can delete a node recursively in batch" do
      {:ok, session} =
        MockSession.start_link(%{
          get_data:
            {%Proto.GetDataRequest{path: @path},
             {:ok, %Proto.GetDataResponse{data: @data, stat: @stat}}},
          get_children:
            Enum.concat(
              [
                {%Proto.GetChildrenRequest{path: @path},
                 {:ok, %Proto.GetChildrenResponse{children: @children}}}
              ],
              Stream.map(
                @children,
                &{%Proto.GetChildrenRequest{path: Path.join(@path, &1)},
                 {:ok, %Proto.GetChildrenResponse{children: []}}}
              )
            ),
          multi:
            {Multi.to_request(
               Enum.concat(@children, [""])
               |> Enum.map(&Multi.Op.delete(Path.join(@path, &1)))
             ),
             {:ok,
              %Multi.Response{
                results: Enum.concat(@children, [""]) |> Enum.map(fn _ -> {:delete, :ok} end)
              }}}
        })

      assert ExZk.delete_recursive(session, @path) == :ok
    end

    test "it can check a node is exists" do
      {:ok, session} =
        MockSession.start_link(%{
          exists: {%Proto.ExistsRequest{path: @path}, {:ok, %Proto.ExistsResponse{stat: @stat}}}
        })

      assert ExZk.exists(session, @path) == {:ok, true, @stat}
    end

    test "it can check a node is not exists" do
      {:ok, session} =
        MockSession.start_link(%{
          exists: {%Proto.ExistsRequest{path: @path}, {:error, :no_node}}
        })

      assert ExZk.exists(session, @path) == {:ok, false, nil}
    end

    test "it can get ACL of a node" do
      {:ok, session} =
        MockSession.start_link(%{
          get_acl:
            {%Proto.GetACLRequest{path: @path},
             {:ok, %Proto.GetACLResponse{acl: @acls, stat: @stat}}}
        })

      assert ExZk.get_acl(session, @path) == {:ok, @acls, @stat}
    end

    test "it can set ACL of a node" do
      {:ok, session} =
        MockSession.start_link(%{
          set_acl:
            {%Proto.SetACLRequest{path: @path, acl: @acls, version: @any_version},
             {:ok, %Proto.SetACLResponse{stat: @stat}}}
        })

      assert ExZk.set_acl(session, @path, @acls) == {:ok, @stat}
    end

    test "it can set ACL of a node with version" do
      {:ok, session} =
        MockSession.start_link(%{
          set_acl:
            {%Proto.SetACLRequest{path: @path, acl: @acls, version: @version},
             {:ok, %Proto.SetACLResponse{stat: @stat}}}
        })

      assert ExZk.set_acl(session, @path, @acls, @version) == {:ok, @stat}
    end

    test "it can sync a node" do
      {:ok, session} =
        MockSession.start_link(%{
          sync: {%Proto.SyncRequest{path: @path}, {:ok, %Proto.SyncResponse{path: @path}}}
        })

      assert ExZk.sync(session, @path) == {:ok, @path}
    end

    test "it can check whoami" do
      {:ok, session} =
        MockSession.start_link(%{
          who_am_i: {nil, {:ok, %Proto.WhoAmIResponse{client_info: @client_info}}}
        })

      assert ExZk.whoami(session) == {:ok, @client_info}
    end

    test "it can send multi ops" do
      {:ok, session} =
        MockSession.start_link(%{
          multi: {Multi.to_request(@multi_ops), {:ok, %Multi.Response{results: @multi_results}}}
        })

      assert ExZk.multi(session, @multi_ops) == {:ok, @multi_results}
    end
  end
end
