defmodule Tidal.Plug.ModernSubscriptionTest do
  use Tidal.Case, async: false

  alias Tidal.ModernProtocolFixtures.{Resources, Tools}

  @version "2026-07-28"

  setup_all do
    {:ok, server} =
      Bandit.start_link(
        plug: {Tidal.Plug, tool_modules: [Tools], resource_handlers: [Resources]},
        port: 0,
        ip: :loopback,
        thousand_island_options: [transport_options: [ip: {127, 0, 0, 1}]]
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
    %{port: port}
  end

  test "subscriptions/listen owns one POST stream and receives only opted-in events", %{port: port} do
    body =
      Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => "listen-1",
        "method" => "subscriptions/listen",
        "params" => %{
          "notifications" => %{
            "toolsListChanged" => true,
            "resourceSubscriptions" => ["tidal://alpha"]
          },
          "_meta" => %{
            "io.modelcontextprotocol/protocolVersion" => @version,
            "io.modelcontextprotocol/clientCapabilities" => %{}
          }
        }
      })

    {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false])
    :ok = :gen_tcp.send(socket, http_request(port, body))

    acknowledgment = receive_until(socket, "notifications/subscriptions/acknowledged")
    assert acknowledgment =~ "HTTP/1.1 200"
    assert acknowledgment =~ "text/event-stream"
    refute String.downcase(acknowledgment) =~ "mcp-session-id"
    assert acknowledgment =~ "listen-1"
    assert acknowledgment =~ "toolsListChanged"
    assert acknowledgment =~ "tidal://alpha"

    :ok = Tidal.Subscriptions.resources_list_changed()
    refute_receive_data(socket)

    :ok = Tidal.Subscriptions.resource_updated("tidal://alpha")
    update = receive_until(socket, "notifications/resources/updated")
    assert update =~ "tidal://alpha"
    assert update =~ "io.modelcontextprotocol/subscriptionId"
    assert update =~ "listen-1"

    :ok = Tidal.Subscriptions.tools_changed()
    assert receive_until(socket, "notifications/tools/list_changed") =~ "listen-1"

    :gen_tcp.close(socket)
  end

  defp http_request(port, body) do
    "POST / HTTP/1.1\r\n" <>
      "Host: 127.0.0.1:#{port}\r\n" <>
      "Content-Type: application/json\r\n" <>
      "Accept: application/json, text/event-stream\r\n" <>
      "MCP-Protocol-Version: #{@version}\r\n" <>
      "Mcp-Method: subscriptions/listen\r\n" <>
      "Content-Length: #{byte_size(body)}\r\n" <>
      "\r\n" <>
      body
  end

  defp receive_until(socket, pattern, accumulated \\ "") do
    {:ok, data} = :gen_tcp.recv(socket, 0, 2_000)
    accumulated = accumulated <> data

    if accumulated =~ pattern do
      accumulated
    else
      receive_until(socket, pattern, accumulated)
    end
  end

  defp refute_receive_data(socket) do
    assert {:error, :timeout} = :gen_tcp.recv(socket, 0, 50)
  end
end
