defmodule Tidal.Protocol do
  @moduledoc """
  MCP protocol message handling.

  Dispatches JSON-RPC requests and notifications to the appropriate
  protocol handler based on method name and session lifecycle state.
  """

  alias Tidal.JSONRPC
  alias Tidal.Protocol.Lifecycle

  require Tidal.JSONRPC.ErrorCodes, as: ErrorCodes

  @supported_protocol_version "2024-11-05"

  @doc """
  Returns the MCP protocol version supported by this server.
  """
  def supported_protocol_version, do: @supported_protocol_version

  @doc """
  Dispatches a JSON-RPC request to the appropriate handler.

  Returns `{response, new_state}` where response is a JSONRPC.Response or JSONRPC.Error.
  """
  @spec handle_request(JSONRPC.Request.t(), map()) ::
          {JSONRPC.Response.t() | JSONRPC.Error.t(), map()}
  def handle_request(%JSONRPC.Request{} = request, state) do
    case check_lifecycle(request.method, state.lifecycle) do
      :ok ->
        dispatch_request(request, state)

      {:error, reason} ->
        error = %JSONRPC.Error{
          id: request.id,
          code: ErrorCodes.invalid_request(),
          message: "Invalid Request",
          data: reason
        }

        {error, state}
    end
  end

  @doc """
  Dispatches a JSON-RPC notification to the appropriate handler.

  Returns `{:ok, new_state}` or `{:error, reason, new_state}`.
  """
  @spec handle_notification(JSONRPC.Notification.t(), map()) ::
          {:ok, map()} | {:error, String.t(), map()}
  def handle_notification(%JSONRPC.Notification{} = notification, state) do
    case check_lifecycle(notification.method, state.lifecycle) do
      :ok ->
        dispatch_notification(notification, state)

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  # ── Lifecycle checks ──────────────────────────────────────────────

  defp check_lifecycle("initialize", lifecycle) do
    case lifecycle do
      :created -> :ok
      _ -> {:error, "session already initialized"}
    end
  end

  defp check_lifecycle("notifications/initialized", lifecycle) do
    case lifecycle do
      :initializing -> :ok
      :created -> {:error, "must send initialize request first"}
      _ -> {:error, "session already initialized"}
    end
  end

  defp check_lifecycle(_method, lifecycle) do
    case lifecycle do
      :ready -> :ok
      :created -> {:error, "session not initialized — send initialize first"}
      :initializing -> {:error, "session not ready — send notifications/initialized first"}
      :shutting_down -> {:error, "session is shutting down"}
    end
  end

  # ── Request dispatch ──────────────────────────────────────────────

  defp dispatch_request(%JSONRPC.Request{method: "initialize"} = request, state) do
    Lifecycle.handle_initialize(request, state)
  end

  defp dispatch_request(%JSONRPC.Request{method: "ping"} = request, state) do
    Lifecycle.handle_ping(request, state)
  end

  defp dispatch_request(%JSONRPC.Request{method: "shutdown"} = request, state) do
    Lifecycle.handle_shutdown(request, state)
  end

  defp dispatch_request(%JSONRPC.Request{} = request, state) do
    error = %JSONRPC.Error{
      id: request.id,
      code: ErrorCodes.method_not_found(),
      message: "Method not found",
      data: "unknown method: #{request.method}"
    }

    {error, state}
  end

  # ── Notification dispatch ─────────────────────────────────────────

  defp dispatch_notification(%JSONRPC.Notification{method: "notifications/initialized"}, state) do
    Lifecycle.handle_initialized(state)
  end

  defp dispatch_notification(%JSONRPC.Notification{method: "notifications/" <> _}, state) do
    # Accept other notifications silently
    {:ok, state}
  end

  defp dispatch_notification(%JSONRPC.Notification{}, state) do
    {:ok, state}
  end
end
