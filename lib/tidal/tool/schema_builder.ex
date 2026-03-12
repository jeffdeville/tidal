defmodule Tidal.Tool.SchemaBuilder do
  @moduledoc """
  Converts `defop` param and success declarations into JSON Schema maps.

  This is the bridge between the ergonomic Elixir DSL and the JSON Schema
  format required by the MCP protocol's `inputSchema` and `outputSchema` fields.
  """

  @doc """
  Builds a JSON Schema object from a list of param definitions.

  Each param is a map with keys: `:name`, `:type`, `:required`, `:desc`, `:fields` (nested).

  Returns a JSON Schema map with "type" => "object", "properties", and "required".
  """
  @spec build_input_schema([map()]) :: map()
  def build_input_schema(params) do
    # Exclude injected params — they don't appear in the MCP schema
    visible_params = Enum.reject(params, & &1[:injected])
    build_object_schema(visible_params)
  end

  @doc """
  Builds a JSON Schema object from a list of success field definitions.

  Same format as params but simpler (no injected, no nested blocks typically).
  """
  @spec build_output_schema([map()]) :: map() | nil
  def build_output_schema([]), do: nil

  def build_output_schema(fields) do
    build_object_schema(fields)
  end

  # ── Internals ──────────────────────────────────────────────────────

  defp build_object_schema(fields) do
    properties =
      fields
      |> Enum.map(fn field -> {to_string(field.name), field_to_schema(field)} end)
      |> Map.new()

    required =
      fields
      |> Enum.filter(& &1[:required])
      |> Enum.map(&to_string(&1.name))

    %{"type" => "object", "properties" => properties}
    |> maybe_put_required(required)
  end

  defp maybe_put_required(schema, []), do: schema
  defp maybe_put_required(schema, required), do: Map.put(schema, "required", required)

  defp field_to_schema(field) do
    base = type_to_schema(field.type, field[:fields])

    if field[:desc] do
      Map.put(base, "description", field.desc)
    else
      base
    end
  end

  defp type_to_schema(:string, _fields), do: %{"type" => "string"}
  defp type_to_schema(:integer, _fields), do: %{"type" => "integer"}
  defp type_to_schema(:number, _fields), do: %{"type" => "number"}
  defp type_to_schema(:boolean, _fields), do: %{"type" => "boolean"}

  defp type_to_schema({:enum, values}, _fields) do
    %{"type" => "string", "enum" => Enum.map(values, &to_string/1)}
  end

  defp type_to_schema(:map, fields) when is_list(fields) and fields != [] do
    build_object_schema(fields)
  end

  defp type_to_schema(:map, _fields), do: %{"type" => "object"}

  defp type_to_schema(:list, fields) when is_list(fields) and fields != [] do
    %{"type" => "array", "items" => build_object_schema(fields)}
  end

  defp type_to_schema(:list, _fields), do: %{"type" => "array"}

  defp type_to_schema(other, _fields) do
    raise ArgumentError, "Unknown param type: #{inspect(other)}"
  end
end
