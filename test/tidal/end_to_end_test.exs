defmodule Tidal.EndToEndTest do
  @moduledoc """
  End-to-end validation of Tidal as a complete MCP server library.

  Exercises the full lifecycle: initialize → tools → resources →
  subscriptions → session isolation → crash recovery → termination,
  all over real HTTP through Plug/Bandit.
  """
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :e2e

  # ── Sample MCP server modules ──────────────────────────────────────

  defmodule SampleToolHandler do
    @moduledoc "Sample tool handler demonstrating idiomatic Tidal.Tool behaviour."
    @behaviour Tidal.Tool

    alias Tidal.Protocol.{Tool, TextContent, ToolResult}

    @impl true
    def define_tools do
      [
        Tool.new!(
          name: "greet",
          description: "Generates a greeting for the given name",
          input_schema: %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string", "description" => "Name to greet"},
              "style" => %{"type" => "string", "description" => "Greeting style (formal/casual)"}
            },
            "required" => ["name"]
          }
        ),
        Tool.new!(
          name: "calculate",
          description: "Evaluates a basic math expression",
          input_schema: %{
            "type" => "object",
            "properties" => %{
              "operation" => %{"type" => "string", "enum" => ["add", "multiply"]},
              "x" => %{"type" => "number"},
              "y" => %{"type" => "number"}
            },
            "required" => ["operation", "x", "y"]
          }
        ),
        Tool.new!(
          name: "crash_tool",
          description: "A tool that deliberately crashes (for testing fault tolerance)"
        )
      ]
    end

    @impl true
    def handle_tool_call("greet", %{"name" => name} = args, _session) do
      greeting =
        case Map.get(args, "style", "casual") do
          "formal" -> "Good day, #{name}. How do you do?"
          _ -> "Hey #{name}!"
        end

      {:ok, %ToolResult{content: [%TextContent{text: greeting}]}}
    end

    def handle_tool_call("calculate", %{"operation" => op, "x" => x, "y" => y}, _session) do
      result =
        case op do
          "add" -> x + y
          "multiply" -> x * y
        end

      {:ok, %ToolResult{content: [%TextContent{text: "#{result}"}]}}
    end

    def handle_tool_call("crash_tool", _args, _session) do
      raise "deliberate crash for testing"
    end
  end

  defmodule SampleResourceHandler do
    @moduledoc "Sample resource handler demonstrating idiomatic Tidal.Resource behaviour."
    @behaviour Tidal.Resource

    alias Tidal.Protocol.{Resource, ResourceTemplate, TextResourceContents}

    @impl true
    def define_resources do
      [
        %Resource{
          uri: "tidal://system/status",
          name: "System Status",
          description: "Current system status and uptime",
          mime_type: "application/json"
        },
        %Resource{
          uri: "tidal://docs/readme",
          name: "README",
          description: "Project documentation",
          mime_type: "text/markdown"
        },
        %ResourceTemplate{
          uri_template: "tidal://users/{user_id}/profile",
          name: "User Profile",
          description: "Fetch a user's profile by ID",
          mime_type: "application/json"
        }
      ]
    end

    @impl true
    def handle_read_resource("tidal://system/status", _session) do
      {:ok,
       [
         %TextResourceContents{
           uri: "tidal://system/status",
           text: Jason.encode!(%{status: "operational", uptime_seconds: 42_000}),
           mime_type: "application/json"
         }
       ]}
    end

    def handle_read_resource("tidal://docs/readme", _session) do
      {:ok,
       [
         %TextResourceContents{
           uri: "tidal://docs/readme",
           text: "# Tidal MCP Server\n\nA production-quality MCP server library for Elixir.",
           mime_type: "text/markdown"
         }
       ]}
    end

    def handle_read_resource("tidal://users/" <> user_id_slash_profile, _session) do
      user_id = String.replace_suffix(user_id_slash_profile, "/profile", "")

      {:ok,
       [
         %TextResourceContents{
           uri: "tidal://users/#{user_id}/profile",
           text: Jason.encode!(%{id: user_id, name: "User #{user_id}", role: "developer"}),
           mime_type: "application/json"
         }
       ]}
    end

    def handle_read_resource(_uri, _session), do: {:error, "resource not found"}

    @impl true
    def handle_subscribe(_uri, _session), do: :ok
  end

  # ── Setup ──────────────────────────────────────────────────────────

  setup_all do
    :inets.start()
    :ssl.start()

    {:ok, server} =
      Bandit.start_link(
        plug:
          {Tidal.Plug,
           tool_modules: [SampleToolHandler], resource_handlers: [SampleResourceHandler]},
        port: 0,
        ip: :loopback,
        thousand_island_options: [transport_options: [ip: {127, 0, 0, 1}]]
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)

    %{port: port, server: server}
  end

  # ── Step 1 & 3: Initialize and receive capabilities ────────────────

  describe "Step 1-3: initialize and capabilities" do
    test "full initialize handshake returns tools and resources capabilities", %{port: port} do
      # Send initialize request
      init_body =
        jsonrpc_request(
          "initialize",
          %{
            "protocolVersion" => "2024-11-05",
            "capabilities" => %{},
            "clientInfo" => %{"name" => "e2e-test-client", "version" => "1.0.0"}
          },
          1
        )

      {200, headers, resp_body} = post(port, init_body)

      # Verify session ID assigned
      session_id = header_value(headers, ~c"mcp-session-id")
      assert is_binary(session_id) and byte_size(session_id) > 0

      # Verify response structure
      result = Jason.decode!(resp_body)
      assert result["jsonrpc"] == "2.0"
      assert result["id"] == 1
      assert result["result"]["protocolVersion"] == "2024-11-05"
      assert is_map(result["result"]["serverInfo"])

      # Verify capabilities advertise tools AND resources
      caps = result["result"]["capabilities"]
      assert is_map(caps["tools"]), "Server should advertise tools capability"

      assert caps["resources"] == %{"subscribe" => true},
             "Server should advertise resources with subscribe"

      # Complete handshake with initialized notification
      initialized = jsonrpc_notification("notifications/initialized", %{})
      {202, _, _} = post(port, initialized, session_id)

      # Verify session is ready: ping succeeds
      ping_body = jsonrpc_request("ping", %{}, 2)
      {200, _, ping_resp} = post(port, ping_body, session_id)
      assert Jason.decode!(ping_resp)["result"] == %{}
    end
  end

  # ── Step 4: List tools, call a tool ────────────────────────────────

  describe "Step 4: tools listing and invocation" do
    test "list tools and invoke with realistic arguments", %{port: port} do
      session_id = create_initialized_session(port)

      # List tools
      {200, _, resp} = post(port, jsonrpc_request("tools/list", %{}, 10), session_id)
      tools = Jason.decode!(resp)["result"]["tools"]

      tool_names = Enum.map(tools, & &1["name"]) |> Enum.sort()
      assert tool_names == ["calculate", "crash_tool", "greet"]

      # Verify tool schemas are present
      greet_tool = Enum.find(tools, &(&1["name"] == "greet"))
      assert greet_tool["description"] == "Generates a greeting for the given name"
      assert greet_tool["inputSchema"]["required"] == ["name"]

      # Call greet tool with realistic data
      greet_body =
        jsonrpc_request(
          "tools/call",
          %{"name" => "greet", "arguments" => %{"name" => "Alice", "style" => "formal"}},
          11
        )

      {200, _, greet_resp} = post(port, greet_body, session_id)
      greet_result = Jason.decode!(greet_resp)["result"]

      assert [%{"type" => "text", "text" => "Good day, Alice. How do you do?"}] =
               greet_result["content"]

      # Call calculate tool
      calc_body =
        jsonrpc_request(
          "tools/call",
          %{
            "name" => "calculate",
            "arguments" => %{"operation" => "multiply", "x" => 7, "y" => 6}
          },
          12
        )

      {200, _, calc_resp} = post(port, calc_body, session_id)
      calc_result = Jason.decode!(calc_resp)["result"]
      assert [%{"type" => "text", "text" => "42"}] = calc_result["content"]
    end
  end

  # ── Step 5: List resources, read a resource ────────────────────────

  describe "Step 5: resources listing and reading" do
    test "list resources and read with meaningful content", %{port: port} do
      session_id = create_initialized_session(port)

      # List resources
      {200, _, resp} = post(port, jsonrpc_request("resources/list", %{}, 20), session_id)
      resources = Jason.decode!(resp)["result"]["resources"]

      assert length(resources) == 2
      uris = Enum.map(resources, & &1["uri"]) |> Enum.sort()
      assert uris == ["tidal://docs/readme", "tidal://system/status"]

      # List templates
      {200, _, templ_resp} =
        post(port, jsonrpc_request("resources/templates/list", %{}, 21), session_id)

      templates = Jason.decode!(templ_resp)["result"]["resourceTemplates"]
      assert length(templates) == 1
      assert hd(templates)["uriTemplate"] == "tidal://users/{user_id}/profile"

      # Read system status resource
      {200, _, status_resp} =
        post(
          port,
          jsonrpc_request("resources/read", %{"uri" => "tidal://system/status"}, 22),
          session_id
        )

      contents = Jason.decode!(status_resp)["result"]["contents"]
      assert length(contents) == 1
      status_data = Jason.decode!(hd(contents)["text"])
      assert status_data["status"] == "operational"
      assert status_data["uptime_seconds"] == 42_000

      # Read README resource
      {200, _, readme_resp} =
        post(
          port,
          jsonrpc_request("resources/read", %{"uri" => "tidal://docs/readme"}, 23),
          session_id
        )

      readme_content = Jason.decode!(readme_resp)["result"]["contents"] |> hd()
      assert readme_content["text"] =~ "# Tidal MCP Server"
      assert readme_content["mimeType"] == "text/markdown"

      # Read templated resource with realistic user ID
      {200, _, profile_resp} =
        post(
          port,
          jsonrpc_request("resources/read", %{"uri" => "tidal://users/usr_42/profile"}, 24),
          session_id
        )

      profile = Jason.decode!(profile_resp)["result"]["contents"] |> hd()
      profile_data = Jason.decode!(profile["text"])
      assert profile_data["id"] == "usr_42"
      assert profile_data["name"] == "User usr_42"
      assert profile_data["role"] == "developer"
    end
  end

  # ── Step 6: Subscribe to resource, trigger change, verify SSE ──────

  describe "Step 6: resource subscription and SSE push" do
    test "subscribe and receive update notification via SSE", %{port: port} do
      session_id = create_initialized_session(port)

      # Subscribe to resource
      sub_body = jsonrpc_request("resources/subscribe", %{"uri" => "tidal://system/status"}, 30)
      {200, _, sub_resp} = post(port, sub_body, session_id)
      assert Jason.decode!(sub_resp)["result"] == %{}

      # Open SSE stream via raw TCP
      {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false])

      sse_request =
        "GET / HTTP/1.1\r\n" <>
          "Host: 127.0.0.1:#{port}\r\n" <>
          "Accept: application/json, text/event-stream\r\n" <>
          "Mcp-Session-Id: #{session_id}\r\n" <>
          "\r\n"

      :ok = :gen_tcp.send(socket, sse_request)
      {:ok, header_data} = :gen_tcp.recv(socket, 0, 2_000)
      assert header_data =~ "HTTP/1.1 200"
      assert header_data =~ "text/event-stream"

      # Trigger resource update notification
      Tidal.Resource.notify_resource_updated("tidal://system/status")

      # Receive SSE event
      {:ok, event_data} = :gen_tcp.recv(socket, 0, 2_000)
      assert event_data =~ "event: message"
      assert event_data =~ "notifications/resources/updated"
      assert event_data =~ "tidal://system/status"

      :gen_tcp.close(socket)
    end
  end

  # ── Step 7: Concurrent sessions with independent state ─────────────

  describe "Step 7: multi-session isolation" do
    test "two concurrent sessions have independent state", %{port: port} do
      session_a = create_initialized_session(port)
      session_b = create_initialized_session(port)

      assert session_a != session_b

      # Session A subscribes to status
      sub_a = jsonrpc_request("resources/subscribe", %{"uri" => "tidal://system/status"}, 40)
      {200, _, _} = post(port, sub_a, session_a)

      # Session B subscribes to readme
      sub_b = jsonrpc_request("resources/subscribe", %{"uri" => "tidal://docs/readme"}, 40)
      {200, _, _} = post(port, sub_b, session_b)

      # Verify isolation: each session has its own subscriptions
      {:ok, state_a} = Tidal.Session.get_state(session_a)
      {:ok, state_b} = Tidal.Session.get_state(session_b)

      assert MapSet.member?(state_a.resource_subscriptions, "tidal://system/status")
      refute MapSet.member?(state_a.resource_subscriptions, "tidal://docs/readme")

      assert MapSet.member?(state_b.resource_subscriptions, "tidal://docs/readme")
      refute MapSet.member?(state_b.resource_subscriptions, "tidal://system/status")

      # Both sessions can independently invoke tools
      greet_a =
        jsonrpc_request(
          "tools/call",
          %{"name" => "greet", "arguments" => %{"name" => "Alice"}},
          41
        )

      greet_b =
        jsonrpc_request(
          "tools/call",
          %{"name" => "greet", "arguments" => %{"name" => "Bob"}},
          41
        )

      {200, _, resp_a} = post(port, greet_a, session_a)
      {200, _, resp_b} = post(port, greet_b, session_b)

      assert Jason.decode!(resp_a)["result"]["content"] |> hd() |> Map.get("text") =~ "Alice"
      assert Jason.decode!(resp_b)["result"]["content"] |> hd() |> Map.get("text") =~ "Bob"
    end
  end

  # ── Step 8: Crash one session, verify the other is unaffected ──────

  describe "Step 8: crash isolation" do
    test "crashing one session does not affect another", %{port: port} do
      session_alive = create_initialized_session(port)
      session_doomed = create_initialized_session(port)

      # Verify both sessions are alive
      {200, _, _} = post(port, jsonrpc_request("ping", %{}, 50), session_alive)
      {200, _, _} = post(port, jsonrpc_request("ping", %{}, 50), session_doomed)

      # Kill the doomed session's process directly
      {:ok, doomed_pid} = Tidal.Session.get(session_doomed)
      Process.exit(doomed_pid, :kill)

      # Give the supervisor a moment to clean up
      Process.sleep(50)

      # Doomed session should be gone
      {404, _, _} = post(port, jsonrpc_request("ping", %{}, 51), session_doomed)

      # Alive session should still work perfectly
      {200, _, ping_resp} = post(port, jsonrpc_request("ping", %{}, 51), session_alive)
      assert Jason.decode!(ping_resp)["result"] == %{}

      # Alive session can still use tools
      greet_body =
        jsonrpc_request(
          "tools/call",
          %{"name" => "greet", "arguments" => %{"name" => "Survivor"}},
          52
        )

      {200, _, greet_resp} = post(port, greet_body, session_alive)

      assert Jason.decode!(greet_resp)["result"]["content"] |> hd() |> Map.get("text") =~
               "Survivor"
    end
  end

  # ── Step 9: DELETE session, verify 404 ─────────────────────────────

  describe "Step 9: session termination via DELETE" do
    test "DELETE terminates session and subsequent requests return 404", %{port: port} do
      session_id = create_initialized_session(port)

      # Verify session is working
      {200, _, _} = post(port, jsonrpc_request("ping", %{}, 60), session_id)

      # Use a tool before deleting (to confirm full functionality)
      calc_body =
        jsonrpc_request(
          "tools/call",
          %{
            "name" => "calculate",
            "arguments" => %{"operation" => "add", "x" => 100, "y" => 200}
          },
          61
        )

      {200, _, calc_resp} = post(port, calc_body, session_id)
      assert Jason.decode!(calc_resp)["result"]["content"] |> hd() |> Map.get("text") == "300"

      # DELETE the session
      {204, _, _} = delete(port, session_id)

      # All subsequent requests should return 404
      {404, _, _} = post(port, jsonrpc_request("ping", %{}, 62), session_id)
      {404, _, _} = post(port, jsonrpc_request("tools/list", %{}, 63), session_id)

      {404, _, error_resp} =
        post(
          port,
          jsonrpc_request("resources/read", %{"uri" => "tidal://system/status"}, 64),
          session_id
        )

      assert Jason.decode!(error_resp)["error"] =~ "session not found"
    end
  end

  # ── Failure mode: bad inputs ───────────────────────────────────────

  describe "Failure modes" do
    test "calling unknown tool returns MethodNotFound error", %{port: port} do
      session_id = create_initialized_session(port)

      body =
        jsonrpc_request(
          "tools/call",
          %{"name" => "nonexistent_tool", "arguments" => %{"foo" => "bar"}},
          70
        )

      {200, _, resp} = post(port, body, session_id)
      decoded = Jason.decode!(resp)
      assert decoded["error"]["code"] == -32_601
      assert decoded["error"]["data"] =~ "unknown tool"
    end

    test "calling tool with missing required arguments returns InvalidParams", %{port: port} do
      session_id = create_initialized_session(port)

      body =
        jsonrpc_request(
          "tools/call",
          %{"name" => "greet", "arguments" => %{}},
          71
        )

      {200, _, resp} = post(port, body, session_id)
      decoded = Jason.decode!(resp)
      assert decoded["error"]["code"] == -32_602
      assert decoded["error"]["data"] =~ "missing required arguments"
    end

    test "reading nonexistent resource returns error", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/read", %{"uri" => "tidal://nonexistent"}, 72)
      {200, _, resp} = post(port, body, session_id)
      decoded = Jason.decode!(resp)
      assert decoded["error"]["code"] == -32_602
      assert decoded["error"]["data"] =~ "resource not found"
    end

    test "POST without session ID on non-initialize method returns 400", %{port: port} do
      body = jsonrpc_request("tools/list", %{}, 73)
      {400, _, resp} = post(port, body)
      assert Jason.decode!(resp)["error"] =~ "Mcp-Session-Id header required"
    end

    test "POST with invalid session ID returns 404", %{port: port} do
      body = jsonrpc_request("ping", %{}, 74)
      {404, _, resp} = post(port, body, "invalid-session-id-that-does-not-exist")
      assert Jason.decode!(resp)["error"] =~ "session not found"
    end
  end

  # ── Full lifecycle in a single test ────────────────────────────────

  describe "Full lifecycle (smoke test)" do
    test "complete MCP lifecycle: init → tools → resources → subscribe → delete", %{port: port} do
      # 1. Initialize
      init_body =
        jsonrpc_request(
          "initialize",
          %{
            "protocolVersion" => "2024-11-05",
            "capabilities" => %{},
            "clientInfo" => %{"name" => "smoke-test", "version" => "0.1.0"}
          },
          1
        )

      {200, headers, init_resp} = post(port, init_body)
      session_id = header_value(headers, ~c"mcp-session-id")
      assert session_id
      init_result = Jason.decode!(init_resp)["result"]
      assert init_result["protocolVersion"] == "2024-11-05"

      # 2. Complete handshake
      {202, _, _} = post(port, jsonrpc_notification("notifications/initialized", %{}), session_id)

      # 3. List and call tools
      {200, _, tools_resp} = post(port, jsonrpc_request("tools/list", %{}, 2), session_id)
      tools = Jason.decode!(tools_resp)["result"]["tools"]
      assert length(tools) == 3

      {200, _, greet_resp} =
        post(
          port,
          jsonrpc_request(
            "tools/call",
            %{"name" => "greet", "arguments" => %{"name" => "World"}},
            3
          ),
          session_id
        )

      assert Jason.decode!(greet_resp)["result"]["content"] |> hd() |> Map.get("text") ==
               "Hey World!"

      # 4. List and read resources
      {200, _, res_resp} = post(port, jsonrpc_request("resources/list", %{}, 4), session_id)
      assert length(Jason.decode!(res_resp)["result"]["resources"]) == 2

      {200, _, read_resp} =
        post(
          port,
          jsonrpc_request("resources/read", %{"uri" => "tidal://system/status"}, 5),
          session_id
        )

      status =
        Jason.decode!(read_resp)["result"]["contents"]
        |> hd()
        |> Map.get("text")
        |> Jason.decode!()

      assert status["status"] == "operational"

      # 5. Subscribe to resource
      {200, _, _} =
        post(
          port,
          jsonrpc_request("resources/subscribe", %{"uri" => "tidal://system/status"}, 6),
          session_id
        )

      {:ok, state} = Tidal.Session.get_state(session_id)
      assert MapSet.member?(state.resource_subscriptions, "tidal://system/status")

      # 6. DELETE session
      {204, _, _} = delete(port, session_id)
      {404, _, _} = post(port, jsonrpc_request("ping", %{}, 7), session_id)
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────

  defp create_initialized_session(port) do
    init_body =
      jsonrpc_request(
        "initialize",
        %{
          "protocolVersion" => "2024-11-05",
          "capabilities" => %{},
          "clientInfo" => %{"name" => "e2e-test", "version" => "1.0"}
        },
        1
      )

    {200, headers, _} = post(port, init_body)
    session_id = header_value(headers, ~c"mcp-session-id")

    initialized = jsonrpc_notification("notifications/initialized", %{})
    {202, _, _} = post(port, initialized, session_id)

    session_id
  end

  defp post(port, body, session_id \\ nil) do
    url = ~c"http://127.0.0.1:#{port}/"

    headers =
      [{~c"accept", ~c"application/json, text/event-stream"}] ++
        if(session_id, do: [{~c"mcp-session-id", to_charlist(session_id)}], else: [])

    {:ok, {{_, status, _}, resp_headers, resp_body}} =
      :httpc.request(:post, {url, headers, ~c"application/json", to_charlist(body)}, [], [])

    {status, resp_headers, to_string(resp_body)}
  end

  defp delete(port, session_id) do
    url = ~c"http://127.0.0.1:#{port}/"
    headers = [{~c"mcp-session-id", to_charlist(session_id)}]

    {:ok, {{_, status, _}, resp_headers, resp_body}} =
      :httpc.request(:delete, {url, headers}, [], [])

    {status, resp_headers, to_string(resp_body)}
  end

  defp jsonrpc_request(method, params, id) do
    Jason.encode!(%{"jsonrpc" => "2.0", "method" => method, "id" => id, "params" => params})
  end

  defp jsonrpc_notification(method, params) do
    Jason.encode!(%{"jsonrpc" => "2.0", "method" => method, "params" => params})
  end

  defp header_value(headers, key) do
    case List.keyfind(headers, key, 0) do
      {_, value} -> to_string(value)
      nil -> nil
    end
  end
end
