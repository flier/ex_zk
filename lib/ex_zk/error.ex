defmodule ExZk.Error do
  defstruct [:message]

  @type t :: %__MODULE__{
          message: String.t()
        }
end

defmodule ExZk.ConnectionError do
  defexception [:reason]

  @type t() :: %__MODULE__{reason: atom}

  @impl true
  def message(%__MODULE__{reason: reason}) do
    format_reason(reason)
  end

  # :inet.format_error/1 doesn't format closed messages.
  defp format_reason(:tcp_closed), do: "TCP connection closed"
  defp format_reason(:ssl_closed), do: "SSL connection closed"

  # Manually returned by us when the connection is closed and someone tries to send a command to Zookeeper.
  defp format_reason(:closed), do: "the connection to Zookeeper is closed"

  defp format_reason(reason), do: reason |> :inet.format_error() |> List.to_string()
end
