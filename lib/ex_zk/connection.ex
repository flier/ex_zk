defmodule ExZk.Connection do
  require Logger

  @behaviour :gen_statem

  defstruct [
    :opts,
    :transport,
    :socket,
    :connected_address,
    :backoff_current,
    :backoff_initial,
    :backoff_max,
    :reconnect_times
  ]

  @type t :: %__MODULE__{
          opts: [option()],
          transport: ExZk.Socket.transport(),
          socket: ExZk.Socket.t(),
          connected_address: String.t(),
          backoff_current: timeout(),
          backoff_initial: timeout(),
          backoff_max: timeout(),
          reconnect_times: integer()
        }

  @type option :: ExZk.Socket.option() | :gen_statem.start_opt()

  @type status :: :disconnected | :connecting | :connected

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
  def stop(conn, timeout \\ :infinity) do
    :gen_statem.stop(conn, :normal, timeout)
  end

  @spec status(:gen_statem.server_ref()) :: status()
  def status(conn) do
    :gen_statem.call(conn, :status)
  end

  ####
  ## Callbacks
  ##

  @impl true
  def callback_mode, do: :state_functions

  @impl true
  def init(opts) do
    transport = if(opts[:ssl], do: :ssl, else: :gen_tcp)

    {:ok, socket} = ExZk.Socket.start_link(self(), opts)

    data = %__MODULE__{
      opts: opts,
      transport: transport,
      socket: socket
    }

    {:ok, :connecting, data}
  end

  @impl true
  def terminate(reason, _state, %__MODULE__{socket: socket}) do
    if Process.alive?(socket) and reason == :normal do
      :ok = ExZk.Socket.normal_stop(socket)
    end
  end

  ####
  ## State functions
  ##

  # "Disconnected" state: the connection is down and the socket is not alive.
  def disconnected({:timeout, :reconnect}, _timer_info, %__MODULE__{opts: opts} = data) do
    {:ok, socket} = ExZk.Socket.start_link(self(), opts)

    {:next_state, :connecting, %{data | socket: socket}}
  end

  def disconnected(:info, {:stopped, socket, reason}, %__MODULE__{socket: socket} = data) do
    data = %{data | connected_address: nil}
    disconnect(data, reason)
  end

  def disconnected(
        {:call, from},
        :status,
        %__MODULE__{backoff_current: backoff_current, reconnect_times: reconnect_times} = _data
      ) do
    :gen_statem.reply(
      from,
      {:disconnected, %{backoff_current: backoff_current, reconnect_times: reconnect_times}}
    )

    :keep_state_and_data
  end

  # "Connecting" state: the connection is on going and the socket is not alive.
  def connecting(:info, {:connected, socket, _sock, addr}, %__MODULE__{socket: socket} = data) do
    data = %{data | backoff_current: nil, reconnect_times: nil, connected_address: addr}
    {:next_state, :connected, %{data | socket: socket}}
  end

  def connecting(:info, {:stopped, socket, reason}, %__MODULE__{socket: socket} = data) do
    disconnect(data, reason)
  end

  def connecting(
        {:call, from},
        :status,
        %__MODULE__{transport: transport, socket: socket} = _data
      ) do
    :gen_statem.reply(from, {:connecting, %{transport: transport, socket: socket}})
    :keep_state_and_data
  end

  # "Connected" state: the connection is up and the socket is alive.
  def connected(:info, {:stopped, socket, reason}, %__MODULE__{socket: socket} = data) do
    data = %{data | connected_address: nil}
    disconnect(data, reason)
  end

  def connected({:call, from}, :status, %__MODULE__{connected_address: addr} = _data) do
    :gen_statem.reply(from, {:connected, %{addr: addr}})
    :keep_state_and_data
  end

  ####
  ## Private methods
  ##

  defp disconnect(%__MODULE__{opts: opts} = data, reason) do
    if opts[:exit_on_disconnection] do
      {:stop, %ExZk.ConnectionError{reason: reason}}
    else
      {backoff, data} = next_backoff(data)

      actions = [
        {{:timeout, :reconnect}, backoff, nil}
      ]

      {:next_state, :disconnected, data, actions}
    end
  end

  defp next_backoff(%__MODULE__{backoff_current: nil} = data) do
    backoff_initial = data.opts[:backoff_initial]
    {backoff_initial, %{data | backoff_current: backoff_initial, reconnect_times: 1}}
  end

  @backoff_exponent 1.5

  defp next_backoff(%__MODULE__{opts: opts, reconnect_times: reconnect_times} = data) do
    next_exponential_backoff = round(data.backoff_current * @backoff_exponent)

    backoff_current =
      case opts[:backoff_max] do
        :infinity -> next_exponential_backoff
        backoff_max -> min(next_exponential_backoff, backoff_max)
      end

    {backoff_current,
     %{data | backoff_current: backoff_current, reconnect_times: reconnect_times + 1}}
  end
end
