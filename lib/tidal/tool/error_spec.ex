defmodule Tidal.Tool.ErrorSpec do
  @moduledoc """
  Represents a declared error in a tool's error catalog.

  Each error has a name, HTTP-style status code, retry guidance,
  a human description, and a recovery instruction for the agent.
  """

  @type t :: %__MODULE__{
          name: atom(),
          status: pos_integer(),
          retryable: boolean(),
          desc: String.t(),
          recovery: String.t() | nil
        }

  @enforce_keys [:name, :status, :desc]
  defstruct [:name, :status, :desc, :recovery, retryable: false]

  @doc """
  Formats an error spec into a structured error response map.

  The optional `details` map is merged into the response for runtime context.
  """
  @spec to_response(t(), map()) :: map()
  def to_response(%__MODULE__{} = spec, details \\ %{}) do
    %{
      "status" => "error",
      "error" => to_string(spec.name),
      "reason" => spec.desc,
      "retryable" => spec.retryable,
      "recovery" => spec.recovery
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
    |> Map.merge(details)
  end
end
