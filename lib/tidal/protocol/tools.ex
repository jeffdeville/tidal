defmodule Tidal.Protocol.Tools do
  @moduledoc """
  Handles MCP tools protocol methods: tools/list and tools/call.
  """

  alias Tidal.JSONRPC
  alias Tidal.Protocol.{Tool, ToolResult, TextContent}
  alias Tidal.Tool.Pipeline

  require Tidal.JSONRPC.ErrorCodes, as: ErrorCodes

  @doc """
  Handles the `tools/list` request.

  Returns all defined tools from the registered tool modules.
  """
  def handle_list(%JSONRPC.Request{} = request, state) do
    tool_modules = Map.get(state, :tool_modules, [])

    tools =
      tool_modules
      |> Enum.flat_map(& &1.define_tools())
      |> Enum.map(&Tool.to_map/1)

    response = %JSONRPC.Response{id: request.id, result: %{"tools" => tools}}
    {response, state}
  end

  @doc """
  Handles the `tools/call` request.

  Validates the tool name, invokes the appropriate handler, and returns the result.
  """
  def handle_call(%JSONRPC.Request{} = request, state) do
    params = request.params || %{}
    tool_name = params["name"]
    arguments = params["arguments"] || %{}

    tool_modules = Map.get(state, :tool_modules, [])

    case find_tool(tool_modules, tool_name) do
      {:ok, module, tool} ->
        invoke_tool(module, tool, tool_name, arguments, request, state)

      :error ->
        error = %JSONRPC.Error{
          id: request.id,
          code: ErrorCodes.method_not_found(),
          message: "Method not found",
          data: "unknown tool: #{tool_name}"
        }

        {error, state}
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────────

  defp find_tool(tool_modules, tool_name) do
    Enum.reduce_while(tool_modules, :error, fn module, _acc ->
      tools = module.define_tools()

      case Enum.find(tools, &(&1.name == tool_name)) do
        nil -> {:cont, :error}
        tool -> {:halt, {:ok, module, tool}}
      end
    end)
  end

  defp invoke_tool(module, tool, tool_name, arguments, request, state) do
    with :ok <- validate_arguments(tool, arguments),
         {:ok, result} <- run_pipeline(module, tool_name, arguments, state) do
      response = %JSONRPC.Response{id: request.id, result: ToolResult.to_map(result)}
      {response, state}
    else
      {:error, :validation, msg} ->
        error = %JSONRPC.Error{
          id: request.id,
          code: ErrorCodes.invalid_params(),
          message: "Invalid params",
          data: msg
        }

        {error, state}

      {:error, reason} when is_binary(reason) ->
        error_result = %ToolResult{
          content: [%TextContent{text: reason}],
          is_error: true
        }

        response = %JSONRPC.Response{id: request.id, result: ToolResult.to_map(error_result)}
        {response, state}
    end
  end

  defp run_pipeline(module, tool_name, arguments, state) do
    middleware = Map.get(state, :middleware, [])

    handler = fn _name, args, session ->
      case module.handle_tool_call(tool_name, args, session) do
        {:ok, %ToolResult{} = result} -> {:ok, result, session}
        {:error, reason} -> {:error, reason}
      end
    end

    case Pipeline.call(middleware, tool_name, arguments, state, handler) do
      {:ok, %ToolResult{} = result, _session} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_arguments(%Tool{input_schema: nil}, _arguments), do: :ok

  defp validate_arguments(%Tool{input_schema: schema}, arguments) do
    validate_required(schema, arguments)
  end

  defp validate_required(%{"required" => required} = _schema, arguments)
       when is_list(required) do
    missing = Enum.reject(required, &Map.has_key?(arguments, &1))

    case missing do
      [] -> :ok
      fields -> {:error, :validation, "missing required arguments: #{Enum.join(fields, ", ")}"}
    end
  end

  defp validate_required(_schema, _arguments), do: :ok
end
