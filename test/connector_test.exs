defmodule ConnectorTest do
  use ExUnit.Case, async: false

  import Mock

  import ExZk.Frame
  alias ExZk.Proto.ConnectResponse
  alias ExZk.{Connector, Frame, Wire}

  @host "localhost"
  @port 2181
  @timeout 5000
  @bufsize 10_240

  @connect_opts [host: @host, port: @port, timeout: @timeout]
  @inet_opts [:binary, {:active, false}]
  @ssl_opts @inet_opts ++ [{:cacertfile, CAStore.file_path()}, verify: :verify_peer, depth: 3]

  @connect_response %ConnectResponse{
    time_out: 15_000,
    session_id: 123
  }

  @connected %Connector.Connected{
    addr: "#{@host}:#{@port}",
    session_timeout: @connect_response.time_out,
    session_id: @connect_response.session_id,
    passwd: "",
    readonly: false
  }

  setup_with_mocks([
    {:inet, [:unstick, :passthrough],
     [
       getopts: fn :sock, [:sndbuf, :recbuf, :buffer] ->
         {:ok, [sndbuf: @bufsize, recbuf: @bufsize, buffer: @bufsize]}
       end,
       setopts: fn :sock, _opts -> :ok end
     ]},
    {:ssl, [],
     [
       connect: fn _addr, _port, _opts, _timeout -> {:ok, :ssl} end,
       getopts: fn :ssl, [:sndbuf, :recbuf, :buffer] ->
         {:ok, [sndbuf: @bufsize, recbuf: @bufsize, buffer: @bufsize]}
       end,
       setopts: fn :ssl, _opts -> :ok end,
       send: fn :ssl, _data -> :ok end,
       recv: fn :ssl, 0, _timeout -> {:ok, Wire.pack(%Frame{response: @connect_response})} end
     ]},
    {:gen_tcp, [:unstick],
     [
       connect: fn _addr, _port, _opts, _timeout -> {:ok, :sock} end,
       send: fn :sock, _data -> :ok end,
       recv: fn :sock, 0, _timeout -> {:ok, Wire.pack(%Frame{response: @connect_response})} end
     ]}
  ]) do
    :ok
  end

  describe "Given a Connector" do
    test "it can connect to a server" do
      assert Connector.connect(self(), @connect_opts) == {:ok, :sock, @connected}

      assert_called(:gen_tcp.connect(String.to_charlist(@host), @port, @inet_opts, @timeout))
      assert_called(:inet.getopts(:sock, [:sndbuf, :recbuf, :buffer]))
      assert_called(:inet.setopts(:sock, buffer: @bufsize))
      assert_called(:gen_tcp.send(:sock, Wire.pack(new_connect_request())))
      assert_called(:gen_tcp.recv(:sock, 0, @timeout))
    end

    test "it can connect to a server with SSL" do
      assert Connector.connect(self(), @connect_opts ++ [ssl: true]) == {:ok, :ssl, @connected}

      assert_called(:ssl.connect(String.to_charlist(@host), @port, @ssl_opts, @timeout))
      assert_called(:ssl.getopts(:ssl, [:sndbuf, :recbuf, :buffer]))
      assert_called(:ssl.setopts(:ssl, buffer: @bufsize))
      assert_called(:ssl.send(:ssl, Wire.pack(new_connect_request())))
      assert_called(:ssl.recv(:ssl, 0, @timeout))
    end

    test_with_mock "it may be failed when connect to a server", :gen_tcp, [:unstick],
      connect: fn _addr, _port, _opts, _timeout -> {:error, :foobar} end do
      assert Connector.connect(self(), @connect_opts) == {:error, :foobar}

      assert_called(:gen_tcp.connect(String.to_charlist(@host), @port, @inet_opts, @timeout))
    end

    test_with_mock "it may be failed when send connect request", :gen_tcp, [:unstick],
      connect: fn _addr, _port, _opts, _timeout -> {:ok, :sock} end,
      send: fn :sock, _data -> {:error, :foobar} end do
      assert Connector.connect(self(), @connect_opts) == {:error, :foobar}

      assert_called(:gen_tcp.connect(String.to_charlist(@host), @port, @inet_opts, @timeout))
      assert_called(:gen_tcp.send(:sock, Wire.pack(new_connect_request())))
    end

    test "it can connect to a server with auth info" do
      assert Connector.connect(
               self(),
               @connect_opts ++ [auth_info: {:digest, {"username", "password"}}]
             ) == {:ok, :sock, @connected}

      assert_called(:gen_tcp.connect(String.to_charlist(@host), @port, @inet_opts, @timeout))
      assert_called(:gen_tcp.send(:sock, Wire.pack(new_connect_request())))

      assert_called_exactly(
        :gen_tcp.send(:sock, Wire.pack(new_auth_packet("digest", "username:password"))),
        1
      )
    end

    test "it can connect to a server with multiple auth info" do
      auth_info = [
        auth_info: [
          {:digest, {"username", "password"}},
          {:ip, {127, 0, 0, 1}},
          {:ip, ":1"},
          {:x509, "CN=localhost,OU=ZooKeeper,O=Apache,L=Unknown,ST=Unknown,C=Unknown"}
        ]
      ]

      assert Connector.connect(self(), @connect_opts ++ auth_info) == {:ok, :sock, @connected}

      assert_called(:gen_tcp.connect(String.to_charlist(@host), @port, @inet_opts, @timeout))
      assert_called(:gen_tcp.send(:sock, Wire.pack(new_connect_request())))

      auth_packets =
        Wire.pack([
          new_auth_packet("digest", "username:password"),
          new_auth_packet("ip", "127.0.0.1"),
          new_auth_packet("ip", ":1"),
          new_auth_packet(
            "x509",
            "CN=localhost,OU=ZooKeeper,O=Apache,L=Unknown,ST=Unknown,C=Unknown"
          )
        ])

      assert_called_exactly(:gen_tcp.send(:sock, auth_packets), 1)
    end
  end
end
