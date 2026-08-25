defmodule Tidal.Plug.ModernValidationTest do
  use Tidal.Case, async: true

  import Plug.Conn
  import Plug.Test
  import Tidal.ModernProtocolHelpers

  alias Tidal.ModernProtocolFixtures.Tools
  alias Tidal.Transport.V20260728.RequestValidator

  @plug_opts [tool_modules: [Tools]]

  test "requires the protocol version header and mirrors it against request metadata" do
    conn = call(request("tools/list"), @plug_opts, header_version: nil)

    assert conn.status == 400
    assert decode(conn)["error"]["code"] == -32_020

    conn =
      call(request("tools/list"), @plug_opts, header_version: "2025-11-25")

    assert conn.status == 400
    assert decode(conn)["error"]["code"] == -32_020
  end

  test "returns the structured unsupported-version correction" do
    message = request("tools/list", %{}, 9, body_version: "2030-01-01")
    conn = call(message, @plug_opts, header_version: "2030-01-01")

    assert conn.status == 400

    assert decode(conn)["error"] == %{
             "code" => -32_022,
             "message" => "Unsupported protocol version",
             "data" => %{
               "requested" => "2030-01-01",
               "supported" => ["2026-07-28", "2025-11-25"]
             }
           }
  end

  test "requires per-request capabilities but not advisory client identity" do
    without_capabilities =
      update_in(request("tools/list"), ["params", "_meta"], fn meta ->
        Map.delete(meta, "io.modelcontextprotocol/clientCapabilities")
      end)

    rejected = call(without_capabilities, @plug_opts)
    assert rejected.status == 400
    assert decode(rejected)["error"]["code"] == -32_602

    without_client_info =
      update_in(request("tools/list"), ["params", "_meta"], fn meta ->
        Map.delete(meta, "io.modelcontextprotocol/clientInfo")
      end)

    assert call(without_client_info, @plug_opts).status == 200
  end

  test "returns HTTP 404 and JSON-RPC method-not-found for an unknown modern method" do
    conn = call(request("unknown/operation"), @plug_opts)

    assert conn.status == 404
    assert decode(conn)["error"]["code"] == -32_601
  end

  test "requires and validates Mcp-Method and Mcp-Name" do
    missing_method = call(request("tools/list"), @plug_opts, method_header: nil)
    assert missing_method.status == 400
    assert decode(missing_method)["error"]["code"] == -32_020

    mismatched_method = call(request("tools/list"), @plug_opts, method_header: "resources/list")
    assert mismatched_method.status == 400
    assert decode(mismatched_method)["error"]["code"] == -32_020

    tool_request = request("tools/call", %{"name" => "echo", "arguments" => %{"message" => "hi"}})
    missing_name = call(tool_request, @plug_opts, name_header: nil)
    assert missing_name.status == 400
    assert decode(missing_name)["error"]["code"] == -32_020

    mismatched_name = call(tool_request, @plug_opts, name_header: "another-tool")
    assert mismatched_name.status == 400
    assert decode(mismatched_name)["error"]["code"] == -32_020
  end

  test "requires both JSON and SSE response media types" do
    conn = call(request("tools/list"), @plug_opts, accept: "application/json")
    assert conn.status == 406

    conn = call(request("tools/list"), @plug_opts, accept: "text/event-stream")
    assert conn.status == 406
  end

  test "validates browser origins before dispatch" do
    message = request("tools/list")

    no_browser_origin = call(message, @plug_opts)
    assert no_browser_origin.status == 200

    unconfigured =
      call(message, @plug_opts, headers: [{"origin", "http://www.example.com"}])

    assert unconfigured.status == 403

    rejected =
      call(message, @plug_opts, headers: [{"origin", "https://attacker.example"}])

    assert rejected.status == 403
    assert decode(rejected)["error"]["code"] == -32_600

    configured =
      call(
        message,
        Keyword.put(@plug_opts, :allowed_origins, ["https://app.example"]),
        headers: [{"origin", "https://app.example"}]
      )

    assert configured.status == 200
  end

  test "rejects batches and client-sent JSON-RPC responses" do
    batch = [request("tools/list", %{}, 1), request("tools/list", %{}, 2)]
    batch_conn = call(batch, @plug_opts, method_header: "tools/list")
    assert batch_conn.status == 400
    assert decode(batch_conn)["error"]["code"] == -32_600

    response = %{"jsonrpc" => "2.0", "id" => 1, "result" => %{}}
    response_conn = call(response, @plug_opts, method_header: "tools/list")
    assert response_conn.status == 400
    assert decode(response_conn)["error"]["code"] == -32_600
  end

  test "requires a subscriptions/listen notification filter" do
    request = request("subscriptions/listen")
    {:ok, rpc_request} = request |> Jason.encode!() |> Tidal.JSONRPC.decode()

    conn =
      conn(:post, "/")
      |> put_req_header("mcp-protocol-version", "2026-07-28")
      |> put_req_header("mcp-method", "subscriptions/listen")

    assert {:error, 400, error} =
             RequestValidator.validate(conn, rpc_request, Tidal.Server.new!())

    assert error.code == -32_602
    assert error.data == "notifications must be an object"
  end

  test "does not expose subscriptions when the server disabled its event bus" do
    message = request("subscriptions/listen", %{"notifications" => %{}})
    conn = call(message, Keyword.put(@plug_opts, :subscription_bus, nil))

    assert conn.status == 404
    assert decode(conn)["error"]["code"] == -32_601
  end

  test "ignores legacy session and replay headers on modern requests" do
    conn =
      call(request("tools/list"), @plug_opts, headers: [{"mcp-session-id", "legacy"}, {"last-event-id", "17"}])

    assert conn.status == 200
    assert get_resp_header(conn, "mcp-session-id") == []
  end

  test "GET and DELETE are unavailable on the modern transport" do
    for method <- [:get, :delete] do
      conn =
        conn(method, "/")
        |> put_req_header("mcp-protocol-version", "2026-07-28")
        |> Tidal.Plug.call(Tidal.Plug.init(@plug_opts))

      assert conn.status == 405
    end
  end

  test "modern GET and DELETE attempts still validate Origin" do
    for method <- [:get, :delete] do
      conn =
        conn(method, "/")
        |> put_req_header("mcp-protocol-version", "2026-07-28")
        |> put_req_header("origin", "https://attacker.example")
        |> Tidal.Plug.call(Tidal.Plug.init(@plug_opts))

      assert conn.status == 403
    end
  end

  test "Origin protection also covers the legacy compatibility path" do
    body =
      Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{"protocolVersion" => "2025-11-25", "capabilities" => %{}}
      })

    conn =
      conn(:post, "/", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json")
      |> put_req_header("origin", "https://attacker.example")
      |> Tidal.Plug.call(Tidal.Plug.init(@plug_opts))

    assert conn.status == 403
  end
end
