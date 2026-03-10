defmodule Tidal.Protocol.BlobResourceContents do
  @moduledoc """
  Binary (base64-encoded) content returned when reading an MCP resource.

  ## Fields

    * `:uri` — the URI of the resource (required)
    * `:mime_type` — MIME type (optional)
    * `:blob` — base64-encoded binary data (required)

  """

  @type t :: %__MODULE__{
          uri: String.t(),
          mime_type: String.t() | nil,
          blob: String.t()
        }

  @enforce_keys [:uri, :blob]
  defstruct [:uri, :blob, :mime_type]

  @doc """
  Serializes to the MCP wire format.
  """
  @spec to_protocol(t()) :: map()
  def to_protocol(%__MODULE__{} = contents) do
    map = %{"uri" => contents.uri, "blob" => contents.blob}
    map = if contents.mime_type, do: Map.put(map, "mimeType", contents.mime_type), else: map
    map
  end
end
