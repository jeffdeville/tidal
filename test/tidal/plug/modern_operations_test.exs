defmodule Tidal.Plug.ModernOperationsTest do
  use Tidal.Case, async: true

  import Tidal.ModernProtocolHelpers

  alias Tidal.ModernProtocolFixtures.{Resources, Tools}

  defp plug_opts do
    [
      tool_modules: [Tools],
      resource_handlers: [Resources],
      context_builder: fn conn, _metadata -> %{test_pid: Map.get(conn.assigns, :test_pid)} end
    ]
  end

  test "passes a fresh typed context to a tool and stamps the result" do
    message = request("tools/call", %{"name" => "echo", "arguments" => %{"message" => "hello"}})
    conn = call(message, plug_opts(), test_pid: self())

    assert conn.status == 200
    assert_receive {:tool_context, %Tidal.RequestContext{} = context}
    assert context.protocol_version == "2026-07-28"
    assert context.client_info["name"] == "tidal-test"

    assert decode(conn)["result"] == %{
             "content" => [%{"type" => "text", "text" => "hello"}],
             "resultType" => "complete",
             "_meta" => %{
               "io.modelcontextprotocol/serverInfo" => %{
                 "name" => "tidal",
                 "version" => "0.1.0"
               }
             }
           }
  end

  test "passes request context to resource handlers and adds private cache defaults" do
    message = request("resources/read", %{"uri" => "tidal://alpha"})
    conn = call(message, plug_opts(), test_pid: self())
    result = decode(conn)["result"]

    assert conn.status == 200
    assert_receive {:resource_context, %Tidal.RequestContext{}}
    assert result["contents"] == [%{"mimeType" => "text/plain", "text" => "alpha", "uri" => "tidal://alpha"}]
    assert result["resultType"] == "complete"
    assert result["ttlMs"] == 0
    assert result["cacheScope"] == "private"
  end

  test "validates x-mcp-header values, including Base64 sentinel decoding" do
    message = request("tools/call", %{"name" => "route", "arguments" => %{"region" => "Hello, 世界"}})

    missing = call(message, plug_opts())
    assert missing.status == 400
    assert decode(missing)["error"]["code"] == -32_020

    encoded = "=?base64?" <> Base.encode64("Hello, 世界") <> "?="
    matching = call(message, plug_opts(), headers: [{"mcp-param-region", encoded}])
    assert matching.status == 200

    mismatch = call(message, plug_opts(), headers: [{"mcp-param-region", "us-east1"}])
    assert mismatch.status == 400
    assert decode(mismatch)["error"]["code"] == -32_020

    unexpected =
      call(message, plug_opts(), headers: [{"mcp-param-region", encoded}, {"mcp-param-shard", "7"}])

    assert unexpected.status == 400
    assert decode(unexpected)["error"]["code"] == -32_020
  end

  test "rejects annotated integers outside the JSON safe range" do
    too_large = 9_007_199_254_740_992

    message =
      request(
        "tools/call",
        %{"name" => "route", "arguments" => %{"region" => "us-east1", "shard" => too_large}}
      )

    conn =
      call(message, plug_opts(),
        headers: [{"mcp-param-region", "us-east1"}, {"mcp-param-shard", Integer.to_string(too_large)}]
      )

    assert conn.status == 400
    assert decode(conn)["error"]["code"] == -32_020
  end

  test "a crashing tool is reported once and is never replayed" do
    message = request("tools/call", %{"name" => "crash", "arguments" => %{}})
    conn = call(message, plug_opts(), test_pid: self())

    assert conn.status == 200
    assert_receive :crash_tool_called
    refute_receive :crash_tool_called
    assert decode(conn)["error"]["code"] == -32_603
  end

  test "ordinary calls run concurrently in independent request processes" do
    message = request("tools/call", %{"name" => "parallel", "arguments" => %{}})
    owner = self()

    tasks =
      for _ <- 1..2 do
        Arena.Task.async(fn -> call(message, plug_opts(), test_pid: owner) end)
      end

    assert_receive {:parallel_tool_entered, first}
    assert_receive {:parallel_tool_entered, second}
    assert first != second

    send(first, :continue)
    send(second, :continue)

    assert Enum.all?(Arena.Task.await_many(tasks), &(&1.status == 200))
  end
end
