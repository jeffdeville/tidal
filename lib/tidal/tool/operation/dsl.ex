defmodule Tidal.Tool.Operation.DSL do
  @moduledoc false
  # DSL macros available inside `defop` blocks.
  # These accumulate declarations into module attributes that the
  # `defop` macro reads after the block executes.

  @doc "Set the tool description."
  defmacro desc(text) do
    quote do
      Module.put_attribute(__MODULE__, :_tidal_desc, unquote(text))
    end
  end

  @doc "Mark this tool as a mutation (default false)."
  defmacro mutation(value) do
    quote do
      Module.put_attribute(__MODULE__, :_tidal_mutation, unquote(value))
    end
  end

  @doc "Mark this tool as idempotent (default false)."
  defmacro idempotent(value) do
    quote do
      Module.put_attribute(__MODULE__, :_tidal_idempotent, unquote(value))
    end
  end

  @doc "Set agent-facing usage guidance."
  defmacro guidance(text) do
    quote do
      Module.put_attribute(__MODULE__, :_tidal_guidance, unquote(text))
    end
  end

  @doc """
  Declare an input parameter.

  ## Options
  - `:required` — boolean (default false)
  - `:desc` — parameter description
  - `:injected` — if true, excluded from MCP schema (server provides it)
  - `:default` — default value

  ## Nested fields

  For `:map` or `:list` types, pass a `do` block with `field/3` calls:

      param :result, :map, required: true do
        field :summary, :string, required: true, desc: "What was done"
        field :merge_sha, :string, desc: "Git SHA"
      end
  """
  defmacro param(name, type, opts \\ [], do_block \\ nil) do
    {block, opts} = extract_block(do_block, opts)

    quote do
      fields =
        case unquote(block) do
          nil ->
            []

          {:__block__, _, _} = block_ast ->
            # Block with nested fields — collect them
            Module.put_attribute(__MODULE__, :_tidal_nested_fields, [])
            unquote(block)
            Module.get_attribute(__MODULE__, :_tidal_nested_fields) |> Enum.reverse()

          _ ->
            Module.put_attribute(__MODULE__, :_tidal_nested_fields, [])
            unquote(block)
            Module.get_attribute(__MODULE__, :_tidal_nested_fields) |> Enum.reverse()
        end

      opts = unquote(opts)

      param_def = %{
        name: unquote(name),
        type: unquote(type),
        required: Keyword.get(opts, :required, false),
        desc: Keyword.get(opts, :desc),
        injected: Keyword.get(opts, :injected, false),
        default: Keyword.get(opts, :default),
        fields: fields
      }

      Module.put_attribute(
        __MODULE__,
        :_tidal_params,
        [param_def | Module.get_attribute(__MODULE__, :_tidal_params)]
      )
    end
  end

  @doc """
  Declare an output schema for successful responses.

      success do
        field :task_id, :string, desc: "The completed task ID"
        field :verified, :boolean
      end
  """
  defmacro success(do: block) do
    quote do
      Module.put_attribute(__MODULE__, :_tidal_nested_fields, [])
      unquote(block)

      fields = Module.get_attribute(__MODULE__, :_tidal_nested_fields) |> Enum.reverse()
      Module.put_attribute(__MODULE__, :_tidal_success_fields, fields)
    end
  end

  @doc """
  Declare a field inside a `param ... do` or `success do` block.

  ## Options
  - `:required` — boolean (default false)
  - `:desc` — field description
  """
  defmacro field(name, type, opts \\ []) do
    quote do
      opts = unquote(opts)

      field_def = %{
        name: unquote(name),
        type: unquote(type),
        required: Keyword.get(opts, :required, false),
        desc: Keyword.get(opts, :desc),
        fields: []
      }

      Module.put_attribute(
        __MODULE__,
        :_tidal_nested_fields,
        [field_def | Module.get_attribute(__MODULE__, :_tidal_nested_fields)]
      )
    end
  end

  @doc """
  Declare an error in the tool's error catalog.

  ## Examples

      error :not_found, 404, retryable: false, desc: "Resource not found"

      error :rate_limited, 429,
        retryable: true,
        desc: "Too many requests",
        recovery: "Wait 10 seconds and retry."
  """
  defmacro error(name, status, opts) do
    quote do
      opts = unquote(opts)

      error_def = %{
        name: unquote(name),
        status: unquote(status),
        retryable: Keyword.get(opts, :retryable, false),
        desc: Keyword.fetch!(opts, :desc),
        recovery: Keyword.get(opts, :recovery)
      }

      Module.put_attribute(
        __MODULE__,
        :_tidal_errors,
        [error_def | Module.get_attribute(__MODULE__, :_tidal_errors)]
      )
    end
  end

  # Extract do/end block from opts if passed as last keyword
  defp extract_block(nil, opts) do
    case Keyword.pop(opts, :do) do
      {nil, opts} -> {nil, opts}
      {block, opts} -> {block, opts}
    end
  end

  defp extract_block([do: block], opts), do: {block, opts}
  defp extract_block(block, opts) when not is_nil(block), do: {block, opts}
end
