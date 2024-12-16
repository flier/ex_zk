defmodule SocketTest do
  use ExUnit.Case, async: false

  import Mock

  import ExZk.Wire
  alias ExZk.{Connector, Frame, Socket}
  alias ExZk.Proto.{ConnectResponse, ReplyHeader}

  @connect_response %ConnectResponse{
    time_out: 15_000,
    session_id: 123
  }

  @connected %Connector.Connected{
    addr: :addr,
    session_timeout: @connect_response.time_out,
    session_id: @connect_response.session_id,
    passwd: "",
    readonly: false
  }

  setup_with_mocks([
    {Connector, [], [connect: fn _pid, _opts -> {:ok, :sock, @connected} end]},
    {:inet, [:unstick], [setopts: fn _sock, _opts -> :ok end]},
    {:ssl, [], [setopts: fn _sock, _opts -> :ok end]}
  ]) do
    :ok
  end

  describe "Given a ExZk.Socket" do
    test "it can be connected with TCP" do
      Process.flag(:trap_exit, true)

      {:ok, sock} = Socket.start_link(self(), [])
      assert is_pid(sock)

      assert_receive {:connected, ^sock, :sock, @connected}
      assert_called(Connector.connect(self(), []))
      assert_called(:inet.setopts(:sock, active: :once))

      Socket.normal_stop(sock)
      assert_receive {:EXIT, ^sock, :normal}
    end

    test "it can be connected with SSL" do
      Process.flag(:trap_exit, true)

      {:ok, sock} = Socket.start_link(self(), ssl: true)
      assert is_pid(sock)

      assert_receive {:connected, ^sock, :sock, @connected}
      assert_called(Connector.connect(self(), ssl: true))
      assert_called(:ssl.setopts(:sock, active: :once))

      Socket.normal_stop(sock)
      assert_receive {:EXIT, ^sock, :normal}
    end

    test_with_mock "it may be stopped when Connector.connect return {:stop, _}",
                   Connector,
                   [],
                   connect: fn _pid, _opts -> {:stop, :reason} end do
      Process.flag(:trap_exit, true)

      {:ok, sock} = Socket.start_link(self(), [])
      assert is_pid(sock)

      assert_receive {:stopped, ^sock, :reason}
      assert_called(Connector.connect(self(), []))

      assert_receive {:EXIT, ^sock, :normal}
    end

    test_with_mock "it may be failed when Connector.setopts return {:error, _}",
                   :ssl,
                   [],
                   setopts: fn _sock, _opts -> {:error, :reason} end do
      Process.flag(:trap_exit, true)

      {:ok, sock} = Socket.start_link(self(), ssl: true)
      assert is_pid(sock)

      assert_receive {:stopped, ^sock, :reason}
      assert_called(Connector.connect(self(), ssl: true))
      assert_called(:ssl.setopts(:sock, active: :once))

      assert_receive {:EXIT, ^sock, :normal}
    end

    test "it can receive frame" do
      {:ok, sock} = Socket.start_link(self(), [])
      assert is_pid(sock)

      assert_receive {:connected, ^sock, :sock, @connected}

      reply_hdr = %ReplyHeader{xid: 123, zxid: 456, err: 789}
      buf = pack(reply_hdr)
      frame = <<byte_size(buf)::32>> <> buf

      # receive frame
      send(sock, {:tcp, :sock, frame})
      assert_receive {:frame, ^sock, %Frame{reply_hdr: ^reply_hdr, payload: ""}}
    end
  end
end
