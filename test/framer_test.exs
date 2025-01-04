defmodule FramerTest do
  use ExUnit.Case, async: true

  use ExZk.Defs

  import ExZk.Wire

  alias ExZk.Proto.{
    CreateRequest,
    CreateResponse,
    DeleteRequest,
    ErrorResponse,
    ReplyHeader,
    RequestHeader
  }

  alias ExZk.Defs.ErrCode
  alias ExZk.{Frame, Framer}

  @path "/foobar"
  @data "hello world"
  @err ErrCode.value!(:bad_arguments)

  @create_request %CreateRequest{path: @path, data: @data}
  @create_response %CreateResponse{path: @path}
  @error_response %ErrorResponse{err: @err}
  @delete_request %DeleteRequest{path: @path}
  @ping_response %ReplyHeader{xid: @ping_xid}

  describe "Given a Framer" do
    test "it can create new frame with request" do
      f = %Framer{}

      assert {:ok, %Frame{request: @create_request}, f1} =
               Framer.new_frame(f, :create_container, @create_request)

      assert f1.next_xid == f.next_xid + 1
      assert map_size(f1.requests) == 1
    end

    test "it can parse frame with response for request" do
      f = %Framer{}

      assert {:ok, %Frame{req_hdr: %RequestHeader{xid: xid}, request: @create_request},
              %Framer{} = f1} =
               Framer.new_frame(f, :create_container, @create_request)

      assert {:ok, %Frame{request: @create_request, response: @create_response}, _sender,
              %Framer{} = f2} =
               Framer.parse_frame(f1, pack([%ReplyHeader{xid: xid}, @create_response]))

      assert f2.next_xid == f1.next_xid
      assert map_size(f2.requests) == 0
    end

    test "it can parse frame with error for request" do
      f = %Framer{}

      assert {:ok, %Frame{req_hdr: %RequestHeader{xid: xid}, request: @create_request},
              %Framer{} = f1} =
               Framer.new_frame(f, :create_container, @create_request)

      assert {:ok, %Frame{request: @create_request, response: @error_response}, _sender,
              %Framer{} = f2} =
               Framer.parse_frame(f1, pack([%ReplyHeader{xid: xid, err: @err}]))

      assert f2.next_xid == f1.next_xid
      assert map_size(f2.requests) == 0
    end

    test "it can parse frame without response for request" do
      f = %Framer{}

      assert {:ok, %Frame{req_hdr: %RequestHeader{xid: xid}, request: @delete_request},
              %Framer{} = f1} =
               Framer.new_frame(f, :delete, @delete_request)

      assert {:ok, %Frame{response: nil}, _sender, %Framer{} = f2} =
               Framer.parse_frame(f1, pack([%ReplyHeader{xid: xid}]))

      assert f2.next_xid == f1.next_xid
      assert map_size(f2.requests) == 0
    end

    test "it can parse ping response" do
      f = %Framer{}

      assert Framer.parse_frame(f, pack(@ping_response)) ==
               {:ok, %Frame{reply_hdr: @ping_response, response: :pong, payload: ""}, nil, f}
    end

    test "it can handle unexpected xid" do
      assert Framer.parse_frame(%Framer{}, pack([%ReplyHeader{xid: 123}, @create_response])) ==
               {:error, {:unexpected_xid, 123}}

      assert Framer.parse_frame(
               %Framer{},
               pack([%ReplyHeader{xid: 123, err: @err}, @create_response])
             ) ==
               {:error, {:unexpected_xid, 123}}
    end

    test "it can handle unexpected opcode" do
      f = %Framer{}

      assert {:ok, %Frame{req_hdr: %RequestHeader{xid: xid}, request: @create_request},
              %Framer{} = f1} =
               Framer.new_frame(f, :close_session, @create_request)

      assert Framer.parse_frame(f1, pack([%ReplyHeader{xid: xid}, @create_response])) ==
               {:error, {:unexpected_opcode, :close_session}}
    end
  end
end
