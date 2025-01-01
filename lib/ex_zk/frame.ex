defmodule ExZk.Frame do
  alias ExZk.Defs.OpCode
  alias ExZk.{Multi, Proto}
  alias ExZk.Proto.{ReplyHeader, RequestHeader, WatcherEvent}
  alias ExZk.WatchedEvent
  alias ExZk.Watcher.Event

  defstruct [:req_hdr, :reply_hdr, :request, :response, :payload]

  @type t :: %__MODULE__{
          req_hdr: RequestHeader.t() | nil,
          reply_hdr: ReplyHeader.t() | nil,
          request: request() | nil,
          response: response() | nil,
          payload: binary() | nil
        }

  @type request ::
          Proto.ConnectRequest.t()
          | Proto.AuthPacket.t()
          | Proto.CreateRequest.t()
          | Proto.CreateTTLRequest.t()
          | Proto.DeleteRequest.t()
          | Proto.ExistsRequest.t()
          | Proto.GetACLRequest.t()
          | Proto.GetAllChildrenNumberRequest.t()
          | Proto.GetChildren2Request.t()
          | Proto.GetChildrenRequest.t()
          | Proto.GetDataRequest.t()
          | Proto.GetEphemeralsRequest.t()
          | Proto.SetACLRequest.t()
          | Proto.SetDataRequest.t()
          | Proto.SetWatches.t()
          | Proto.SetWatches2.t()
          | Proto.SyncRequest.t()
          | Multi.request()

  @type response ::
          :pong
          | {:auth_failed, error()}
          | {:notification, zxid(), WatcherEvent.t()}
          | Proto.ConnectResponse.t()
          | Proto.Create2Response.t()
          | Proto.CreateResponse.t()
          | Proto.ExistsResponse.t()
          | Proto.GetACLResponse.t()
          | Proto.GetAllChildrenNumberResponse.t()
          | Proto.GetChildren2Response.t()
          | Proto.GetChildrenResponse.t()
          | Proto.GetDataResponse.t()
          | Proto.GetEphemeralsResponse.t()
          | Proto.SetACLResponse.t()
          | Proto.SetDataResponse.t()
          | Proto.SyncResponse.t()

  @type error :: integer()
  @type xid :: integer()
  @type zxid :: integer()
  @type watches :: list(String.t())

  @default_protocol_version 0

  @notification_xid -1
  @ping_xid -2
  @auth_packet_xid -4
  @set_watches_xid -8

  ####
  ## Public API
  ##

  @spec new_ping_request :: t()
  def new_ping_request do
    %__MODULE__{
      req_hdr: new_request_header(@ping_xid, :ping)
    }
  end

  @spec new_auth_packet(scheme :: String.t(), auth :: binary()) :: t()
  def new_auth_packet(scheme, auth) do
    %__MODULE__{
      req_hdr: new_request_header(@auth_packet_xid, :auth),
      request: %Proto.AuthPacket{scheme: scheme, auth: auth}
    }
  end

  @spec new_connect_request(
          last_zxid :: zxid(),
          session_timeout :: timeout(),
          session_id :: integer(),
          passwd :: binary(),
          readonly :: boolean() | nil
        ) :: t()
  def new_connect_request(
        last_zxid \\ 0,
        session_timeout \\ 0,
        session_id \\ 0,
        passwd \\ "",
        readonly \\ nil
      ) do
    %__MODULE__{
      request: %Proto.ConnectRequest{
        protocol_version: @default_protocol_version,
        last_zxid_seen: last_zxid || 0,
        time_out: session_timeout || 0,
        session_id: session_id || 0,
        passwd: passwd || "",
        read_only: readonly
      }
    }
  end

  @spec new_set_watches_request(
          relative_zxid :: zxid(),
          data_watches :: watches(),
          exist_watches :: watches(),
          child_watches :: watches()
        ) :: t()
  def new_set_watches_request(relative_zxid, data_watches, exist_watches, child_watches) do
    %__MODULE__{
      req_hdr: new_request_header(@set_watches_xid, :set_watches),
      request: %Proto.SetWatches{
        relative_zxid: relative_zxid,
        data_watches: data_watches,
        exist_watches: exist_watches,
        child_watches: child_watches
      }
    }
  end

  @spec new_set_watches2_request(
          relative_zxid :: zxid(),
          data_watches :: watches(),
          exist_watches :: watches(),
          child_watches :: watches(),
          persistent_watches :: watches(),
          persistent_recursive_watches :: watches()
        ) :: t()
  def new_set_watches2_request(
        relative_zxid,
        data_watches,
        exist_watches,
        child_watches,
        persistent_watches,
        persistent_recursive_watches
      ) do
    %__MODULE__{
      req_hdr: new_request_header(@set_watches_xid, :set_watches2),
      request: %Proto.SetWatches2{
        relative_zxid: relative_zxid,
        data_watches: data_watches,
        exist_watches: exist_watches,
        child_watches: child_watches,
        persistent_watches: persistent_watches,
        persistent_recursive_watches: persistent_recursive_watches
      }
    }
  end

  @spec new_close_session :: t()
  def new_close_session, do: %__MODULE__{req_hdr: new_request_header(0, :close_session)}

  @spec unpack(data :: binary()) :: t()
  def unpack(data) when is_binary(data) do
    {:ok, reply_hdr, rest} = ReplyHeader.unpack(data)

    {response, rest} =
      case reply_hdr do
        %ReplyHeader{xid: @ping_xid} ->
          {:pong, rest}

        %ReplyHeader{xid: @auth_packet_xid, err: err} ->
          {{:auth_failed, err}, rest}

        %ReplyHeader{xid: @notification_xid, zxid: zxid} ->
          {:ok,
           %WatcherEvent{
             type: type,
             state: state,
             path: path
           }, rest} = WatcherEvent.unpack(rest)

          {{:notification,
            %WatchedEvent{
              type: Event.Type.cast!(type),
              state: Event.KeeperState.cast!(state),
              path: path,
              zxid: zxid
            }}, rest}

        %ReplyHeader{xid: xid} when xid < 0 ->
          {nil, rest}

        _ ->
          {nil, rest}
      end

    %__MODULE__{
      reply_hdr: reply_hdr,
      response: response,
      payload: rest
    }
  end

  ####
  ## Protocol
  ##

  defimpl ExZk.Wire.Pack do
    alias ExZk.{Frame, Wire}

    def pack(%Frame{} = frame) do
      buf =
        if !is_nil(frame.req_hdr) or !is_nil(frame.request) do
          Wire.pack([frame.req_hdr, frame.request])
        else
          Wire.pack([frame.reply_hdr, frame.response])
        end

      <<byte_size(buf)::32>> <> buf
    end
  end

  ####
  ## Private methods
  ##

  defp new_request_header(xid, op_code),
    do: %RequestHeader{xid: xid, type: OpCode.value!(op_code)}
end
