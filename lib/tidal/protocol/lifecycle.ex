defmodule Tidal.Protocol.Lifecycle do
  @moduledoc """
  Handles MCP lifecycle protocol methods: initialize, initialized, ping, shutdown.
  """

  alias Tidal.JSONRPC
  alias Tidal.Protocol

  require Tidal.JSONRPC.ErrorCodes, as: ErrorCodes

  @doc """
  Handles the `initialize` request.

  Validates the client's protocol version, stores client info and capabilities,
  and returns the server's capabilities and info.
  """
  def handle_initialize(%JSONRPC.Request{} = request, state) do
    params = request.params || %{}
    client_protocol_version = params["protocolVersion"]

    if compatible_protocol_version?(client_protocol_version) do
      client_info = params["clientInfo"] || %{}
      client_capabilities = params["capabilities"] || %{}

      result = %{
        "protocolVersion" => Protocol.supported_protocol_version(),
        "capabilities" => state.capabilities,
        "serverInfo" => state.server_info
      }

      response = %JSONRPC.Response{id: request.id, result: result}

      new_state =
        state
        |> Map.put(:lifecycle, :initializing)
        |> Map.put(:client_info, client_info)
        |> Map.put(:client_capabilities, client_capabilities)

      {response, new_state}
    else
      error = %JSONRPC.Error{
        id: request.id,
        code: ErrorCodes.invalid_params(),
        message: "Invalid params",
        data:
          "unsupported protocol version: #{inspect(client_protocol_version)}, " <>
            "server supports: #{Protocol.supported_protocol_version()}"
      }

      {error, state}
    end
  end

  @doc """
  Handles the `notifications/initialized` notification.

  Transitions the session to the `:ready` state.
  """
  def handle_initialized(state) do
    {:ok, Map.put(state, :lifecycle, :ready)}
  end

  @doc """
  Handles the `ping` request.

  Returns an empty result per the MCP spec.
  """
  def handle_ping(%JSONRPC.Request{} = request, state) do
    response = %JSONRPC.Response{id: request.id, result: %{}}
    {response, state}
  end

  @doc """
  Handles the `shutdown` request.

  Transitions the session to `:shutting_down` and signals the session to stop.
  """
  def handle_shutdown(%JSONRPC.Request{} = request, state) do
    response = %JSONRPC.Response{id: request.id, result: %{}}
    new_state = Map.put(state, :lifecycle, :shutting_down)
    {response, new_state}
  end

  # ── Helpers ─────────────────────────────────────────────────────────

  defp compatible_protocol_version?(nil), do: false

  defp compatible_protocol_version?(version) when is_binary(version) do
    version == Protocol.supported_protocol_version()
  end

  defp compatible_protocol_version?(_), do: false
end
