defmodule Tidal.Protocol.TextContent do
  @moduledoc """
  Represents text content in a tool result.

  Corresponds to the MCP `TextContent` type.
  """

  @type t :: %__MODULE__{
          type: String.t(),
          text: String.t()
        }

  @enforce_keys [:text]
  defstruct type: "text", text: nil

  @doc """
  Serializes a TextContent struct to a JSON-compatible map.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = content) do
    %{"type" => content.type, "text" => content.text}
  end
end
