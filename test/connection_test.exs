defmodule ConnectionTest do
  use ExUnit.Case, async: false

  import Mock

  setup_with_mocks([
    {:inet, [:no_link, :unstick], [setopts: fn _sock, _opts -> :ok end]},
    {:ssl, [:no_link], [setopts: fn _sock, _opts -> :ok end]}
  ]) do
    :ok
  end

  describe "Given a ExZk.Connection" do
    test "it can be connected" do
      with_mocks([
        {ExZk.Connector, [], [connect: fn _pid, _opts -> {:ok, :sock, :addr} end]}
      ]) do
        Process.flag(:trap_exit, true)

        # connect to the server
        {:ok, conn} = ExZk.Connection.start_link(exit_on_disconnection: true)

        # it should be connected
        Process.sleep(100)
        assert ExZk.Connection.status(conn) == {:connected, %{addr: :addr}}

        assert_called_exactly(ExZk.Connector.connect(conn, exit_on_disconnection: true), 1)

        # stop the connection
        ExZk.Connection.stop(conn)

        # it should be terminated
        Process.sleep(100)
        assert !Process.alive?(conn)

        # the EXIT signal should be received
        assert_received {:EXIT, ^conn, :normal}
      end
    end

    test "it should be reconnect when connect failed" do
      with_mocks([
        {ExZk.Connector, [], [connect: fn _pid, _opts -> {:error, :foobar} end]}
      ]) do
        Process.flag(:trap_exit, true)

        # connect to the server
        {:ok, conn} = ExZk.Connection.start_link(backoff_initial: 10, backoff_max: 50)

        # it should be connected
        Process.sleep(100)

        assert ExZk.Connection.status(conn) ==
                 {:disconnected, %{backoff_current: 50, reconnect_times: 5}}

        assert_called_exactly(
          ExZk.Connector.connect(conn, backoff_initial: 10, backoff_max: 50),
          5
        )
      end
    end

    test "it can be sync connected" do
      with_mocks([
        {ExZk.Connector, [], [connect: fn _pid, _opts -> {:ok, :sock, :addr} end]}
      ]) do
        # connect to the server
        {:ok, conn} = ExZk.Connection.start_link(sync_connect: true)

        # it should be connected
        assert ExZk.Connection.status(conn) == {:connected, %{addr: :addr}}

        assert_called_exactly(
          ExZk.Connector.connect(conn, sync_connect: true),
          1
        )
      end
    end

    test "sync connect will not retry" do
      with_mocks([
        {ExZk.Connector, [:no_link], [connect: fn _pid, _opts -> {:error, :foobar} end]}
      ]) do
        Process.flag(:trap_exit, true)

        # connect to the server
        assert ExZk.Connection.start_link(sync_connect: true) ==
                 {:error, %ExZk.ConnectionError{reason: :foobar}}

        assert_called_exactly(
          ExZk.Connector.connect(:_, sync_connect: true),
          1
        )
      end
    end
  end
end
