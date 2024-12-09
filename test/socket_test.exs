defmodule SocketTest do
  use ExUnit.Case, async: false

  import Mock

  setup_with_mocks([
    {ExZk.Connector, [], [connect: fn _pid, _opts -> {:ok, :sock, :addr} end]},
    {:inet, [:unstick], [setopts: fn _sock, _opts -> :ok end]},
    {:ssl, [], [setopts: fn _sock, _opts -> :ok end]}
  ]) do
    :ok
  end

  describe "Given a ExZk.Socket" do
    test "it can be connected with TCP" do
      Process.flag(:trap_exit, true)

      {:ok, sock} = ExZk.Socket.start_link(self(), [])
      assert is_pid(sock)

      assert_receive {:connected, ^sock, :sock, :addr}
      assert_called(ExZk.Connector.connect(self(), []))
      assert_called(:inet.setopts(:sock, active: :once))

      ExZk.Socket.normal_stop(sock)
      assert_receive {:EXIT, ^sock, :normal}
    end

    test "it can be connected with SSL" do
      Process.flag(:trap_exit, true)

      {:ok, sock} = ExZk.Socket.start_link(self(), ssl: true)
      assert is_pid(sock)

      assert_receive {:connected, ^sock, :sock, :addr}
      assert_called(ExZk.Connector.connect(self(), ssl: true))
      assert_called(:ssl.setopts(:sock, active: :once))

      ExZk.Socket.normal_stop(sock)
      assert_receive {:EXIT, ^sock, :normal}
    end

    test_with_mock "it may be stopped when ExZk.Connector.connect return {:stop, _}",
                   ExZk.Connector,
                   [],
                   connect: fn _pid, _opts -> {:stop, :reason} end do
      Process.flag(:trap_exit, true)

      {:ok, sock} = ExZk.Socket.start_link(self(), [])
      assert is_pid(sock)

      assert_receive {:stopped, ^sock, :reason}
      assert_called(ExZk.Connector.connect(self(), []))

      assert_receive {:EXIT, ^sock, :normal}
    end

    test_with_mock "it may be failed when ExZk.Connector.setopts return {:error, _}",
                   :ssl,
                   [],
                   setopts: fn _sock, _opts -> {:error, :reason} end do
      Process.flag(:trap_exit, true)

      {:ok, sock} = ExZk.Socket.start_link(self(), ssl: true)
      assert is_pid(sock)

      assert_receive {:stopped, ^sock, :reason}
      assert_called(ExZk.Connector.connect(self(), ssl: true))
      assert_called(:ssl.setopts(:sock, active: :once))

      assert_receive {:EXIT, ^sock, :normal}
    end
  end
end
