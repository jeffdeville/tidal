defmodule Tidal.Protocol.ToolResultTest do
  use ExUnit.Case, async: true

  alias Tidal.Protocol.{ToolResult, TextContent, ImageContent, EmbeddedResource}

  describe "to_map/1" do
    test "serializes text content" do
      result = %ToolResult{
        content: [%TextContent{text: "hello"}]
      }

      map = ToolResult.to_map(result)
      assert map == %{"content" => [%{"type" => "text", "text" => "hello"}]}
      refute Map.has_key?(map, "isError")
    end

    test "serializes image content" do
      result = %ToolResult{
        content: [%ImageContent{data: "base64data", mime_type: "image/png"}]
      }

      map = ToolResult.to_map(result)

      assert [%{"type" => "image", "data" => "base64data", "mimeType" => "image/png"}] =
               map["content"]
    end

    test "serializes embedded resource content" do
      result = %ToolResult{
        content: [%EmbeddedResource{resource: %{"uri" => "file:///test.txt", "text" => "data"}}]
      }

      map = ToolResult.to_map(result)

      assert [%{"type" => "resource", "resource" => %{"uri" => "file:///test.txt"}}] =
               map["content"]
    end

    test "serializes mixed content types" do
      result = %ToolResult{
        content: [
          %TextContent{text: "text"},
          %ImageContent{data: "img", mime_type: "image/jpeg"}
        ]
      }

      map = ToolResult.to_map(result)
      assert length(map["content"]) == 2
      assert Enum.at(map["content"], 0)["type"] == "text"
      assert Enum.at(map["content"], 1)["type"] == "image"
    end

    test "includes isError when true" do
      result = %ToolResult{
        content: [%TextContent{text: "error message"}],
        is_error: true
      }

      map = ToolResult.to_map(result)
      assert map["isError"] == true
    end

    test "omits isError when false" do
      result = %ToolResult{content: [%TextContent{text: "ok"}], is_error: false}
      map = ToolResult.to_map(result)
      refute Map.has_key?(map, "isError")
    end
  end
end
