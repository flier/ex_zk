defmodule ExZk.Framer do
  require Logger

  alias ExZk.{Frame, Multi, Proto}
  alias ExZk.Defs.OpCode
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
    data |> Frame.unpack() |> parse_reply(framer)
  end

  @spec parse_reply(Frame.t(), t()) ::
          {:ok, Frame.t(), :gen_statem.from(), t()} | {:error, reason :: term()}
  def parse_reply(
        %Frame{reply_hdr: %ReplyHeader{xid: xid, err: 0}, payload: payload} = frame,
        %__MODULE__{requests: requests} = framer
      )
      when xid >= 0 do
    case Map.pop(requests, xid) do
      {nil, _} ->
        {:error, :unexpected_xid}

      {{%Frame{req_hdr: %RequestHeader{type: type} = req_hdr, request: request}, from}, requests} ->
        with {:ok, op_code} <- OpCode.cast(type),
             {:ok, res_type} <- Keyword.fetch(@response_types, op_code),
             {:ok, response, rest} <- parse_response(res_type, payload) do
          frame = %{frame | req_hdr: req_hdr, request: request, response: response, payload: rest}

          {:ok, frame, from, %{framer | requests: requests}}
        else
          :error -> {:error, :unexpected_opcode}
        end
    end
  end

  def parse_reply(
        %Frame{reply_hdr: %ReplyHeader{xid: xid, err: err}} = frame,
        %__MODULE__{requests: requests} = framer
      )
      when err != 0 do
    case Map.pop(requests, xid) do
      {nil, _} ->
        {:error, :unexpected_xid}

      {{%Frame{req_hdr: %RequestHeader{} = req_hdr, request: request}, from}, requests} ->
        frame = %{frame | req_hdr: req_hdr, request: request, response: %ErrorResponse{err: err}}

        {:ok, frame, from, %{framer | requests: requests}}
    end
  end

  def parse_reply(frame, framer), do: {:ok, frame, nil, framer}

  defp parse_response(nil, payload), do: {:ok, nil, payload}
  defp parse_response(mod, payload), do: mod.unpack(payload)
end
