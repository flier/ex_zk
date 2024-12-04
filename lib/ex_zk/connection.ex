defmodule ExZk.Connection do
  require Logger

  @behaviour :gen_statem

  defstruct [
    :opts,
    :transport,
    :socket,
    :connected_address
  ]

  @type t :: %__MODULE__{
          opts: [option()],
          transport: ExZk.Socket.transport(),
          socket: ExZk.Socket.t()
        }

  @type option :: ExZk.Socket.option() | :gen_statem.start_opt()

  ####
  ## Public API
  ##

  @spec start_link([option()]) :: :gen_statem.start_ret()
  def start_link(opts) when is_list(opts) do
    {gen_statem_opts, opts} = Keyword.split(opts, [:hibernate_after, :debug, :spawn_opt])

    case Keyword.fetch(opts, :name) do
      :error ->
        :gen_statem.start_link(__MODULE__, opts, gen_statem_opts)

      {:ok, atom} when is_atom(atom) ->
        :gen_statem.start_link({:local, atom}, __MODULE__, opts, gen_statem_opts)

      {:ok, {:global, _term} = tuple} ->
        :gen_statem.start_link(tuple, __MODULE__, opts, gen_statem_opts)

      {:ok, {:via, via_module, _term} = tuple} when is_atom(via_module) ->
        :gen_statem.start_link(tuple, __MODULE__, opts, gen_statem_opts)

      {:ok, other} ->
        raise ArgumentError, """
        expected :name option to be one of the following:

          * nil
          * atom
          * {:global, term}
          * {:via, module, term}

        Got: #{inspect(other)}
        """
    end
  end

  @spec stop(:gen_statem.server_ref(), timeout()) :: :ok
  def stop(conn, timeout) do
    :gen_statem.stop(conn, :normal, timeout)
  end

  ####
  ## Callbacks
  ##

  @impl true
  def callback_mode, do: :state_functions

  @impl true
  def init(opts) do
    transport = if(opts[:ssl], do: :ssl, else: :gen_tcp)

    data = %__MODULE__{
      opts: opts,
      transport: transport
    }

    {:ok, :connecting, data}
  end

  @impl true
  def terminate(reason, _state, data) do
    if Process.alive?(data.socket) and reason == :normal do
      :ok = ExZk.Socket.normal_stop(data.socket)
    end
  end

  ####
  ## State functions
  ##
end
