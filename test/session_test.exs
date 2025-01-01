defmodule ConnectionTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mock

  import ExZk.Wire

  alias ExZk.{Connector, Frame, Session}
  alias ExZk.Defs.OpCode
  alias ExZk.Proto.{ReplyHeader, RequestHeader, WatcherEvent}
  alias ExZk.WatchedEvent
  alias ExZk.Watcher.Event

  @close_session Frame.new_close_session()

  setup_with_mocks([
    {:inet, [:no_link, :unstick, :passthrough], [setopts: fn _sock, _opts -> :ok end]},
    {:gen_tcp, [:unstick], [send: fn :sock, _data -> :ok end]},
    {:ssl, [:no_link], [setopts: fn _sock, _opts -> :ok end]},
    {Connector, [],
     [connect: fn _pid, _opts -> {:ok, :sock, %Connector.Connected{addr: :addr}} end]}
  ]) do
    :ok
  end

  describe "Given a Session" do
    test "it can be connected" do
      Process.flag(:trap_exit, true)

      # connect to the server
      {:ok, session} = Session.start_link(exit_on_disconnection: true)

      # it should be connected
      Process.sleep(100)
      assert {:connected, %{addr: :addr}} = Session.status(session)

      assert_called_exactly(Connector.connect(session, exit_on_disconnection: true), 1)

      # stop the session
      Session.close(session)

      assert_called_exactly(:gen_tcp.send(:sock, pack(@close_session)), 1)

      # it should be terminated
      Process.sleep(100)
      assert !Process.alive?(session)

      # the EXIT signal should be received
      assert_received {:EXIT, ^session, :normal}
    end

    test "it should be reconnect when connect failed" do
      with_mocks([
        {Connector, [], [connect: fn _pid, _opts -> {:error, :foobar} end]}
      ]) do
        Process.flag(:trap_exit, true)

        # connect to the server
        {:ok, session} = Session.start_link(backoff_initial: 10, backoff_max: 50)

        # it should be connected
        Process.sleep(100)

        assert Session.status(session) ==
                 {:disconnected, %{backoff_current: 50, reconnect_times: 5}}

        assert_called_exactly(
          Connector.connect(session, backoff_initial: 10, backoff_max: 50),
          5
        )
      end
    end

    test "it can be sync connected" do
      # connect to the server
      {:ok, session} = Session.start_link(sync_connect: true)

      # it should be connected
      assert {:connected, %{addr: :addr}} = Session.status(session)

      assert_called_exactly(
        Connector.connect(session, sync_connect: true),
        1
      )
    end

    test "sync connect will not retry" do
      with_mocks([
        {Connector, [:no_link], [connect: fn _pid, _opts -> {:error, :foobar} end]}
      ]) do
        Process.flag(:trap_exit, true)

        # connect to the server
        assert Session.start_link(sync_connect: true) ==
                 {:error, %Session.Error{reason: :foobar}}

        assert_called_exactly(
          Connector.connect(:_, sync_connect: true),
          1
        )
      end
    end

    @notification_xid -1
    @ping_xid -2
    @auth_packet_xid -4

    test "it can handle ping response" do
      # connect to the server
      {:ok, session} = Session.start_link(sync_connect: true)

      # it should be connected
      assert {:connected, %{socket: socket, addr: :addr}} = Session.status(session)

      assert capture_log([level: :debug, format: "$message"], fn ->
               frame = Frame.unpack(pack(%ReplyHeader{xid: @ping_xid}))

               send(session, {:frame, socket, frame})

               assert {:connected, %{socket: ^socket, addr: :addr}} = Session.status(session)
             end) == "[session: [pid: #{inspect(session)}, id: nil], ping: [latency: \"PT0S\"]]"
    end

    test "it can handle auth packet response" do
      # connect to the server
      {:ok, session} = Session.start_link(sync_connect: true)

      # it should be connected
      assert {:connected, %{socket: socket, addr: :addr}} = Session.status(session)

      frame = Frame.unpack(pack(%ReplyHeader{xid: @auth_packet_xid, err: -1}))

      assert capture_log([level: :debug, format: "$message"], fn ->
               send(session, {:frame, socket, frame})

               assert {:connected, %{socket: ^socket, addr: :addr}} = Session.status(session)
             end) ==
               "[session: [pid: #{inspect(session)}, id: nil], auth: [error: {:ok, :system_error}]]"
    end

    test "it can handle notification" do
      # connect to the server
      {:ok, session} = Session.start_link(sync_connect: true)

      # it should be connected
      assert {:connected, %{socket: socket, addr: :addr}} = Session.status(session)

      frame =
        Frame.unpack(
          pack(%ReplyHeader{xid: @notification_xid, zxid: 123}) <>
            pack(%WatcherEvent{
              type: Event.Type.value!(:node_data_changed),
              state: Event.KeeperState.value!(:sync_connected),
              path: "/test"
            })
        )

      evt = %WatchedEvent{
        type: :node_data_changed,
        state: :sync_connected,
        path: "/test",
        zxid: 123
      }

      assert capture_log([level: :debug, format: "$message"], fn ->
               send(session, {:frame, socket, frame})

               assert {:connected, %{socket: ^socket, addr: :addr}} = Session.status(session)
             end) ==
               "[session: [pid: #{inspect(session)}, id: nil], notification: #{inspect(evt)}]"
    end

    test "it can handle unknown build-in frame" do
      # connect to the server
      {:ok, session} = Session.start_link(sync_connect: true)

      # it should be connected
      assert {:connected, %{socket: socket, addr: :addr}} = Session.status(session)

      xid = -123
      frame = Frame.unpack(pack(%ReplyHeader{xid: xid}))

      assert capture_log([level: :debug, format: "$message"], fn ->
               send(session, {:frame, socket, frame})

               assert {:connected, %{socket: ^socket, addr: :addr}} = Session.status(session)
             end) == "Got unknown reply for session id - with with xid: #{xid}"
    end

    test "it can send ping" do
      with_mocks([
        {:gen_tcp, [:unstick], [send: fn _socket, _data -> :ok end]}
      ]) do
        # connect to the server
        {:ok, session} = Session.start_link(sync_connect: true)

        assert :gen_statem.cast(session, :send_ping) == :ok

        assert {:connected, %{socket: socket}} = Session.status(session)

        frame = pack(%RequestHeader{xid: @ping_xid, type: OpCode.value!(:ping)})

        assert_called(:gen_tcp.send(:sock, <<byte_size(frame)::32>> <> frame))

        frame = Frame.unpack(pack(%ReplyHeader{xid: @ping_xid}))

        assert String.starts_with?(
                 capture_log([level: :debug, format: "$message"], fn ->
                   send(session, {:frame, socket, frame})

                   assert {:connected, %{socket: ^socket, addr: :addr}} = Session.status(session)
                 end),
                 "[session: [pid: #{inspect(session)}, id: nil], ping: [latency: \"PT0."
               )
      end
    end
  end
end
