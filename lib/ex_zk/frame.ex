defmodule ExZk.Frame do
  alias ExZk.Defs.OpCode

  alias ExZk.Proto.{
    AuthPacket,
    ConnectRequest,
    ConnectResponse,
    ReplyHeader,
    RequestHeader,
    SetWatches,
    SetWatches2,
    WatcherEvent
  }

  defstruct [:req_hdr, :reply_hdr, :request, :response, :payload]

  @type t :: %__MODULE__{
          req_hdr: RequestHeader.t() | nil,
          reply_hdr: ReplyHeader.t() | nil,
          request: request() | nil,
          response: response() | nil,
          payload: binary() | nil
        }

  @type request :: ConnectRequest.t() | AuthPacket.t() | SetWatches.t() | SetWatches2.t()
  @type(
    response :: ConnectResponse.t(),
    :pong | {:auth_failed, error()} | {:notification, zxid(), WatcherEvent.t()}
  )
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

  def new_ping_request() do
    %__MODULE__{
      req_hdr: new_request_header(@ping_xid, :ping)
    }
  end

  @spec new_auth_request(scheme :: String.t(), data :: binary()) :: t()
  def new_auth_request(scheme, data) do
    %__MODULE__{
      req_hdr: new_request_header(@auth_packet_xid, :auth),
      request: %AuthPacket{scheme: scheme, auth: data}
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
      request: %ConnectRequest{
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
      request: %SetWatches{
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
      request: %SetWatches2{
        relative_zxid: relative_zxid,
        data_watches: data_watches,
        exist_watches: exist_watches,
        child_watches: child_watches,
        persistent_watches: persistent_watches,
        persistent_recursive_watches: persistent_recursive_watches
      }
    }
  end

  def unpack(buf) when is_binary(buf) do
    {:ok, reply_hdr, rest} = ReplyHeader.unpack(buf)

    {response, rest} =
      case reply_hdr do
        %ReplyHeader{xid: @ping_xid} ->
          {:pong, rest}

        %ReplyHeader{xid: @auth_packet_xid, err: err} ->
          {{:auth_failed, err}, rest}

        %ReplyHeader{xid: @notification_xid, zxid: zxid} ->
          {:ok, watcher_event, rest} = WatcherEvent.unpack(rest)
          {{:notification, zxid, watcher_event}, rest}

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
    def pack(%ExZk.Frame{} = frame) do
      buf =
        if !is_nil(frame.req_hdr) or !is_nil(frame.request) do
          ExZk.Wire.pack([frame.req_hdr, frame.request])
        else
          ExZk.Wire.pack([frame.reply_hdr, frame.response])
        end

      <<byte_size(buf)::32>> <> buf
    end
  end

  ####
  ## Private methods
  ##

  defp new_request_header(xid, op_code) do
    %RequestHeader{xid: xid, type: OpCode.value!(op_code)}
  end
end
