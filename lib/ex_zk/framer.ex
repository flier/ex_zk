defmodule ExZk.Framer do
  require Logger

  alias ExZk.{
    Frame,
    Framer,
    Multi,
    Proto
  }

  alias ExZk.Defs.OpCode
  alias ExZk.Proto.{ReplyHeader, RequestHeader}

  defstruct next_xid: 1,
            requests: %{}

  @type t :: %__MODULE__{
          next_xid: xid(),
          requests: %{xid() => {Frame.t(), pid()}}
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
    sync: Proto.SyncResponse
  ]

  @spec new_frame(t(), OpCode.t(), Frame.request(), sender :: pid() | nil) ::
          {:ok, Frame.t(), t()} | {:error, reason :: term()}
  def new_frame(
        %__MODULE__{next_xid: next_xid, requests: requests} = framer,
        opcode,
        request,
        sender \\ nil
      ) do
    with {:ok, type} <- OpCode.value(opcode) do
      frame = %Frame{
        req_hdr: %RequestHeader{xid: next_xid, type: type},
        request: request
      }

      requests = Map.put(requests, next_xid, {frame, sender})
      framer = %{framer | next_xid: next_xid + 1, requests: requests}

      {:ok, frame, framer}
    end
  end

  @spec parse_frame(t(), data :: binary()) ::
          {:ok, Frame.t(), sender :: pid(), t()} | {:error, reason :: term()}
  def parse_frame(%__MODULE__{} = framer, data) do
    data |> Frame.unpack() |> parse_reply(framer)
  end

  defp parse_reply(
         %Frame{reply_hdr: %ReplyHeader{xid: xid}, payload: payload} = frame,
         %__MODULE__{requests: requests} = framer
       )
       when xid >= 0 do
    case Map.pop(requests, xid) do
      {nil, _} ->
        {:error, :unexpected_xid}

      {{%Frame{req_hdr: %RequestHeader{type: type}, request: request} = req_hdr, sender},
       requests} ->
        with {:ok, op_code} <- OpCode.cast(type),
             {:ok, res_type} <- Keyword.fetch(@response_types, op_code),
             {:ok, response, rest} <- parse_response(res_type, payload) do
          frame = %Frame{
            frame
            | req_hdr: req_hdr,
              request: request,
              response: response,
              payload: rest
          }

          {:ok, frame, sender, %Framer{framer | requests: requests}}
        else
          :error -> {:error, :unexpected_opcode}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp parse_reply(frame, framer), do: {:ok, frame, nil, framer}

  defp parse_response(nil, payload), do: {:ok, nil, payload}
  defp parse_response(mod, payload), do: mod.unpack(payload)
end
