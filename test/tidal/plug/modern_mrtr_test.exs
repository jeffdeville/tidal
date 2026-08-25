defmodule Tidal.Plug.ModernMrtrTest do
  use Tidal.Case, async: true

  import Tidal.ModernProtocolHelpers

  alias Tidal.ModernProtocolFixtures.Tools

  @plug_opts [tool_modules: [Tools], request_state_secret: String.duplicate("m", 32)]
  @capabilities %{"elicitation" => %{}}

  test "ends an input-required request and completes on a stateless retry" do
    initial =
      request(
        "tools/call",
        %{"name" => "confirm", "arguments" => %{}},
        1,
        capabilities: @capabilities
      )

    first = call(initial, @plug_opts)
    first_result = decode(first)["result"]

    assert first.status == 200
    assert first_result["resultType"] == "input_required"
    assert is_binary(first_result["requestState"])

    assert first_result["inputRequests"]["confirmation"]["method"] ==
             "elicitation/create"

    retry =
      request(
        "tools/call",
        %{
          "name" => "confirm",
          "arguments" => %{},
          "requestState" => first_result["requestState"],
          "inputResponses" => %{
            "confirmation" => %{
              "result" => %{"action" => "accept", "content" => true}
            }
          }
        },
        2,
        capabilities: @capabilities
      )

    second = call(retry, @plug_opts)

    assert second.status == 200
    assert decode(second)["result"]["resultType"] == "complete"
    assert get_in(decode(second), ["result", "content", Access.at(0), "text"]) == "confirmed=true"

    changed =
      request(
        "tools/call",
        %{
          "name" => "confirm",
          "arguments" => %{"changed" => true},
          "requestState" => first_result["requestState"],
          "inputResponses" => %{"confirmation" => %{"result" => %{}}}
        },
        3,
        capabilities: @capabilities
      )

    changed_result = call(changed, @plug_opts) |> decode() |> get_in(["result"])
    assert changed_result["isError"] == true
    assert get_in(changed_result, ["content", Access.at(0), "text"]) =~ "request_mismatch"
  end

  test "rejects an input-required result when the request omitted its required capability" do
    message = request("tools/call", %{"name" => "confirm", "arguments" => %{}})
    conn = call(message, @plug_opts)

    assert conn.status == 400

    assert decode(conn)["error"] == %{
             "code" => -32_021,
             "message" => "Missing required client capability",
             "data" => %{"requiredCapabilities" => %{"elicitation" => %{}}}
           }
  end
end
