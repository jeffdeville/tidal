defmodule Tidal.Protocol.ResourcesTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias Tidal.Protocol.{BlobResourceContents, Resource, ResourceTemplate, TextResourceContents}

  # ── Test resource handler ──────────────────────────────────────────

  defmodule TestResourceHandler do
    @behaviour Tidal.Resource

    @impl true
    def define_resources do
      [
        %Resource{
          uri: "test://config",
          name: "Test Config",
          description: "Test configuration data",
          mime_type: "application/json"
        },
        %Resource{
          uri: "test://readme",
          name: "README",
          mime_type: "text/plain"
        },
        %ResourceTemplate{
          uri_template: "test://files/{path}",
          name: "Files",
          description: "Access test files by path",
          mime_type: "text/plain"
        }
      ]
    end

    @impl true
    def handle_read_resource("test://config", _session) do
      {:ok,
       [
         %TextResourceContents{
           uri: "test://config",
           text: ~s({"debug": true}),
           mime_type: "application/json"
         }
       ]}
    end

    def handle_read_resource("test://readme", _session) do
      {:ok,
       [
         %TextResourceContents{
           uri: "test://readme",
           text: "# Hello World",
           mime_type: "text/plain"
         }
       ]}
    end

    def handle_read_resource("test://files/" <> path, _session) do
      {:ok,
       [
         %TextResourceContents{
           uri: "test://files/#{path}",
           text: "contents of #{path}",
           mime_type: "text/plain"
         }
       ]}
    end

    def handle_read_resource(_uri, _session) do
      {:error, "resource not found"}
    end

    @impl true
    def handle_subscribe(_uri, _session), do: :ok
  end

  defmodule BlobResourceHandler do
    @behaviour Tidal.Resource

    @impl true
    def define_resources do
      [
        %Resource{
          uri: "test://binary",
          name: "Binary Data",
          mime_type: "application/octet-stream"
        }
      ]
    end

    @impl true
    def handle_read_resource("test://binary", _session) do
      {:ok,
       [
         %BlobResourceContents{
           uri: "test://binary",
           blob: Base.encode64("binary data"),
           mime_type: "application/octet-stream"
         }
       ]}
    end

    def handle_read_resource(_uri, _session), do: {:error, "not found"}

    @impl true
    def handle_subscribe(_uri, _session), do: :ok
  end

  # ── Setup ──────────────────────────────────────────────────────────

  setup_all do
    :inets.start()
    :ssl.start()

    {:ok, server} =
      Bandit.start_link(
        plug: {Tidal.Plug, resource_handlers: [TestResourceHandler, BlobResourceHandler]},
        port: 0,
        ip: :loopback,
        thousand_island_options: [transport_options: [ip: {127, 0, 0, 1}]]
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)

    %{port: port}
  end

  # ── resources/list ─────────────────────────────────────────────────

  describe "resources/list" do
    test "returns all defined resources", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/list", %{}, 10)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      resources = decoded["result"]["resources"]

      assert is_list(resources)
      assert length(resources) == 3

      config = Enum.find(resources, &(&1["uri"] == "test://config"))
      assert config["name"] == "Test Config"
      assert config["description"] == "Test configuration data"
      assert config["mimeType"] == "application/json"

      readme = Enum.find(resources, &(&1["uri"] == "test://readme"))
      assert readme["name"] == "README"
      assert readme["mimeType"] == "text/plain"

      binary = Enum.find(resources, &(&1["uri"] == "test://binary"))
      assert binary["name"] == "Binary Data"
      assert binary["mimeType"] == "application/octet-stream"
    end

    test "returns empty list when no resource handlers configured", %{port: _port} do
      # Start a server with no resource handlers
      {:ok, server} =
        Bandit.start_link(
          plug: Tidal.Plug,
          port: 0,
          ip: :loopback,
          thousand_island_options: [transport_options: [ip: {127, 0, 0, 1}]]
        )

      {:ok, {_ip, port}} = ThousandIsland.listener_info(server)

      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/list", %{}, 10)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["result"]["resources"] == []
    end
  end

  # ── resources/read ─────────────────────────────────────────────────

  describe "resources/read" do
    test "reads text resource by URI", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/read", %{"uri" => "test://config"}, 11)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      contents = decoded["result"]["contents"]

      assert length(contents) == 1
      content = hd(contents)
      assert content["uri"] == "test://config"
      assert content["text"] == ~s({"debug": true})
      assert content["mimeType"] == "application/json"
    end

    test "reads resource matching a template URI", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/read", %{"uri" => "test://files/hello.txt"}, 12)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      contents = decoded["result"]["contents"]

      assert length(contents) == 1
      content = hd(contents)
      assert content["uri"] == "test://files/hello.txt"
      assert content["text"] == "contents of hello.txt"
    end

    test "reads blob resource", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/read", %{"uri" => "test://binary"}, 13)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      contents = decoded["result"]["contents"]

      assert length(contents) == 1
      content = hd(contents)
      assert content["uri"] == "test://binary"
      assert content["blob"] == Base.encode64("binary data")
      assert content["mimeType"] == "application/octet-stream"
    end

    test "returns error for unknown resource URI", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/read", %{"uri" => "test://nonexistent"}, 14)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["error"]["code"] == -32_602
      assert decoded["error"]["data"] =~ "resource not found"
    end

    test "returns error for missing URI param", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/read", %{}, 15)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["error"]["code"] == -32_602
      assert decoded["error"]["data"] =~ "missing required parameter: uri"
    end
  end

  # ── resources/templates/list ───────────────────────────────────────

  describe "resources/templates/list" do
    test "returns resource templates", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/templates/list", %{}, 20)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      templates = decoded["result"]["resourceTemplates"]

      assert length(templates) == 1
      template = hd(templates)
      assert template["uriTemplate"] == "test://files/{path}"
      assert template["name"] == "Files"
      assert template["description"] == "Access test files by path"
      assert template["mimeType"] == "text/plain"
    end
  end

  # ── resources/subscribe and unsubscribe ────────────────────────────

  describe "resources/subscribe" do
    test "subscribe returns success", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/subscribe", %{"uri" => "test://config"}, 30)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["result"] == %{}
    end

    test "subscribe tracks URI in session state", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/subscribe", %{"uri" => "test://config"}, 30)
      {200, _headers, _resp_body} = post(port, body, session_id)

      {:ok, state} = Tidal.Session.get_state(session_id)
      assert MapSet.member?(state.resource_subscriptions, "test://config")
    end

    test "unsubscribe removes URI from session state", %{port: port} do
      session_id = create_initialized_session(port)

      # Subscribe
      sub_body = jsonrpc_request("resources/subscribe", %{"uri" => "test://config"}, 30)
      {200, _headers, _resp_body} = post(port, sub_body, session_id)

      # Unsubscribe
      unsub_body = jsonrpc_request("resources/unsubscribe", %{"uri" => "test://config"}, 31)
      {200, _headers, resp_body} = post(port, unsub_body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["result"] == %{}

      {:ok, state} = Tidal.Session.get_state(session_id)
      refute MapSet.member?(state.resource_subscriptions, "test://config")
    end

    test "subscribe returns error for missing URI", %{port: port} do
      session_id = create_initialized_session(port)

      body = jsonrpc_request("resources/subscribe", %{}, 30)
      {200, _headers, resp_body} = post(port, body, session_id)

      decoded = Jason.decode!(resp_body)
      assert decoded["error"]["code"] == -32_602
      assert decoded["error"]["data"] =~ "missing required parameter: uri"
    end
  end

  # ── Subscription isolation ─────────────────────────────────────────

  describe "subscription isolation" do
    test "subscriptions are per-session", %{port: port} do
      session1 = create_initialized_session(port)
      session2 = create_initialized_session(port)

      # Session 1 subscribes
      body1 = jsonrpc_request("resources/subscribe", %{"uri" => "test://config"}, 30)
      {200, _headers, _resp_body} = post(port, body1, session1)

      # Session 2 subscribes to a different resource
      body2 = jsonrpc_request("resources/subscribe", %{"uri" => "test://readme"}, 30)
      {200, _headers, _resp_body} = post(port, body2, session2)

      # Verify isolation
      {:ok, state1} = Tidal.Session.get_state(session1)
      {:ok, state2} = Tidal.Session.get_state(session2)

      assert MapSet.member?(state1.resource_subscriptions, "test://config")
      refute MapSet.member?(state1.resource_subscriptions, "test://readme")

      assert MapSet.member?(state2.resource_subscriptions, "test://readme")
      refute MapSet.member?(state2.resource_subscriptions, "test://config")
    end
  end

  # ── SSE notifications ──────────────────────────────────────────────

  describe "resource update notifications" do
    test "subscribed session receives notification via SSE", %{port: port} do
      session_id = create_initialized_session(port)

      # Subscribe to resource
      sub_body = jsonrpc_request("resources/subscribe", %{"uri" => "test://config"}, 30)
      {200, _headers, _resp_body} = post(port, sub_body, session_id)

      # Register ourselves as an SSE subscriber
      :ok = Tidal.Session.subscribe(session_id)

      # Trigger resource update notification
      Tidal.Resource.notify_resource_updated("test://config")

      # Should receive the notification
      assert_receive {:sse_message, notification}, 1000

      assert notification.method == "notifications/resources/updated"
      assert notification.params == %{"uri" => "test://config"}
    end

    test "unsubscribed session does not receive notification", %{port: port} do
      session_id = create_initialized_session(port)

      # Don't subscribe to any resources, just register as SSE subscriber
      :ok = Tidal.Session.subscribe(session_id)

      # Trigger resource update
      Tidal.Resource.notify_resource_updated("test://config")

      # Should NOT receive notification
      refute_receive {:sse_message, _}, 200
    end

    test "notification only goes to sessions subscribed to that URI", %{port: port} do
      session1 = create_initialized_session(port)
      session2 = create_initialized_session(port)

      # Session 1 subscribes to config
      sub1 = jsonrpc_request("resources/subscribe", %{"uri" => "test://config"}, 30)
      {200, _headers, _resp_body} = post(port, sub1, session1)
      :ok = Tidal.Session.subscribe(session1)

      # Session 2 subscribes to readme
      sub2 = jsonrpc_request("resources/subscribe", %{"uri" => "test://readme"}, 30)
      {200, _headers, _resp_body} = post(port, sub2, session2)
      :ok = Tidal.Session.subscribe(session2)

      # Notify config change
      Tidal.Resource.notify_resource_updated("test://config")

      # Session 1 should receive it
      assert_receive {:sse_message, notification}, 1000
      assert notification.params == %{"uri" => "test://config"}

      # Session 2 should NOT receive it (subscribed to different URI)
      # Note: We can only check one mailbox (ours), so we verify session 2
      # via state instead
      {:ok, state2} = Tidal.Session.get_state(session2)
      refute MapSet.member?(state2.resource_subscriptions, "test://config")
    end
  end

  # ── Initialize advertises resource capabilities ────────────────────

  describe "capability advertisement" do
    test "server advertises resources capability when handlers configured", %{port: port} do
      init_body =
        jsonrpc_request(
          "initialize",
          %{
            "protocolVersion" => "2024-11-05",
            "capabilities" => %{},
            "clientInfo" => %{"name" => "test-client", "version" => "1.0"}
          },
          1
        )

      {200, _headers, resp_body} = post(port, init_body)
      result = Jason.decode!(resp_body)["result"]

      assert result["capabilities"]["resources"] == %{"subscribe" => true}
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp create_initialized_session(port) do
    init_body =
      jsonrpc_request(
        "initialize",
        %{"protocolVersion" => "2024-11-05", "capabilities" => %{}},
        1
      )

    {200, headers, _resp_body} = post(port, init_body)
    session_id = header_value(headers, ~c"mcp-session-id")

    initialized_body = jsonrpc_notification("notifications/initialized", %{})
    {202, _headers, _resp_body} = post(port, initialized_body, session_id)

    session_id
  end

  defp post(port, body, session_id \\ nil) do
    url = ~c"http://127.0.0.1:#{port}/"

    headers =
      [{~c"accept", ~c"application/json, text/event-stream"}] ++
        if session_id, do: [{~c"mcp-session-id", to_charlist(session_id)}], else: []

    {:ok, {{_, status, _}, resp_headers, resp_body}} =
      :httpc.request(:post, {url, headers, ~c"application/json", to_charlist(body)}, [], [])

    {status, resp_headers, to_string(resp_body)}
  end

  defp jsonrpc_request(method, params, id) do
    Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => method,
      "id" => id,
      "params" => params
    })
  end

  defp jsonrpc_notification(method, params) do
    Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params
    })
  end

  defp header_value(headers, key) do
    case List.keyfind(headers, key, 0) do
      {_, value} -> to_string(value)
      nil -> nil
    end
  end
end
