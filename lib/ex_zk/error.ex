defmodule ExZk.Error do
  defstruct [:message]

  @type t :: %__MODULE__{
          message: String.t()
        }
end
