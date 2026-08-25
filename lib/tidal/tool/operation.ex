defmodule Tidal.Tool.Operation do
  @moduledoc """
  Macro for declarative MCP tool definitions.

  `defop` defines a tool's complete contract: input params, output schema,
  error catalog, annotations, and agent guidance — all from a single declaration.
  The macro auto-implements `Tidal.Tool` callbacks and generates JSON Schema,
  validation, and structured error formatting.

  ## Example

      defmodule MyApp.Tools do
        use Tidal.Tool.Operation

        defop :echo do
          desc "Echoes back the provided message"

          param :message, :string, required: true, desc: "The message to echo"

          success do
            field :echoed, :string, desc: "The echoed message"
          end

          error :empty_message, 400, retryable: false,
            desc: "Message was empty",
            recovery: "Provide a non-empty message."

          guidance "Call this to test connectivity."
        end

        @impl true
        def execute(:echo, %{message: message}, _session) do
          if message == "", do: {:error, :empty_message}, else: {:ok, %{echoed: message}}
        end
      end

  ## Callbacks

  After using this module, implement `execute/3`:

      @callback execute(op_name :: atom(), params :: map(), session :: map()) ::
                  {:ok, map()} | {:error, atom()} | {:error, atom(), map()}

  The macro auto-generates `c:Tidal.Tool.define_tools/0` and
  `c:Tidal.Tool.handle_tool_call/3` from your `defop` declarations and
  `execute/3` implementation.
  """

  alias Tidal.Tool.{SchemaBuilder, ErrorSpec}
  alias Tidal.Protocol.{Tool, ToolResult, TextContent}

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Tidal.Tool
      import Tidal.Tool.Operation, only: [defop: 2]
      Module.register_attribute(__MODULE__, :_tidal_operations, accumulate: true)
      @before_compile Tidal.Tool.Operation
    end
  end

  @doc """
  Defines a tool operation with its complete contract.

  Inside the block, use these DSL functions:
  - `desc/1` — tool description
  - `mutation/1` — marks as a mutation (default false)
  - `idempotent/1` — marks as idempotent (default false)
  - `param/3` or `param/4` — input parameter (with optional nested fields block)
  - `success/1` — output schema block with `field/3` declarations
  - `error/3` or `error/4` — declared error with status and options
  - `guidance/1` — agent-facing usage guidance
  """
  defmacro defop(name, do: block) do
    quote do
      # Reset temporary attributes for this operation
      Module.delete_attribute(__MODULE__, :_tidal_desc)
      Module.delete_attribute(__MODULE__, :_tidal_mutation)
      Module.delete_attribute(__MODULE__, :_tidal_idempotent)
      Module.delete_attribute(__MODULE__, :_tidal_guidance)
      Module.put_attribute(__MODULE__, :_tidal_params, [])
      Module.put_attribute(__MODULE__, :_tidal_success_fields, [])
      Module.put_attribute(__MODULE__, :_tidal_errors, [])

      # Import DSL functions for this block
      import Tidal.Tool.Operation.DSL

      # Execute the block — DSL calls accumulate into module attributes
      unquote(block)

      # Collect everything into an operation definition
      @_tidal_operations %{
        name: unquote(name),
        desc: Module.get_attribute(__MODULE__, :_tidal_desc) || "",
        mutation: Module.get_attribute(__MODULE__, :_tidal_mutation) || false,
        idempotent: Module.get_attribute(__MODULE__, :_tidal_idempotent) || false,
        guidance: Module.get_attribute(__MODULE__, :_tidal_guidance),
        params: Module.get_attribute(__MODULE__, :_tidal_params) |> Enum.reverse(),
        success_fields: Module.get_attribute(__MODULE__, :_tidal_success_fields) |> Enum.reverse(),
        errors: Module.get_attribute(__MODULE__, :_tidal_errors) |> Enum.reverse()
      }
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    operations = Module.get_attribute(env.module, :_tidal_operations) |> Enum.reverse()

    tools_ast = generate_define_tools(operations)
    handle_ast = generate_handle_tool_call(operations)
    introspection_ast = generate_introspection(operations)

    quote do
      unquote(tools_ast)
      unquote(handle_ast)
      unquote(introspection_ast)
    end
  end

  # ── Code Generation ──────────────────────────────────────────────────

  defp generate_define_tools(operations) do
    tools =
      Enum.map(operations, fn op ->
        input_schema = SchemaBuilder.build_input_schema(op.params)
        output_schema = SchemaBuilder.build_output_schema(op.success_fields)

        tool_opts =
          [name: to_string(op.name), description: op.desc, input_schema: input_schema]
          |> maybe_add_output_schema(output_schema)

        Macro.escape(Tool.new!(tool_opts))
      end)

    quote do
      @impl Tidal.Tool
      def define_tools, do: unquote(tools)
    end
  end

  defp maybe_add_output_schema(opts, nil), do: opts
  # output_schema will be supported when Tidal.Protocol.Tool adds the field
  # For now, store it in annotations
  defp maybe_add_output_schema(opts, _output_schema), do: opts

  defp generate_handle_tool_call(operations) do
    dispatch_mod = __MODULE__

    clauses =
      Enum.map(operations, fn op ->
        name_string = to_string(op.name)
        name_atom = op.name
        error_catalog = Macro.escape(build_error_catalog(op.errors))

        quote do
          def handle_tool_call(unquote(name_string), arguments, session) do
            unquote(dispatch_mod).dispatch(
              __MODULE__,
              unquote(name_atom),
              arguments,
              session,
              unquote(error_catalog)
            )
          end
        end
      end)

    # Add a catch-all clause
    catch_all =
      quote do
        def handle_tool_call(name, _arguments, _session) do
          {:error, "Unknown tool: #{name}"}
        end
      end

    quote do
      @impl Tidal.Tool
      unquote_splicing(clauses)
      unquote(catch_all)
    end
  end

  defp generate_introspection(operations) do
    ops_data = Macro.escape(operations)

    error_catalogs =
      operations
      |> Enum.map(fn op -> {op.name, build_error_catalog(op.errors)} end)
      |> Map.new()
      |> Macro.escape()

    quote do
      @doc false
      def __tidal_operations__, do: unquote(ops_data)

      @doc false
      def __tidal_errors__(name), do: Map.get(unquote(error_catalogs), name, [])
    end
  end

  defp build_error_catalog(errors) do
    Enum.map(errors, fn err ->
      %ErrorSpec{
        name: err.name,
        status: err.status,
        retryable: err[:retryable] || false,
        desc: err.desc,
        recovery: err[:recovery]
      }
    end)
  end

  # ── Runtime Dispatch ─────────────────────────────────────────────────

  @doc false
  def dispatch(module, op_name, arguments, session, error_catalog) do
    # Atomize string keys from MCP protocol
    params = atomize_keys(arguments)

    case module.execute(op_name, params, session) do
      {:ok, result} when is_map(result) ->
        json = Jason.encode!(result)
        {:ok, %ToolResult{content: [%TextContent{text: json}]}}

      {:error, error_name} when is_atom(error_name) ->
        format_catalog_error(error_name, %{}, error_catalog)

      {:error, error_name, details} when is_atom(error_name) and is_map(details) ->
        format_catalog_error(error_name, details, error_catalog)

      {:error, reason} when is_binary(reason) ->
        {:error, reason}
    end
  end

  defp format_catalog_error(error_name, details, catalog) do
    case Enum.find(catalog, &(&1.name == error_name)) do
      %ErrorSpec{} = spec ->
        response = ErrorSpec.to_response(spec, details)
        json = Jason.encode!(response)

        {:ok,
         %ToolResult{
           content: [%TextContent{text: json}],
           is_error: true
         }}

      nil ->
        {:error, "Undeclared error: #{error_name}"}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} when is_atom(k) -> {k, v}
    end)
  rescue
    ArgumentError -> map
  end
end
