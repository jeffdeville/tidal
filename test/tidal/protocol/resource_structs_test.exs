defmodule Tidal.Protocol.ResourceStructsTest do
  use ExUnit.Case, async: true

  alias Tidal.Protocol.{BlobResourceContents, Resource, ResourceTemplate, TextResourceContents}

  # ── Resource ───────────────────────────────────────────────────────

  describe "Resource.new/1" do
    test "creates resource with required fields" do
      assert {:ok, resource} = Resource.new(uri: "test://foo", name: "Foo")
      assert resource.uri == "test://foo"
      assert resource.name == "Foo"
      assert resource.description == nil
      assert resource.mime_type == nil
    end

    test "creates resource with all fields" do
      assert {:ok, resource} =
               Resource.new(
                 uri: "test://foo",
                 name: "Foo",
                 description: "A test resource",
                 mime_type: "text/plain"
               )

      assert resource.description == "A test resource"
      assert resource.mime_type == "text/plain"
    end

    test "rejects missing uri" do
      assert {:error, %NimbleOptions.ValidationError{}} = Resource.new(name: "Foo")
    end

    test "rejects missing name" do
      assert {:error, %NimbleOptions.ValidationError{}} = Resource.new(uri: "test://foo")
    end

    test "rejects non-string uri" do
      assert {:error, %NimbleOptions.ValidationError{}} = Resource.new(uri: 42, name: "Foo")
    end
  end

  describe "Resource.to_protocol/1" do
    test "serializes to MCP wire format" do
      resource = %Resource{
        uri: "test://foo",
        name: "Foo",
        description: "desc",
        mime_type: "text/plain"
      }

      protocol = Resource.to_protocol(resource)

      assert protocol == %{
               "uri" => "test://foo",
               "name" => "Foo",
               "description" => "desc",
               "mimeType" => "text/plain"
             }
    end

    test "omits nil optional fields" do
      resource = %Resource{uri: "test://foo", name: "Foo"}
      protocol = Resource.to_protocol(resource)
      assert protocol == %{"uri" => "test://foo", "name" => "Foo"}
      refute Map.has_key?(protocol, "description")
      refute Map.has_key?(protocol, "mimeType")
    end
  end

  # ── ResourceTemplate ───────────────────────────────────────────────

  describe "ResourceTemplate.new/1" do
    test "creates template with required fields" do
      assert {:ok, template} =
               ResourceTemplate.new(uri_template: "test://files/{path}", name: "Files")

      assert template.uri_template == "test://files/{path}"
      assert template.name == "Files"
    end

    test "creates template with all fields" do
      assert {:ok, template} =
               ResourceTemplate.new(
                 uri_template: "test://files/{path}",
                 name: "Files",
                 description: "Access files",
                 mime_type: "text/plain"
               )

      assert template.description == "Access files"
      assert template.mime_type == "text/plain"
    end

    test "rejects missing uri_template" do
      assert {:error, %NimbleOptions.ValidationError{}} = ResourceTemplate.new(name: "Files")
    end
  end

  describe "ResourceTemplate.to_protocol/1" do
    test "serializes to MCP wire format" do
      template = %ResourceTemplate{
        uri_template: "test://files/{path}",
        name: "Files",
        description: "desc",
        mime_type: "text/plain"
      }

      protocol = ResourceTemplate.to_protocol(template)

      assert protocol == %{
               "uriTemplate" => "test://files/{path}",
               "name" => "Files",
               "description" => "desc",
               "mimeType" => "text/plain"
             }
    end

    test "omits nil optional fields" do
      template = %ResourceTemplate{uri_template: "test://files/{path}", name: "Files"}
      protocol = ResourceTemplate.to_protocol(template)
      assert protocol == %{"uriTemplate" => "test://files/{path}", "name" => "Files"}
    end
  end

  # ── TextResourceContents ───────────────────────────────────────────

  describe "TextResourceContents.to_protocol/1" do
    test "serializes with all fields" do
      contents = %TextResourceContents{
        uri: "test://foo",
        text: "hello",
        mime_type: "text/plain"
      }

      assert TextResourceContents.to_protocol(contents) == %{
               "uri" => "test://foo",
               "text" => "hello",
               "mimeType" => "text/plain"
             }
    end

    test "omits nil mime_type" do
      contents = %TextResourceContents{uri: "test://foo", text: "hello", mime_type: nil}

      protocol = TextResourceContents.to_protocol(contents)
      refute Map.has_key?(protocol, "mimeType")
    end
  end

  # ── BlobResourceContents ───────────────────────────────────────────

  describe "BlobResourceContents.to_protocol/1" do
    test "serializes with all fields" do
      contents = %BlobResourceContents{
        uri: "test://bin",
        blob: Base.encode64("data"),
        mime_type: "application/octet-stream"
      }

      assert BlobResourceContents.to_protocol(contents) == %{
               "uri" => "test://bin",
               "blob" => Base.encode64("data"),
               "mimeType" => "application/octet-stream"
             }
    end

    test "omits nil mime_type" do
      contents = %BlobResourceContents{uri: "test://bin", blob: "data", mime_type: nil}

      protocol = BlobResourceContents.to_protocol(contents)
      refute Map.has_key?(protocol, "mimeType")
    end
  end
end
