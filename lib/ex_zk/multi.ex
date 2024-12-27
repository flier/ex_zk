defmodule ExZk.Multi do
  @moduledoc """
  A multi-operation transaction.
  """

  alias ExZk.Create
  alias ExZk.Defs.{ErrCode, OpCode}
  alias ExZk.Proto.MultiHeader

  defmodule Op do
    @moduledoc """
    Represents a single operation in a multi-operation transaction.

    Each operation can be a `create/3`, `set_data/2`, `delete/1`, a version `check/2`
    or just read operations like `get_children/1` or `get_data/1`.
    """

    alias ExZk.Data.Stat
    alias ExZk.Defs.OpCode

    alias ExZk.Proto.{
      CheckVersionRequest,
      Create2Response,
      CreateRequest,
      CreateResponse,
      CreateTTLRequest,
      DeleteRequest,
      ErrorResponse,
      GetChildrenRequest,
      GetChildrenResponse,
      GetDataRequest,
      GetDataResponse,
      SetDataRequest,
      SetDataResponse
    }

    @type t ::
            {:create, Path.t(), iodata(), opts :: [Create.option()]}
            | {:check, Path.t(), version()}
            | {:delete, Path.t(), version()}
            | {:get_children, Path.t()}
            | {:get_data, Path.t()}
            | {:set_data, Path.t(), iodata(), version()}

    @type version :: integer()

    @type request ::
            CreateRequest.t()
            | CreateTTLRequest.t()
            | CheckVersionRequest.t()
            | DeleteRequest.t()
            | GetChildrenRequest.t()
            | GetDataRequest.t()
            | SetDataRequest.t()

    @type response ::
            CreateResponse.t()
            | Create2Response.t()
            | ErrorResponse.t()
            | SetDataResponse.t()
            | GetChildrenResponse.t()
            | GetDataResponse.t()

    @any_version -1

    @doc """
    Constructs a create operation with data and options.
    """
    @spec create(Path.t(), iodata(), opts :: [Create.option()]) :: Op.t()
    def create(path, data, opts) when is_binary(data) and is_list(opts),
      do: {:create, path, data, opts}

    @doc """
    Constructs a create operation with data or options.
    """
    @spec create(Path.t(), data_or_opts :: binary() | [Create.option()]) :: Op.t()
    def create(path, data_or_opts)

    def create(path, data) when is_binary(data), do: {:create, path, data, []}
    def create(path, opts) when is_list(opts), do: {:create, path, "", opts}

    @doc """
    Constructs a create operation without data.
    """
    @spec create(Path.t()) :: Op.t()
    def create(path), do: {:create, path, "", []}

    @doc """
    Constructs an version check operation.
    """
    @spec check(Path.t(), version()) :: Op.t()
    def check(path, version \\ @any_version), do: {:check, path, version}

    @doc """
    Constructs a delete operation.
    """
    @spec delete(Path.t(), version()) :: Op.t()
    def delete(path, version \\ @any_version), do: {:delete, path, version}

    @doc """
    Constructs a get_children operation.
    """
    @spec get_children(Path.t()) :: Op.t()
    def get_children(path), do: {:get_children, path}

    @doc """
    Constructs a get_data operation.
    """
    @spec get_data(Path.t()) :: Op.t()
    def get_data(path), do: {:get_data, path}

    @doc """
    Constructs a set_data operation.
    """
    @spec set_data(Path.t(), iodata(), version()) :: Op.t()
    def set_data(path, data, version \\ @any_version), do: {:set_data, path, data, version}

    @doc """
    Converts a multi operation to a request.
    """
    @spec to_request(Op.t()) :: {OpCode.t(), request()}
    def to_request(op)

    def to_request({:create, path, data, opts}), do: Create.new_request(path, data, opts)

    def to_request({:check, path, version}),
      do: {:check, %CheckVersionRequest{path: IO.chardata_to_string(path), version: version}}

    def to_request({:delete, path, version}),
      do: {:delete, %DeleteRequest{path: IO.chardata_to_string(path), version: version}}

    def to_request({:get_children, path}),
      do: {:get_children, %GetChildrenRequest{path: IO.chardata_to_string(path)}}

    def to_request({:get_data, path}),
      do: {:get_data, %GetDataRequest{path: IO.chardata_to_string(path)}}

    def to_request({:set_data, path, data, version}),
      do:
        {:set_data,
         %SetDataRequest{
           path: IO.chardata_to_string(path),
           data: IO.iodata_to_binary(data),
           version: version
         }}
  end

  defmodule Result do
    @moduledoc """
    Result of a single operation in a multi-operation transaction.
    """

    alias ExZk.Data.Stat

    alias ExZk.Proto.{
      Create2Response,
      CreateResponse,
      ErrorResponse,
      GetChildrenResponse,
      GetDataResponse,
      SetDataResponse
    }

    @type t ::
            {:create, Path.t(), Stat.t() | nil}
            | {:check, :ok}
            | {:delete, :ok}
            | {:error, ErrCode.t() | integer()}
            | {:get_children, children :: [Path.t()]}
            | {:get_data, iodata(), Stat.t()}
            | {:set_data, Stat.t()}

    @doc """
    Unpacks a multi operation result.
    """
    @spec unpack(OpCode.t(), iodata()) ::
            {:ok, t(), binary()} | {:error, reason :: term()}
    def unpack(opcode, data)

    def unpack(:create, data) when is_binary(data) do
      with {:ok, %CreateResponse{path: path}, rest} <- CreateResponse.unpack(data) do
        {:ok, {:create, path, nil}, rest}
      end
    end

    def unpack(:create2, data) when is_binary(data) do
      with {:ok, %Create2Response{path: path, stat: stat}, rest} <- Create2Response.unpack(data) do
        {:ok, {:create, path, stat}, rest}
      end
    end

    def unpack(:delete, data) when is_binary(data), do: {:ok, {:delete, :ok}, data}

    def unpack(:set_data, data) when is_binary(data) do
      with {:ok, %SetDataResponse{stat: stat}, rest} <- SetDataResponse.unpack(data) do
        {:ok, {:set_data, stat}, rest}
      end
    end

    def unpack(:check, data) when is_binary(data), do: {:ok, {:check, :ok}, data}

    def unpack(:get_children, data) when is_binary(data) do
      with {:ok, %GetChildrenResponse{children: children}, rest} <-
             GetChildrenResponse.unpack(data) do
        {:ok, {:get_children, children}, rest}
      end
    end

    def unpack(:get_data, data) when is_binary(data) do
      with {:ok, %GetDataResponse{data: data, stat: stat}, rest} <- GetDataResponse.unpack(data) do
        {:ok, {:get_data, data, stat}, rest}
      end
    end

    def unpack(:error, data) when is_binary(data) do
      with {:ok, %ErrorResponse{err: err}, rest} <- ErrorResponse.unpack(data) do
        err =
          case ErrCode.cast(err) do
            {:ok, err} -> err
            :error -> err
          end

        {:ok, {:error, err}, rest}
      end
    end

    def unpack(opcode, _data), do: {:error, {:unexpected_opcode, opcode}}
  end

  defmodule Response do
    @moduledoc """
    Response of a multi-operation transaction.
    """

    defstruct results: []

    @type t :: %__MODULE__{
            results: [Result.t()]
          }

    @doc """
    Unpacks a multi operation response.
    """
    @spec unpack(iodata()) :: {:ok, t()} | {:error, :nomatch}
    def unpack(data) when is_binary(data) do
      with {:ok, hdr, rest} <- MultiHeader.unpack(data),
           {:ok, results, rest} <- unpack_results(hdr, rest, []) do
        {:ok, %__MODULE__{results: results}, rest}
      end
    end

    defp unpack_results(%MultiHeader{done: true}, rest, results),
      do: {:ok, Enum.reverse(results), rest}

    defp unpack_results(%MultiHeader{type: type, done: false}, rest, results) do
      with {:ok, opcode} <- OpCode.cast(type),
           {:ok, res, rest} <- Result.unpack(opcode, rest),
           {:ok, hdr, rest} <- MultiHeader.unpack(rest) do
        unpack_results(hdr, rest, [res | results])
      else
        :error -> {:error, {:unexpected_opcode, type}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @type request :: [MultiHeader.t() | Op.request()]
  @type response :: [MultiHeader.t() | Op.response()]

  @done %MultiHeader{type: -1, done: true, err: -1}

  ####
  ## Public API
  ##

  @doc """
  Converts a list of operations to a multi request.
  """
  @spec to_request([Op.t()]) :: request()
  def to_request(ops) do
    ops
    |> Stream.flat_map(fn op ->
      {opcode, request} = Op.to_request(op)

      [%MultiHeader{type: OpCode.value!(opcode), done: false, err: -1}, request]
    end)
    |> Stream.concat([@done])
    |> Enum.into([])
  end
end
