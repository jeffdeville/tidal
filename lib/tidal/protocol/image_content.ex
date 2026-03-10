defmodule Tidal.Protocol.ImageContent do
  @moduledoc """
  Represents image content in a tool result.

  Corresponds to the MCP `ImageContent` type.
  """

  @type t :: %__MODULE__{
          type: String.t(),
          data: String.t(),
          mime_type: String.t()
        }

  @enforce_keys [:data, :mime_type]
  defstruct type: "image", data: nil, mime_type: nil

  @doc """
  Serializes an ImageContent struct to a JSON-compatible map.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = content) do
    %{"type" => content.type, "data" => content.data, "mimeType" => content.mime_type}
  end
end
