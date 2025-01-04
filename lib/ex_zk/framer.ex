defmodule ExZk.Framer do
  alias ExZk.{Defs.OpCode, Frame, Multi, Proto, Wire.Unpack}
  alias ExZk.Proto.{ErrorResponse, ReplyHeader, RequestHeader}

  defstruct next_xid: 1,
            requests: %{}

  @type t :: %__MODULE__{
          next_xid: xid(),
          requests: %{xid() => {Frame.t(), :gen_statem.from()}}
        }

  @type xid :: integer()

  @response_types [
    create_container: Proto.CreateResponse,
    create_ttl: Proto.Create2Response,
    create: Proto.CreateResponse,
    create2: Proto.Create2Response,
    delete: nil,
    exists: Proto.ExistsResponse,
    get_acl: Proto.GetACLResponse,
    get_all_children_number: Proto.GetAllChildrenNumberResponse,
    get_children: Proto.GetChildrenResponse,
    get_children2: Proto.GetChildren2Response,
    get_data: Proto.GetDataResponse,
    get_ephemerals: Proto.GetEphemeralsResponse,
    multi: Multi.Response,
    multi_read: Multi.Response,
    set_acl: Proto.SetACLResponse,
    set_data: Proto.SetDataResponse,
    sync: Proto.SyncResponse,
    who_am_i: Proto.WhoAmIResponse
  ]

  @spec new_frame(t(), OpCode.t(), Frame.request() | nil, from :: :gen_statem.from() | nil) ::
          {:ok, Frame.t(), t()} | {:error, reason :: term()}
  def new_frame(
        %__MODULE__{next_xid: next_xid, requests: requests} = framer,
        opcode,
        request,
        from \\ nil
      ) do
    frame = %Frame{
      req_hdr: %RequestHeader{xid: next_xid, type: OpCode.value!(opcode)},
      request: request
    }

    requests = Map.put(requests, next_xid, {frame, from})
    framer = %{framer | next_xid: next_xid + 1, requests: requests}

    {:ok, frame, framer}
  end

  @spec parse_frame(t(), data :: binary()) ::
          {:ok, Frame.t(), :gen_statem.from(), t()} | {:error, reason :: term()}
  def parse_frame(%__MODULE__{} = framer, data) do
    with {:ok, frame, _rest} <- Unpack.unpack(%Frame{}, data) do
      parse_reply(frame, framer)
    end
  end

  @spec parse_reply(Frame.t(), t()) ::
          {:ok, Frame.t(), :gen_statem.from(), t()} | {:error, reason :: term()}

  def parse_reply(
        %Frame{reply_hdr: %ReplyHeader{xid: xid}} = frame,
        %__MODULE__{requests: requests} = framer
      )
      when xid >= 0 do
    case Map.pop(requests, xid) do
      {nil, _} ->
        {:error, {:unexpected_xid, xid}}

      {{%Frame{req_hdr: req_hdr, request: request}, from}, requests} ->
        with {:ok, frame} <- handle_reply(%{frame | req_hdr: req_hdr, request: request}) do
          {:ok, frame, from, %{framer | requests: requests}}
        end
    end
  end

  def parse_reply(frame, framer), do: {:ok, frame, nil, framer}

  defp handle_reply(
         %Frame{
           req_hdr: %RequestHeader{type: type},
           reply_hdr: %ReplyHeader{err: 0},
           payload: payload
         } =
           frame
       ) do
    with {:ok, opcode} <- parse_opcode(type),
         {:ok, res_type} <- get_response_type(opcode),
         {:ok, res, rest} <- parse_response(res_type, payload) do
      {:ok, %{frame | response: res, payload: rest}}
    end
  end

  defp handle_reply(%Frame{reply_hdr: %ReplyHeader{err: err}} = frame) do
    {:ok, %{frame | response: %ErrorResponse{err: err}}}
  end

  defp parse_opcode(type) do
    case OpCode.cast(type) do
      {:ok, opcode} -> {:ok, opcode}
      :error -> {:error, {:unexpected_opcode, type}}
    end
  end

  defp get_response_type(opcode) do
    case Keyword.fetch(@response_types, opcode) do
      {:ok, mod} -> {:ok, mod}
      :error -> {:error, {:unexpected_opcode, opcode}}
    end
  end

  defp parse_response(nil, payload), do: {:ok, nil, payload}
  defp parse_response(mod, payload), do: Unpack.unpack(struct!(mod), payload)
end
