defmodule Tidal.RequestContextTest do
  use Tidal.Case, async: true

  import Plug.Conn
  import Plug.Test

  test "constructs typed request-local context from the current request only" do
    context_builder = fn conn, metadata ->
      %{
        request_id: conn.assigns.request_id,
        tenant: metadata.client_info["name"]
      }
    end

    server = Tidal.Server.new!(context_builder: context_builder)

    conn =
      conn(:post, "/")
      |> assign(:request_id, "req-123")
      |> assign(:tidal_auth_context, %{subject: "user-7"})

    metadata = %{
      protocol_version: "2026-07-28",
      client_capabilities: %{"elicitation" => %{}},
      client_info: %{"name" => "context-test", "version" => "1.0.0"},
      log_level: "info",
      trace_context: %{"traceparent" => "00-abc-def-01"}
    }

    assert {:ok, context} = Tidal.RequestContext.new(server, conn, metadata)
    assert %Tidal.RequestContext{} = context
    assert context.protocol_version == "2026-07-28"
    assert context.client_capabilities == %{"elicitation" => %{}}
    assert context.client_info == %{"name" => "context-test", "version" => "1.0.0"}
    assert context.log_level == "info"
    assert context.trace_context == %{"traceparent" => "00-abc-def-01"}
    assert context.auth_context == %{subject: "user-7"}
    assert context.assigns == %{request_id: "req-123", tenant: "context-test"}
    assert context.server == server
  end

  test "does not retain values from a previous request" do
    server = Tidal.Server.new!()
    conn = conn(:post, "/")

    first = %{
      protocol_version: "2026-07-28",
      client_capabilities: %{"sampling" => %{}},
      client_info: %{"name" => "first", "version" => "1"},
      log_level: "debug",
      trace_context: %{}
    }

    second = %{
      protocol_version: "2026-07-28",
      client_capabilities: %{},
      client_info: nil,
      log_level: nil,
      trace_context: %{}
    }

    assert {:ok, first_context} = Tidal.RequestContext.new(server, conn, first)
    assert {:ok, second_context} = Tidal.RequestContext.new(server, conn, second)

    assert first_context.client_capabilities == %{"sampling" => %{}}
    assert second_context.client_capabilities == %{}
    assert second_context.client_info == nil
    assert second_context.log_level == nil
  end
end
