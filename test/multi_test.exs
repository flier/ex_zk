defmodule MultiTest do
  use ExUnit.Case, async: true

  import ExZk.Defs.Ids
  import ExZk.Multi.Op

  alias ExZk.Data.Stat
  alias ExZk.Defs.{ErrCode, OpCode}
  alias ExZk.Multi
  alias ExZk.Multi.{Response, Result}
  alias ExZk.Wire

  alias ExZk.Proto.{
    Create2Response,
    CreateRequest,
    CreateResponse,
    DeleteRequest,
    ErrorResponse,
    GetChildrenRequest,
    GetChildrenResponse,
    GetDataRequest,
    GetDataResponse,
    MultiHeader,
    SetDataRequest,
    SetDataResponse
  }

  @path "/foo/bar"
  @data "hello world"
  @version 123
  @stat %Stat{version: @version, data_length: byte_size(@data)}
  @children ["a", "b", "c"]
  @any_version -1
  @err :system_error
  @err_code ErrCode.value!(@err)
  @done %MultiHeader{type: -1, done: true, err: -1}

  def to_multi_hdr(opcode), do: %MultiHeader{type: OpCode.value!(opcode), done: false, err: -1}

  describe "given a multi op" do
    test "it can be construct" do
      assert create(@path, @data, acl: [open_acl()]) ==
               {:create, @path, @data, [acl: [open_acl()]]}

      assert create(@path, @data) == {:create, @path, @data, []}
      assert create(@path, acl: [open_acl()]) == {:create, @path, "", [acl: [open_acl()]]}

      assert create(@path) == {:create, @path, "", []}

      assert check(@path, @version) == {:check, @path, @version}

      assert delete(@path, @version) == {:delete, @path, @version}
      assert delete(@path) == {:delete, @path, @any_version}

      assert get_children(@path) == {:get_children, @path}

      assert get_data(@path) == {:get_data, @path}

      assert set_data(@path, @data, @version) == {:set_data, @path, @data, @version}
      assert set_data(@path, @data) == {:set_data, @path, @data, @any_version}
    end

    test "it can be converted to a request" do
      assert create(@path) |> to_request() == {:create, %CreateRequest{path: @path}}

      assert create(@path, @data) |> to_request() ==
               {:create, %CreateRequest{path: @path, data: @data}}

      assert create(@path, @data, acl: [open_acl()]) |> to_request() ==
               {:create, %CreateRequest{path: @path, data: @data, acl: [open_acl()]}}

      assert create(@path, acl: [open_acl()]) |> to_request() ==
               {:create, %CreateRequest{path: @path, acl: [open_acl()]}}

      assert delete(@path, @version) |> to_request() ==
               {:delete, %DeleteRequest{path: @path, version: @version}}

      assert delete(@path) |> to_request() ==
               {:delete, %DeleteRequest{path: @path, version: @any_version}}

      assert get_children(@path) |> to_request() ==
               {:get_children, %GetChildrenRequest{path: @path}}

      assert get_data(@path) |> to_request() == {:get_data, %GetDataRequest{path: @path}}

      assert set_data(@path, @data, @version) |> to_request() ==
               {:set_data, %SetDataRequest{path: @path, data: @data, version: @version}}

      assert set_data(@path, @data) |> to_request() ==
               {:set_data, %SetDataRequest{path: @path, data: @data, version: @any_version}}
    end
  end

  describe "given a multi op result" do
    test "it can be unpacked" do
      assert Result.unpack(:create, Wire.pack(%CreateResponse{path: @path}) <> @data) ==
               {:ok, {:create, @path, nil}, @data}

      assert Result.unpack(
               :create2,
               Wire.pack(%Create2Response{path: @path, stat: @stat}) <> @data
             ) == {:ok, {:create, @path, @stat}, @data}

      assert Result.unpack(:delete, @data) == {:ok, {:delete, :ok}, @data}

      assert Result.unpack(:set_data, Wire.pack(%SetDataResponse{stat: @stat}) <> @data) ==
               {:ok, {:set_data, @stat}, @data}

      assert Result.unpack(:check, @data) == {:ok, {:check, :ok}, @data}

      assert Result.unpack(
               :get_children,
               Wire.pack(%GetChildrenResponse{children: @children}) <> @data
             ) ==
               {:ok, {:get_children, @children}, @data}

      assert Result.unpack(
               :get_data,
               Wire.pack(%GetDataResponse{data: @data, stat: @stat}) <> @data
             ) ==
               {:ok, {:get_data, @data, @stat}, @data}

      assert Result.unpack(:error, Wire.pack(%ErrorResponse{err: @err_code}) <> @data) ==
               {:ok, {:error, @err}, @data}

      assert Result.unpack(:create, "") == {:error, :nomatch}
      assert Result.unpack(:create, @data) == {:error, :nomatch}
    end
  end

  describe "given some multi ops" do
    test "it can be converted to a request" do
      assert [] |> Multi.to_request() == [@done]

      assert [create(@path, @data)] |> Multi.to_request() == [
               :create |> to_multi_hdr(),
               %CreateRequest{path: @path, data: @data},
               @done
             ]

      assert [delete(@path)] |> Multi.to_request() == [
               :delete |> to_multi_hdr(),
               %DeleteRequest{path: @path, version: @any_version},
               @done
             ]

      assert [get_children(@path)] |> Multi.to_request() == [
               :get_children |> to_multi_hdr(),
               %GetChildrenRequest{path: @path},
               @done
             ]

      assert [get_data(@path)] |> Multi.to_request() == [
               :get_data |> to_multi_hdr(),
               %GetDataRequest{path: @path},
               @done
             ]

      assert [set_data(@path, @data)] |> Multi.to_request() == [
               :set_data |> to_multi_hdr(),
               %SetDataRequest{path: @path, data: @data, version: @any_version},
               @done
             ]

      assert [
               create(@path, @data),
               delete(@path),
               get_children(@path),
               get_data(@path),
               set_data(@path, @data)
             ]
             |> Multi.to_request() == [
               :create |> to_multi_hdr(),
               %CreateRequest{path: @path, data: @data},
               :delete |> to_multi_hdr(),
               %DeleteRequest{path: @path, version: @any_version},
               :get_children |> to_multi_hdr(),
               %GetChildrenRequest{path: @path},
               :get_data |> to_multi_hdr(),
               %GetDataRequest{path: @path},
               :set_data |> to_multi_hdr(),
               %SetDataRequest{path: @path, data: @data, version: @any_version},
               @done
             ]
    end
  end

  describe "given a multi op response" do
    test "it can be unpacked" do
      assert @done |> Wire.pack() |> Response.unpack() == {:ok, %Response{}, ""}

      assert [
               :create |> to_multi_hdr(),
               %CreateResponse{path: @path},
               :create2 |> to_multi_hdr(),
               %Create2Response{path: @path, stat: @stat},
               :delete |> to_multi_hdr(),
               :set_data |> to_multi_hdr(),
               %SetDataResponse{stat: @stat},
               :get_children |> to_multi_hdr(),
               %GetChildrenResponse{children: @children},
               :get_data |> to_multi_hdr(),
               %GetDataResponse{data: @data, stat: @stat},
               :error |> to_multi_hdr(),
               %ErrorResponse{err: @err_code},
               @done
             ]
             |> Wire.pack()
             |> Response.unpack() ==
               {:ok,
                %Response{
                  results: [
                    {:create, @path, nil},
                    {:create, @path, @stat},
                    {:delete, :ok},
                    {:set_data, @stat},
                    {:get_children, @children},
                    {:get_data, @data, @stat},
                    {:error, @err}
                  ]
                }, ""}

      assert [:auth |> to_multi_hdr(), @done] |> Wire.pack() |> Response.unpack() ==
               {:error, {:unexpected_opcode, :auth}}

      assert [%MultiHeader{type: 123, done: false, err: -1}, @done]
             |> Wire.pack()
             |> Response.unpack() ==
               {:error, {:unexpected_opcode, 123}}

      assert [:create |> to_multi_hdr(), @done] |> Wire.pack() |> Response.unpack() ==
               {:error, :nomatch}
    end
  end
end
