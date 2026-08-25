defmodule Tidal.Transport.V20260728 do
  @moduledoc false

  import Plug.Conn

  alias Tidal.JSONRPC.{Notification, Request}
  alias Tidal.Protocol.V20260728, as: Protocol
  alias Tidal.RequestContext
  alias Tidal.Server
  alias Tidal.Subscriptions
  alias Tidal.Transport.V20260728.RequestValidator

  require Logger

  @sse_heartbeat_ms 30_000

  @spec handle_post(Plug.Conn.t(), term(), Server.t()) :: Plug.Conn.t()
  def handle_post(conn, message, %Server{} = server) do
    with :ok <- validate_accept(conn),
         {:ok, metadata} <- RequestValidator.validate(conn, message, server),
         {:ok, context} <- RequestContext.new(server, conn, metadata) do
      dispatch(conn, message, context)
    else
      {:error, status, body} -> send_json(conn, status, body)
      {:error, reason} -> send_context_error(conn, message, reason)
    end
  end

  defp dispatch(conn, %Request{} = request, context) do
    case request.method do
      "subscriptions/listen" when not is_nil(context.server.subscription_bus) ->
        serve_subscription(conn, request, context)

      _method ->
        send_protocol_response(conn, Protocol.handle(request, context))
    end
  end

  defp dispatch(conn, %Notification{}, _context), do: send_resp(conn, 202, "")

  defp send_protocol_response(conn, {status, response}), do: send_json(conn, status, response)

  defp serve_subscription(conn, request, context) do
    requested = request.params["notifications"] || %{}

    with {:ok, honored} <- Subscriptions.subscribe(context.server, requested) do
      conn =
        conn
        |> put_resp_header("content-type", "text/event-stream")
        |> put_resp_header("cache-control", "no-cache")
        |> put_resp_header("x-accel-buffering", "no")
        |> send_chunked(200)

      acknowledgment = subscription_acknowledgment(request.id, honored)

      case chunk_message(conn, acknowledgment) do
        {:ok, conn} -> subscription_loop(conn, request.id, context.server)
        {:error, _reason} -> conn
      end
    else
      {:error, reason} -> send_context_error(conn, request, reason)
    end
  end

  defp subscription_loop(conn, subscription_id, server) do
    receive do
      {:tidal_subscription, event} ->
        notification = event_notification(event, subscription_id)

        case chunk_message(conn, notification) do
          {:ok, conn} -> subscription_loop(conn, subscription_id, server)
          {:error, reason} -> log_disconnect(reason, conn)
        end

      :close ->
        {_status, response} =
          Protocol.handle(
            %Request{id: subscription_id, method: "subscriptions/listen", params: %{}},
            %RequestContext{
              server: server,
              protocol_version: Server.modern_protocol_version(),
              client_capabilities: %{}
            }
          )

        case chunk_message(conn, response) do
          {:ok, conn} -> conn
          {:error, reason} -> log_disconnect(reason, conn)
        end
    after
      @sse_heartbeat_ms ->
        case Plug.Conn.chunk(conn, ": keepalive\n\n") do
          {:ok, conn} -> subscription_loop(conn, subscription_id, server)
          {:error, reason} -> log_disconnect(reason, conn)
        end
    end
  end

  defp subscription_acknowledgment(subscription_id, honored) do
    %{
      "jsonrpc" => "2.0",
      "method" => "notifications/subscriptions/acknowledged",
      "params" => %{
        "notifications" => honored,
        "_meta" => subscription_meta(subscription_id)
      }
    }
  end

  defp event_notification(:tools_list_changed, subscription_id) do
    notification("notifications/tools/list_changed", %{}, subscription_id)
  end

  defp event_notification(:resources_list_changed, subscription_id) do
    notification("notifications/resources/list_changed", %{}, subscription_id)
  end

  defp event_notification({:resource_updated, uri}, subscription_id) do
    notification("notifications/resources/updated", %{"uri" => uri}, subscription_id)
  end

  defp notification(method, params, subscription_id) do
    %{
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => Map.put(params, "_meta", subscription_meta(subscription_id))
    }
  end

  defp subscription_meta(subscription_id) do
    %{"io.modelcontextprotocol/subscriptionId" => subscription_id}
  end

  defp chunk_message(conn, message) do
    Plug.Conn.chunk(conn, "event: message\ndata: #{Jason.encode!(message)}\n\n")
  end

  defp log_disconnect(reason, conn) do
    Logger.debug("MCP subscription stream closed: #{inspect(reason)}")
    conn
  end

  defp validate_accept(conn) do
    media_types =
      conn
      |> get_req_header("accept")
      |> Enum.flat_map(&String.split(&1, ","))
      |> Enum.map(fn value -> value |> String.split(";", parts: 2) |> hd() |> String.trim() |> String.downcase() end)

    if "application/json" in media_types and "text/event-stream" in media_types do
      :ok
    else
      {:error, 406, %{"error" => "Accept header must include application/json and text/event-stream"}}
    end
  end

  defp send_context_error(conn, message, reason) do
    id = if match?(%Request{}, message), do: message.id, else: nil

    send_json(conn, 500, %Tidal.JSONRPC.Error{
      id: id,
      code: -32_603,
      message: "Internal error",
      data: inspect(reason)
    })
  end

  defp send_json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end
end
