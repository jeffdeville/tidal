defmodule Tidal.Protocol.ToolResult do
  @moduledoc """
  Represents the result of a tool invocation.

  Contains a list of content items (TextContent, ImageContent, or EmbeddedResource)
  and an optional `is_error` flag.
  """

  alias Tidal.Protocol.{TextContent, ImageContent, EmbeddedResource}

  @type content_item :: TextContent.t() | ImageContent.t() | EmbeddedResource.t()

  @type t :: %__MODULE__{
          content: [content_item()],
          is_error: boolean()
        }

  defstruct content: [], is_error: false

  @doc """
  Serializes a ToolResult struct to a JSON-compatible map.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = result) do
    content = Enum.map(result.content, &content_to_map/1)

    map = %{"content" => content}

    if result.is_error do
      Map.put(map, "isError", true)
    else
      map
    end
  end

  defp content_to_map(%TextContent{} = c), do: TextContent.to_map(c)
  defp content_to_map(%ImageContent{} = c), do: ImageContent.to_map(c)
  defp content_to_map(%EmbeddedResource{} = c), do: EmbeddedResource.to_map(c)
end
