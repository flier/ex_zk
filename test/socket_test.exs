defmodule SocketTest do
  use ExUnit.Case, async: false

  import Mock

  import ExZk.Wire

  alias ExZk.Proto.{ConnectResponse, ReplyHeader}
  alias ExZk.{Connector, Frame, Socket}

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

      assert_receive {:connected, ^sock, @connected}
      assert_called(Connector.connect(self(), []))
      assert_called(:inet.setopts(:sock, active: :once))

      Socket.normal_stop(sock)
      assert_receive {:EXIT, ^sock, :normal}
    end

    test "it can be connected with SSL" do
      Process.flag(:trap_exit, true)

      {:ok, sock} = Socket.start_link(self(), ssl: true)
      assert is_pid(sock)

      assert_receive {:connected, ^sock, @connected}
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

      assert_receive {:disconnected, ^sock, %Socket.Error{reason: :reason}}
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

      assert_receive {:disconnected, ^sock, %Socket.Error{reason: :reason}}
      assert_called(Connector.connect(self(), ssl: true))
      assert_called(:ssl.setopts(:sock, active: :once))

      assert_receive {:EXIT, ^sock, :normal}
    end

    test "it will be stopped when received :tcp_closed" do
      {:ok, sock} = Socket.start_link(self(), [])

      send(sock, {:tcp_closed, :sock})

      assert_receive {:connected, ^sock, @connected}
      assert_receive {:disconnected, ^sock, %Socket.Error{reason: :tcp_closed}}
    end

    test "it will be stopped when received :tcp_error" do
      {:ok, sock} = Socket.start_link(self(), [])

      send(sock, {:tcp_error, :sock, :reason})

      assert_receive {:connected, ^sock, @connected}
      assert_receive {:disconnected, ^sock, %Socket.Error{reason: :reason}}
    end

    test "it will be stopped when received :ssl_closed" do
      {:ok, sock} = Socket.start_link(self(), [])

      send(sock, {:ssl_closed, :sock})

      assert_receive {:connected, ^sock, @connected}
      assert_receive {:disconnected, ^sock, %Socket.Error{reason: :ssl_closed}}
    end

    test "it will be stopped when received :ssl_error" do
      {:ok, sock} = Socket.start_link(self(), [])

      send(sock, {:ssl_error, :sock, :reason})

      assert_receive {:connected, ^sock, @connected}
      assert_receive {:disconnected, ^sock, %Socket.Error{reason: :reason}}
    end

    test_with_mock "it can send frame", :gen_tcp, [:unstick], send: fn :sock, _data -> :ok end do
      {:ok, sock} = Socket.start_link(self(), [])

      frame = Frame.new_ping_request()

      assert Socket.send_frame(sock, frame) == :ok
      assert Socket.normal_stop(sock) == :ok

      assert_called(:gen_tcp.send(:sock, pack(frame)))
    end

    test_with_mock "it will be stopped when send frame failed", :gen_tcp, [:unstick],
      close: fn :sock -> :ok end,
      send: fn :sock, _data -> {:error, :reason} end do
      {:ok, sock} = Socket.start_link(self(), [])

      frame = Frame.new_ping_request()

      assert Socket.send_frame(sock, frame) == :ok

      assert_receive {:disconnected, ^sock, %Socket.Error{reason: :reason}}
      assert_called(:gen_tcp.send(:sock, pack(frame)))
    end

    test "it can receive frame" do
      {:ok, sock} = Socket.start_link(self(), [])
      assert is_pid(sock)

      assert_receive {:connected, ^sock, @connected}

      reply_hdr = %ReplyHeader{xid: 123, zxid: 456, err: 789}
      buf = pack(reply_hdr)
      frame = <<byte_size(buf)::32>> <> buf

      # receive frame
      send(sock, {:tcp, :sock, frame})
      assert_receive {:frame, ^sock, %Frame{reply_hdr: ^reply_hdr, payload: ""}}
    end

    test "it can receive fragmented frame" do
      {:ok, sock} = Socket.start_link(self(), [])
      assert is_pid(sock)

      assert_receive {:connected, ^sock, @connected}

      reply_hdr = %ReplyHeader{xid: 123, zxid: 456, err: 789}
      buf = pack(reply_hdr)
      frame = <<byte_size(buf)::32>> <> buf

      for data <-
            frame
            |> :binary.bin_to_list()
            |> Enum.chunk_every(16)
            |> Enum.map(&:binary.list_to_bin/1) do
        send(sock, {:tcp, :sock, data})
      end

      # receive frame
      assert_receive {:frame, ^sock, %Frame{reply_hdr: ^reply_hdr, payload: ""}}
    end
  end
end
