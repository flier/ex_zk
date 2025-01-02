defmodule ExZkTest do
  use ExUnit.Case, async: true

  alias ExZk.Create
  alias ExZk.Data.Stat
  alias ExZk.Proto

  @path "/foo/bar"
  @data "hello world"
  @children ["a", "b", "c"]
  @stat %Stat{}
  @version 123
  @any_version -1
  @ttl 60

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

    def connected({:call, from}, {:send_request, opcode, request}, data) do
      assert {^request, response} = data[opcode],
             "request: #{inspect(request)}, data: #{inspect(data)}"

      {:keep_state_and_data, {:reply, from, response}}
    end
  end

  describe "given a mock session" do
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
            {%Proto.CreateRequest{path: @path, data: @data},
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
  end
end
