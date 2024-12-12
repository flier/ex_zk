defmodule ExZk.Frame do
  alias ExZk.Defs.OpCode
  alias ExZk.Proto.{RequestHeader, ReplyHeader, WatcherEvent}

  defstruct [:req_hdr, :reply_hdr, :request, :response, :payload]

  @type t :: %__MODULE__{
          req_hdr: RequestHeader.t(),
          reply_hdr: ReplyHeader.t(),
          request: request(),
          response: response(),
          payload: binary()
        }

  @type request :: term()
  @type response :: :pong | {:auth_failed, error()} | {:notification, zxid(), WatcherEvent.t()}
  @type error :: integer()
  @type xid :: integer()
  @type zxid :: integer()

  @notification_xid -1
  @ping_xid -2
  @auth_packet_xid -4
  # @set_watches_xid -8

  ####
  ## Public API
  ##

  def new_ping_request() do
    %__MODULE__{
      req_hdr: new_request_header(@ping_xid, :ping)
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
    def pack(%ExZk.Frame{req_hdr: req_hdr, request: request}) do
      ExZk.Wire.pack([req_hdr, request])
    end
  end

  ####
  ## Private methods
  ##

  defp new_request_header(xid, op_code) do
    {:ok, type} = OpCode.value(op_code)

    %RequestHeader{xid: xid, type: type}
  end
end
