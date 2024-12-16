defmodule ConnectionTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mock

  import ExZk.Wire
  alias ExZk.Proto.ConnectResponse
  alias ExZk.Defs.OpCode
  alias ExZk.Frame
  alias ExZk.{Connection, Connector, ConnectionError}
  alias ExZk.Proto.{ReplyHeader, RequestHeader, WatcherEvent}

  setup_with_mocks([
    {:inet, [:no_link, :unstick, :passthrough], [setopts: fn _sock, _opts -> :ok end]},
    {:ssl, [:no_link], [setopts: fn _sock, _opts -> :ok end]},
    {Connector, [], [connect: fn _pid, _opts -> {:ok, :sock, :addr, %ConnectResponse{}} end]}
  ]) do
    :ok
  end

  describe "Given a Connection" do
    test "it can be connected" do
      Process.flag(:trap_exit, true)

      # connect to the server
      {:ok, conn} = Connection.start_link(exit_on_disconnection: true)

      # it should be connected
      Process.sleep(100)
      assert {:connected, %{addr: :addr}} = Connection.status(conn)

      assert_called_exactly(Connector.connect(conn, exit_on_disconnection: true), 1)

      # stop the connection
      Connection.stop(conn)

      # it should be terminated
      Process.sleep(100)
      assert !Process.alive?(conn)

      # the EXIT signal should be received
      assert_received {:EXIT, ^conn, :normal}
    end

    test "it should be reconnect when connect failed" do
      with_mocks([
        {Connector, [], [connect: fn _pid, _opts -> {:error, :foobar} end]}
      ]) do
        Process.flag(:trap_exit, true)

        # connect to the server
        {:ok, conn} = Connection.start_link(backoff_initial: 10, backoff_max: 50)

        # it should be connected
        Process.sleep(100)

        assert Connection.status(conn) ==
                 {:disconnected, %{backoff_current: 50, reconnect_times: 5}}

        assert_called_exactly(
          Connector.connect(conn, backoff_initial: 10, backoff_max: 50),
          5
        )
      end
    end

    test "it can be sync connected" do
      # connect to the server
      {:ok, conn} = Connection.start_link(sync_connect: true)

      # it should be connected
      assert {:connected, %{addr: :addr}} = Connection.status(conn)

      assert_called_exactly(
        Connector.connect(conn, sync_connect: true),
        1
      )
    end

    test "sync connect will not retry" do
      with_mocks([
        {Connector, [:no_link], [connect: fn _pid, _opts -> {:error, :foobar} end]}
      ]) do
        Process.flag(:trap_exit, true)

        # connect to the server
        assert Connection.start_link(sync_connect: true) ==
                 {:error, %ConnectionError{reason: :foobar}}

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
      {:ok, conn} = Connection.start_link(sync_connect: true)

      # it should be connected
      assert {:connected, %{socket: socket, addr: :addr}} = Connection.status(conn)

      assert capture_log([level: :debug, format: "$message"], fn ->
               frame = Frame.unpack(pack(%ReplyHeader{xid: @ping_xid}))

               send(conn, {:frame, socket, frame})

               assert {:connected, %{socket: ^socket, addr: :addr}} = Connection.status(conn)
             end) == "Got ping response for session id - after PT0S"
    end

    test "it can handle auth packet response" do
      # connect to the server
      {:ok, conn} = Connection.start_link(sync_connect: true)

      # it should be connected
      assert {:connected, %{socket: socket, addr: :addr}} = Connection.status(conn)

      assert capture_log([level: :debug, format: "$message"], fn ->
               frame = Frame.unpack(pack(%ReplyHeader{xid: @auth_packet_xid, err: -1}))

               send(conn, {:frame, socket, frame})

               assert {:connected, %{socket: ^socket, addr: :addr}} = Connection.status(conn)
             end) == "Got auth response for session id - with err: -1"
    end

    test "it can handle notification" do
      # connect to the server
      {:ok, conn} = Connection.start_link(sync_connect: true)

      # it should be connected
      assert {:connected, %{socket: socket, addr: :addr}} = Connection.status(conn)

      assert capture_log([level: :debug, format: "$message"], fn ->
               frame =
                 Frame.unpack(
                   pack(%ReplyHeader{xid: @notification_xid, zxid: 123}) <>
                     pack(%WatcherEvent{type: 1, state: 2, path: "/test"})
                 )

               send(conn, {:frame, socket, frame})

               assert {:connected, %{socket: ^socket, addr: :addr}} = Connection.status(conn)
             end) ==
               ~s[Got notification for session id - with event: #{%ExZk.WatchedEvent{type: :node_created, state: :sync_connected, path: "/test", zxid: 123} |> inspect()}]
    end

    test "it can send ping" do
      with_mocks([
        {:gen_tcp, [:unstick], [send: fn _socket, _data -> :ok end]}
      ]) do
        # connect to the server
        {:ok, conn} = Connection.start_link(sync_connect: true)

        assert :gen_statem.cast(conn, :ping) == :ok

        assert {:connected, %{socket: socket}} = Connection.status(conn)

        frame = pack(%RequestHeader{xid: @ping_xid, type: OpCode.value!(:ping)})

        assert_called(:gen_tcp.send(:sock, <<byte_size(frame)::32>> <> frame))

        assert String.starts_with?(
                 capture_log([level: :debug, format: "$message"], fn ->
                   frame = Frame.unpack(pack(%ReplyHeader{xid: @ping_xid}))

                   send(conn, {:frame, socket, frame})

                   assert {:connected, %{socket: ^socket, addr: :addr}} = Connection.status(conn)
                 end),
                 "Got ping response for session id - after PT"
               )
      end
    end
  end
end
