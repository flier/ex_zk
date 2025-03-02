defmodule ExZk.Transport do
  @typedoc "A socket representing a client connection"
  @type socket :: :gen_tcp.socket() | :ssl.sslsocket()

  @typedoc "Options which can be set on a socket via setopts/2 (or returned from getopts/1)"
  @type socket_get_options() :: [:inet.socket_getopt()]

  @typedoc "Options which can be set on a socket via setopts/2 (or returned from getopts/1)"
  @type socket_set_options() :: [:inet.socket_setopt()]

  @typedoc "The return value from a close/1 call"
  @type on_close() :: :ok | {:error, any()}

  @typedoc "The return value from a closed/0 call"
  @type on_closed() :: {:tcp_error, :closed} | {:ssl_error, :closed}

  @typedoc "The return value from a recv/3 call"
  @type on_recv() :: {:ok, binary()} | {:error, :closed | :timeout | :inet.posix()}

  @typedoc "The return value from a send/2 call"
  @type on_send() :: :ok | {:error, :closed | {:timeout, rest_data :: binary()} | :inet.posix()}

  @typedoc "The return value from a getopts/2 call"
  @type on_getopts() :: {:ok, [:inet.socket_optval()]} | {:error, :inet.posix()}

  @typedoc "The return value from a setopts/2 call"
  @type on_setopts() :: :ok | {:error, :inet.posix()}

  @doc """
  Closes the given socket.
  """
  @callback close(socket()) :: on_close()

  @doc """
  Returns the closed error.
  """
  @callback closed() :: on_closed()

  @doc """
  Returns available bytes on the given socket. Up to `num_bytes` bytes will be
  returned (0 can be passed in to get the next 'available' bytes, typically the
  next packet). If insufficient bytes are available, the function can wait `timeout`
  milliseconds for data to arrive.
  """
  @callback recv(socket(), length :: non_neg_integer(), timeout :: timeout()) :: on_recv()

  @doc """
  Sends the given data (specified as a binary or an IO list) on the given socket.
  """
  @callback send(socket(), packet :: iodata()) :: on_send()

  @doc """
  Gets the given options on the socket.
  """
  @callback getopts(socket(), socket_get_options()) :: on_getopts()

  @doc """
  Sets the given options on the socket. Should disallow setting of options which
  are not compatible with Thousand Island
  """
  @callback setopts(socket(), socket_set_options()) :: on_setopts()
end
