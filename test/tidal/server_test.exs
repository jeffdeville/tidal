defmodule Tidal.ServerTest do
  use Tidal.Case, async: true

  alias Tidal.Protocol.{Resource, ResourceTemplate, Tool}

  defmodule Tools do
    @behaviour Tidal.Tool

    @impl true
    def define_tools do
      [
        Tool.new!(name: "zebra", input_schema: %{"type" => "object"}),
        Tool.new!(name: "alpha", input_schema: %{"type" => "object"})
      ]
    end

    @impl true
    def handle_tool_call(_name, _arguments, _context), do: {:error, "unused"}
  end

  defmodule Resources do
    @behaviour Tidal.Resource

    @impl true
    def define_resources do
      [
        %Resource{uri: "tidal://zebra", name: "Zebra"},
        %ResourceTemplate{uri_template: "tidal://items/{id}", name: "Item"},
        %Resource{uri: "tidal://alpha", name: "Alpha"}
      ]
    end

    @impl true
    def handle_read_resource(_uri, _context), do: {:error, :unused}
  end

  defmodule InvalidHeaderTools do
    @behaviour Tidal.Tool

    @impl true
    def define_tools do
      [
        Tool.new!(
          name: "invalid",
          input_schema: %{
            "type" => "object",
            "properties" => %{
              "first" => %{"type" => "string", "x-mcp-header" => "Region"},
              "second" => %{"type" => "integer", "x-mcp-header" => "region"}
            }
          }
        )
      ]
    end

    @impl true
    def handle_tool_call(_name, _arguments, _context), do: {:error, "unused"}
  end

  defmodule UnreachableHeaderTools do
    @behaviour Tidal.Tool

    @impl true
    def define_tools do
      [
        Tool.new!(
          name: "invalid",
          input_schema: %{
            "type" => "object",
            "properties" => %{
              "items" => %{
                "type" => "array",
                "items" => %{
                  "type" => "string",
                  "x-mcp-header" => "Invalid Header"
                }
              }
            }
          }
        )
      ]
    end

    @impl true
    def handle_tool_call(_name, _arguments, _context), do: {:error, "unused"}
  end

  test "builds one immutable, deterministically ordered server catalog" do
    server =
      Tidal.Server.new!(
        tool_modules: [Tools],
        resource_handlers: [Resources],
        server_info: %{name: "catalog-test", version: "2.0.0"},
        instructions: "Use the smallest applicable operation.",
        cache: [ttl_ms: 5_000, scope: :public]
      )

    assert %Tidal.Server{} = server
    assert Enum.map(server.tools, & &1.name) == ["alpha", "zebra"]
    assert Enum.map(server.resources, & &1.uri) == ["tidal://alpha", "tidal://zebra"]
    assert Enum.map(server.resource_templates, & &1.uri_template) == ["tidal://items/{id}"]
    assert server.server_info == %{"name" => "catalog-test", "version" => "2.0.0"}
    assert server.cache == %{ttl_ms: 5_000, scope: "public"}
    assert server.supported_versions == ["2026-07-28", "2025-11-25"]

    assert server.capabilities == %{
             "resources" => %{"listChanged" => true, "subscribe" => true},
             "tools" => %{"listChanged" => true}
           }
  end

  test "rejects duplicate tool names at the configuration boundary" do
    assert_raise ArgumentError, ~r/duplicate tool name:/, fn ->
      Tidal.Server.new!(tool_modules: [Tools, Tools])
    end
  end

  test "rejects unsafe origin configuration at the configuration boundary" do
    assert_raise ArgumentError, ~r/allowed_origins/, fn ->
      Tidal.Server.new!(allowed_origins: ["not an origin"])
    end
  end

  test "rejects duplicate x-mcp-header names case-insensitively" do
    assert_raise ArgumentError, ~r/duplicate x-mcp-header/i, fn ->
      Tidal.Server.new!(tool_modules: [InvalidHeaderTools])
    end
  end

  test "rejects unreachable and malformed x-mcp-header annotations" do
    assert_raise ArgumentError, ~r/x-mcp-header/, fn ->
      Tidal.Server.new!(tool_modules: [UnreachableHeaderTools])
    end
  end
end
