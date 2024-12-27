defmodule ExZk.Multi do
  alias ExZk.Create
  alias ExZk.Defs.{ErrCode, OpCode}
  alias ExZk.Proto.MultiHeader

  defmodule Op do
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
            {:create, Path.t(), data :: binary(), opts :: [Create.option()]}
            | {:check, Path.t(), version :: integer()}
            | {:delete, Path.t(), version :: integer()}
            | {:get_children, Path.t()}
            | {:get_data, Path.t()}
            | {:set_data, Path.t(), data :: binary(), version :: integer()}

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

    @spec create(Path.t(), data :: binary(), opts :: [Create.option()]) :: Op.t()
    def create(path, data \\ "", opts \\ []), do: {:create, path, data, opts}

    @spec check_version(Path.t(), version :: integer()) :: Op.t()
    def check_version(path, version \\ 0), do: {:check, path, version}

    @spec delete(Path.t(), version :: integer()) :: Op.t()
    def delete(path, version \\ 0), do: {:delete, path, version}

    @spec get_children(Path.t()) :: Op.t()
    def get_children(path), do: {:get_children, path}

    @spec get_data(Path.t()) :: Op.t()
    def get_data(path), do: {:get_data, path}

    @spec set_data(Path.t(), data :: binary(), version :: integer()) :: Op.t()
    def set_data(path, data, version \\ 0), do: {:set_data, path, data, version}

    @spec new_request(t()) :: {OpCode.t(), request()}

    def new_request({:create, path, data, ops}),
      do: Create.new_request(path, data, ops)

    def new_request({:check, path, version}),
      do: {:check, %CheckVersionRequest{path: IO.chardata_to_string(path), version: version}}

    def new_request({:delete, path, version}),
      do: {:delete, %DeleteRequest{path: IO.chardata_to_string(path), version: version}}

    def new_request({:get_children, path}),
      do: {:get_children, %GetChildrenRequest{path: IO.chardata_to_string(path)}}

    def new_request({:get_data, path}),
      do: {:get_data, %GetDataRequest{path: IO.chardata_to_string(path)}}

    def new_request({:set_data, path, data, version}),
      do:
        {:set_data,
         %SetDataRequest{path: IO.chardata_to_string(path), data: data, version: version}}
  end

  defmodule Result do
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
            {:create, Path.t(), Stat.t()}
            | {:check, :ok}
            | {:delete, :ok}
            | {:error, ErrCode.t()}
            | {:get_children, children :: [String.t()]}
            | {:get_data, data :: binary(), Stat.t()}
            | {:set_data, Stat.t()}

    @spec unpack(OpCode.t(), data :: binary()) ::
            {:ok, t(), binary()} | {:error, reason :: term()}
    def unpack(opcode, data)

    def unpack(:create, data) do
      with {:ok, %CreateResponse{path: path}, rest} <- CreateResponse.unpack(data) do
        {:ok, {:create, path, nil}, rest}
      end
    end

    def unpack(:create2, data) do
      with {:ok, %Create2Response{path: path, stat: stat}, rest} <- Create2Response.unpack(data) do
        {:ok, {:create, path, stat}, rest}
      end
    end

    def unpack(:delete, data), do: {:ok, nil, data}

    def unpack(:set_data, data) do
      with {:ok, %SetDataResponse{stat: stat}, rest} <- SetDataResponse.unpack(data) do
        {:ok, {:set_data, stat}, rest}
      end
    end

    def unpack(:check, data), do: {:ok, nil, data}

    def unpack(:get_children, data) do
      with {:ok, %GetChildrenResponse{children: children}, rest} <-
             GetChildrenResponse.unpack(data) do
        {:ok, {:get_children, children}, rest}
      end
    end

    def unpack(:get_data, data) do
      with {:ok, %GetDataResponse{data: data, stat: stat}, rest} <- GetDataResponse.unpack(data) do
        {:ok, {:get_data, data, stat}, rest}
      end
    end

    def unpack(:error, data) do
      with {:ok, %ErrorResponse{err: err}, rest} <- ErrorResponse.unpack(data) do
        {:ok, {:error, err}, rest}
      end
    end
  end

  defmodule Response do
    defstruct [:results]

    @type t :: %__MODULE__{
            results: [Result.t()]
          }

    @spec unpack(buf :: binary()) :: {:ok, t()} | {:error, :nomatch}
    def unpack(buf) when is_binary(buf) do
      with {:ok, hdr, rest} <- MultiHeader.unpack(buf),
           {:ok, results, _rest} <- unpack_results(hdr, rest, []) do
        {:ok, %__MODULE__{results: results}}
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

  ####
  ## Public API
  ##

  @spec new_request([Op.t()]) :: request()
  def new_request(ops) do
    ops
    |> Stream.flat_map(fn op ->
      {opcode, request} = Op.new_request(op)

      [%MultiHeader{type: opcode, done: false, err: ErrCode.value!(:system_error)}, request]
    end)
    |> Stream.concat([done()])
    |> Enum.into([])
  end

  ####
  ## Private methods
  ##

  defp done,
    do: %MultiHeader{type: OpCode.value!(:error), done: true, err: ErrCode.value!(:system_error)}
end
