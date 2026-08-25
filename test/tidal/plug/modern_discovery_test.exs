defmodule Tidal.Plug.ModernDiscoveryTest do
  use Tidal.Case, async: true

  import Tidal.ModernProtocolHelpers

  alias Tidal.ModernProtocolFixtures.{Resources, Tools}

  @plug_opts [
    tool_modules: [Tools],
    resource_handlers: [Resources],
    server_info: %{name: "modern-test", version: "2.0.0"},
    instructions: "Use test operations.",
    cache: [ttl_ms: 2_500, scope: :public]
  ]

  test "server/discover succeeds without initialization or a session" do
    conn = call(request("server/discover"), @plug_opts)
    body = decode(conn)

    assert conn.status == 200
    assert Plug.Conn.get_resp_header(conn, "mcp-session-id") == []
    assert body["id"] == 1
    assert body["result"]["resultType"] == "complete"
    assert body["result"]["supportedVersions"] == ["2026-07-28", "2025-11-25"]

    assert body["result"]["capabilities"] == %{
             "resources" => %{"listChanged" => true, "subscribe" => true},
             "tools" => %{"listChanged" => true}
           }

    assert body["result"]["instructions"] == "Use test operations."
    assert body["result"]["ttlMs"] == 2_500
    assert body["result"]["cacheScope"] == "public"

    assert body["result"]["_meta"]["io.modelcontextprotocol/serverInfo"] == %{
             "name" => "modern-test",
             "version" => "2.0.0"
           }
  end

  test "tools/list is directly callable and deterministically ordered" do
    conn = call(request("tools/list"), @plug_opts)
    result = decode(conn)["result"]

    assert conn.status == 200

    assert Enum.map(result["tools"], & &1["name"]) == [
             "confirm",
             "crash",
             "echo",
             "parallel",
             "route"
           ]

    assert result["resultType"] == "complete"
    assert result["ttlMs"] == 2_500
    assert result["cacheScope"] == "public"
  end

  test "resources catalogs are directly callable and deterministically ordered" do
    resources = call(request("resources/list"), @plug_opts) |> decode() |> get_in(["result"])

    templates =
      call(request("resources/templates/list"), @plug_opts)
      |> decode()
      |> get_in(["result"])

    assert Enum.map(resources["resources"], & &1["uri"]) == [
             "tidal://alpha",
             "tidal://zebra"
           ]

    assert resources["resultType"] == "complete"
    assert resources["ttlMs"] == 2_500
    assert resources["cacheScope"] == "public"

    assert Enum.map(templates["resourceTemplates"], & &1["uriTemplate"]) == [
             "tidal://items/{id}"
           ]

    assert templates["resultType"] == "complete"
  end
end
