defmodule ExZk.Frame do
  use ExZk.Defs

  alias ExZk.Defs.{ErrCode, OpCode}
  alias ExZk.{Multi, Proto, WatchedEvent, Watcher.Event}
  alias ExZk.Proto.{ReplyHeader, RequestHeader, WatcherEvent}
  alias ExZk.Wire.{Pack, Unpack}

  defstruct [:req_hdr, :reply_hdr, :request, :response, :payload]

  @type t :: %__MODULE__{
          req_hdr: RequestHeader.t() | nil,
          reply_hdr: ReplyHeader.t() | nil,
          request: request() | nil,
          response: response() | nil,
          payload: binary() | nil
        }

  @type request ::
          Multi.request()
          | Proto.AddWatchRequest.t()
          | Proto.AuthPacket.t()
          | Proto.ConnectRequest.t()
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
          | Proto.RemoveWatchesRequest.t()
          | Proto.SetACLRequest.t()
          | Proto.SetDataRequest.t()
          | Proto.SetWatches.t()
          | Proto.SetWatches2.t()
          | Proto.SyncRequest.t()

  @type response ::
          :pong
          | {:auth_failed, ErrCode.t()}
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

  @type zxid :: integer()
  @type watches :: [String.t()]

  @default_protocol_version 0

  ####
  ## Public API
  ##

  def has_error?(%__MODULE__{reply_hdr: %ReplyHeader{err: err}}), do: err != 0

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
          session_id :: ExZk.Session.id(),
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

  @spec new_close_session_request :: t()
  def new_close_session_request, do: %__MODULE__{req_hdr: new_request_header(0, :close_session)}

  ####
  ## Protocol
  ##

  defimpl Pack do
    alias ExZk.{Frame, Wire}

    def pack(frame) do
      buf = pack_frame(frame)

      <<byte_size(buf)::32>> <> buf
    end

    defp pack_frame(%Frame{req_hdr: req_hdr, request: request} = frame)
         when req_hdr != nil or request != nil,
         do: Wire.pack([frame.req_hdr, frame.request])

    defp pack_frame(%Frame{reply_hdr: reply_hdr, response: response} = frame)
         when reply_hdr != nil or response != nil,
         do: Wire.pack([frame.reply_hdr, frame.response])
  end

  defimpl Unpack do
    use ExZk.Defs

    alias ExZk.{Defs.ErrCode, Frame, Proto.ReplyHeader, Wire}

    def unpack(%Frame{} = frame, data) when is_binary(data) do
      {:ok, reply_hdr, rest} = Unpack.unpack(%ReplyHeader{}, data)

      {response, rest} = parse_response(reply_hdr, rest)

      frame = %{frame | reply_hdr: reply_hdr, response: response, payload: rest}

      {:ok, frame, rest}
    end

    defp parse_response(%ReplyHeader{xid: @ping_xid}, rest), do: {:pong, rest}

    defp parse_response(%ReplyHeader{xid: @auth_packet_xid, err: err}, rest),
      do: {{:auth_failed, ErrCode.cast!(err)}, rest}

    defp parse_response(%ReplyHeader{xid: @notification_xid, zxid: zxid}, rest) do
      {:ok,
       %WatcherEvent{
         type: type,
         state: state,
         path: path
       }, rest} = Unpack.unpack(%WatcherEvent{}, rest)

      {{:notification,
        %WatchedEvent{
          type: Event.Type.cast!(type),
          state: Event.KeeperState.cast!(state),
          path: path,
          zxid: zxid
        }}, rest}
    end

    defp parse_response(_reply_hdr, rest), do: {nil, rest}
  end

  ####
  ## Private methods
  ##

  defp new_request_header(xid, op_code),
    do: %RequestHeader{xid: xid, type: OpCode.value!(op_code)}
end
