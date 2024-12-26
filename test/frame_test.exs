defmodule FrameTest do
  use ExUnit.Case, async: true

  import ExZk.Wire

  alias ExZk.Defs.OpCode
  alias ExZk.WatchedEvent
  alias ExZk.Watcher.Event

  alias ExZk.Proto.{
    AuthPacket,
    ReplyHeader,
    RequestHeader,
    SetWatches,
    SetWatches2,
    WatcherEvent
  }

  alias ExZk.Frame

  @notification_xid -1
  @ping_xid -2
  @auth_packet_xid -4
  @set_watches_xid -8

  @path "/foo/bar"

  describe "it can create a build-in frame with" do
    test "a ping request" do
      assert Frame.new_ping_request() == %Frame{
               req_hdr: %RequestHeader{xid: @ping_xid, type: OpCode.value!(:ping)}
             }
    end

    test "an auth packet" do
      assert Frame.new_auth_packet("foo", "bar") == %Frame{
               req_hdr: %RequestHeader{xid: @auth_packet_xid, type: OpCode.value!(:auth)},
               request: %AuthPacket{scheme: "foo", auth: "bar"}
             }
    end

    test "a set watches request" do
      assert Frame.new_set_watches_request(123, [@path], [@path], [@path]) == %Frame{
               req_hdr: %RequestHeader{xid: @set_watches_xid, type: OpCode.value!(:set_watches)},
               request: %SetWatches{
                 relative_zxid: 123,
                 data_watches: [@path],
                 exist_watches: [@path],
                 child_watches: [@path]
               }
             }
    end

    test "a set watches 2 request" do
      assert Frame.new_set_watches2_request(456, [@path], [@path], [@path], [@path], [@path]) ==
               %Frame{
                 req_hdr: %RequestHeader{
                   xid: @set_watches_xid,
                   type: OpCode.value!(:set_watches2)
                 },
                 request: %SetWatches2{
                   relative_zxid: 456,
                   data_watches: [@path],
                   exist_watches: [@path],
                   child_watches: [@path],
                   persistent_watches: [@path],
                   persistent_recursive_watches: [@path]
                 }
               }
    end
  end

  describe "it unpack a frame" do
    @ping_reply %ReplyHeader{xid: @ping_xid}

    test "with ping response" do
      assert Frame.unpack(pack(@ping_reply)) == %Frame{
               reply_hdr: @ping_reply,
               response: :pong,
               payload: ""
             }
    end

    @auth_packet_reply %ReplyHeader{xid: @auth_packet_xid, err: -123}

    test "with auth fail" do
      assert Frame.unpack(pack(@auth_packet_reply)) == %Frame{
               reply_hdr: @auth_packet_reply,
               response: {:auth_failed, -123},
               payload: ""
             }
    end

    @notification_reply %ReplyHeader{xid: @notification_xid, zxid: 123}

    test "with notification" do
      assert Frame.unpack(
               pack([
                 @notification_reply,
                 %WatcherEvent{
                   type: Event.Type.value!(:node_created),
                   state: Event.KeeperState.value!(:sync_connected),
                   path: @path
                 }
               ])
             ) ==
               %Frame{
                 reply_hdr: @notification_reply,
                 response:
                   {:notification,
                    %WatchedEvent{
                      path: "/foo/bar",
                      state: :sync_connected,
                      type: :node_created,
                      zxid: 123
                    }},
                 payload: ""
               }
    end
  end
end
