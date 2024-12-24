defmodule ExZk.Task do
  defmodule Delete do
    use Task

    alias ExZk.Connection
    alias ExZk.Proto.DeleteRequest

    ####
    ## Public API
    ##

    @spec start_link(
            conn :: :gen_statem.server_ref(),
            path :: String.t(),
            version :: integer()
          ) ::
            {:ok, pid()}
    def start_link(conn, path, version \\ 0) do
      Task.start_link(__MODULE__, :run, [conn, path, version])
    end

    @spec run(conn :: :gen_statem.server_ref(), path :: String.t(), version :: integer() | nil) ::
            :ok | {:error, reason :: term()}
    def run(conn, path, version) do
      request = %DeleteRequest{path: path, version: version}

      :ok = Connection.send_request(conn, :delete, request)

      receive do
        {:ok, nil} ->
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule Exists do
    use Task

    alias ExZk.Connection
    alias ExZk.Proto.{ExistsRequest, ExistsResponse}
    alias ExZk.Data.Stat

    ####
    ## Public API
    ##

    @spec start_link(conn :: :gen_statem.server_ref(), path :: String.t()) :: {:ok, pid()}
    def start_link(conn, path) do
      Task.start_link(__MODULE__, :run, [conn, path])
    end

    @spec run(conn :: :gen_statem.server_ref(), path :: String.t()) ::
            {:ok, boolean(), Stat.t()} | {:error, reason :: term()}
    def run(conn, path) do
      request = %ExistsRequest{path: path}

      :ok = Connection.send_request(conn, :exists, request)

      receive do
        {:ok, %ExistsResponse{stat: stat}} ->
          {:ok, true, stat}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
