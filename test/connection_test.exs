defmodule ConnectionTest do
  use ExUnit.Case, async: false

  import Mock

  setup_with_mocks([
    {:inet, [:unstick], [setopts: fn _sock, _opts -> :ok end]},
    {:ssl, [], [setopts: fn _sock, _opts -> :ok end]}
  ]) do
    :ok
  end

  describe "Given a ExZk.Connection" do
    test "it can be connected" do
      with_mocks([
        {ExZk.Connector, [:passthrough], [connect: fn _pid, _opts -> {:ok, :sock, :addr} end]}
      ]) do
        Process.flag(:trap_exit, true)

        # connect to the server
        {:ok, conn} = ExZk.Connection.start_link(exit_on_disconnection: true)

        # it should be connected
        Process.sleep(100)
        assert ExZk.Connection.status(conn) == {:connected, %{addr: :addr}}

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
        {ExZk.Connector, [:passthrough], [connect: fn _pid, _opts -> {:error, :foobar} end]}
      ]) do
        Process.flag(:trap_exit, true)

        # connect to the server
        {:ok, conn} = ExZk.Connection.start_link(backoff_initial: 10, backoff_max: 50)

        # it should be connected
        Process.sleep(100)

        assert ExZk.Connection.status(conn) ==
                 {:disconnected, %{backoff_current: 50, reconnect_times: 5}}
      end
    end
  end
end
