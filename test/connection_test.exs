defmodule ConnectionTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mock

  alias ExZk.{Connection, Connector, ConnectionError}
  alias ExZk.Proto.{ReplyHeader, WatcherEvent}

  setup_with_mocks([
    {:inet, [:no_link, :unstick], [setopts: fn _sock, _opts -> :ok end]},
    {:ssl, [:no_link], [setopts: fn _sock, _opts -> :ok end]},
    {Connector, [], [connect: fn _pid, _opts -> {:ok, :sock, :addr} end]}
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
               send(conn, {:frame, socket, ReplyHeader.pack(%ReplyHeader{xid: @ping_xid})})

               assert {:connected, %{socket: ^socket, addr: :addr}} = Connection.status(conn)
             end) == "Got ping response for session id - after PT0S"
    end

    test "it can handle auth packet response" do
      # connect to the server
      {:ok, conn} = Connection.start_link(sync_connect: true)

      # it should be connected
      assert {:connected, %{socket: socket, addr: :addr}} = Connection.status(conn)

      assert capture_log([level: :debug, format: "$message"], fn ->
               send(
                 conn,
                 {:frame, socket, ReplyHeader.pack(%ReplyHeader{xid: @auth_packet_xid, err: -1})}
               )

               assert {:connected, %{socket: ^socket, addr: :addr}} = Connection.status(conn)
             end) == "Got auth response for session id - with err: -1"
    end

    test "it can handle notification" do
      # connect to the server
      {:ok, conn} = Connection.start_link(sync_connect: true)

      # it should be connected
      assert {:connected, %{socket: socket, addr: :addr}} = Connection.status(conn)

      frame =
        ReplyHeader.pack(%ReplyHeader{xid: @notification_xid, zxid: 123}) <>
          WatcherEvent.pack(%WatcherEvent{type: 1, state: 3, path: "/test"})

      assert capture_log([level: :debug, format: "$message"], fn ->
               send(conn, {:frame, socket, frame})

               assert {:connected, %{socket: ^socket, addr: :addr}} = Connection.status(conn)
             end) ==
               ~s[Got notification for session id - with event: #{%ExZk.Connection.WatchedEvent{type: 1, state: 3, path: "/test", zxid: 123} |> inspect()}]
    end
  end
end
