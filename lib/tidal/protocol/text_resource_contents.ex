defmodule Tidal.Protocol.TextResourceContents do
  @moduledoc """
  Text content returned when reading an MCP resource.

  ## Fields

    * `:uri` — the URI of the resource (required)
    * `:mime_type` — MIME type (optional, defaults to `"text/plain"`)
    * `:text` — the text content (required)

  """

  @type t :: %__MODULE__{
          uri: String.t(),
          mime_type: String.t() | nil,
          text: String.t()
        }

  @enforce_keys [:uri, :text]
  defstruct [:uri, :text, mime_type: "text/plain"]

  @doc """
  Serializes to the MCP wire format.
  """
  @spec to_protocol(t()) :: map()
  def to_protocol(%__MODULE__{} = contents) do
    map = %{"uri" => contents.uri, "text" => contents.text}
    map = if contents.mime_type, do: Map.put(map, "mimeType", contents.mime_type), else: map
    map
  end
end
