defmodule ExZk.Logger do
  @moduledoc """
  Instrumenter to handle logging of various instrumentation events.
  """

  require Logger

  @doc false
  def install do
    handlers = %{}

    for {key, fun} <- handlers do
      :telemetry.attach({__MODULE__, key}, key, fun, :ok)
    end
  end
end
