defmodule Tidal.Transport.V20260728.ToolHeaderSchema do
  @moduledoc false

  alias Tidal.Protocol.Tool

  @primitive_types ["string", "integer", "boolean"]
  @field_name ~r/^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$/

  @spec validate!(Tool.t()) :: :ok
  def validate!(%Tool{input_schema: nil}), do: :ok

  def validate!(%Tool{name: tool_name, input_schema: schema}) do
    annotations = collect(schema, false, true, [])

    case Enum.find(annotations, &match?({:error, _reason}, &1)) do
      {:error, reason} ->
        raise ArgumentError, "tool #{inspect(tool_name)} has invalid x-mcp-header: #{reason}"

      nil ->
        validate_unique!(tool_name, Enum.map(annotations, fn {:ok, name} -> name end))
    end
  end

  defp collect(map, annotation_allowed?, properties_reachable?, path) when is_map(map) do
    current = validate_current(map, annotation_allowed?, path)

    descendants =
      Enum.flat_map(map, fn
        {"properties", properties} when is_map(properties) ->
          Enum.flat_map(properties, fn {property, schema} ->
            collect(
              schema,
              properties_reachable?,
              properties_reachable?,
              path ++ ["properties", property]
            )
          end)

        {"x-mcp-header", _value} ->
          []

        {keyword, value} ->
          collect(value, false, false, path ++ [to_string(keyword)])
      end)

    current ++ descendants
  end

  defp collect(list, _annotation_allowed?, _properties_reachable?, path) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.flat_map(fn {value, index} -> collect(value, false, false, path ++ [index]) end)
  end

  defp collect(_value, _annotation_allowed?, _properties_reachable?, _path), do: []

  defp validate_current(%{"x-mcp-header" => _name}, false, path) do
    [{:error, "annotation at #{format_path(path)} is not reachable through properties"}]
  end

  defp validate_current(%{"x-mcp-header" => name, "type" => type}, true, path)
       when is_binary(name) and name != "" and type in @primitive_types do
    if Regex.match?(@field_name, name) do
      [{:ok, String.downcase(name)}]
    else
      [{:error, "#{inspect(name)} at #{format_path(path)} is not a valid HTTP field name"}]
    end
  end

  defp validate_current(%{"x-mcp-header" => name}, true, path) do
    [
      {:error, "#{inspect(name)} at #{format_path(path)} must name a string, integer, or boolean property"}
    ]
  end

  defp validate_current(_schema, _annotation_allowed?, _path), do: []

  defp validate_unique!(tool_name, names) do
    case names -- Enum.uniq(names) do
      [duplicate | _] ->
        raise ArgumentError,
              "tool #{inspect(tool_name)} has duplicate x-mcp-header name #{inspect(duplicate)}"

      [] ->
        :ok
    end
  end

  defp format_path([]), do: "schema root"
  defp format_path(path), do: Enum.join(path, ".")
end
