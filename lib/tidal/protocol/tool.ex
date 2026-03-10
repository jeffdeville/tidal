defmodule Tidal.Protocol.Tool do
  @moduledoc """
  Represents an MCP tool definition.

  A tool has a name, optional description, and an optional JSON Schema
  describing its input parameters.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          input_schema: map() | nil
        }

  @enforce_keys [:name]
  defstruct [:name, :description, :input_schema]

  @schema NimbleOptions.new!(
            name: [
              type: :string,
              required: true,
              doc: "The unique name of the tool."
            ],
            description: [
              type: :string,
              doc: "A human-readable description of what the tool does."
            ],
            input_schema: [
              type: {:custom, __MODULE__, :validate_json_schema, []},
              doc: "A JSON Schema map describing the tool's expected input parameters."
            ]
          )

  @doc """
  Validates a tool definition keyword list against the schema.

  Returns `{:ok, %Tool{}}` or `{:error, %NimbleOptions.ValidationError{}}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, NimbleOptions.ValidationError.t()}
  def new(attrs) when is_list(attrs) do
    case NimbleOptions.validate(attrs, @schema) do
      {:ok, validated} ->
        {:ok,
         %__MODULE__{
           name: validated[:name],
           description: validated[:description],
           input_schema: validated[:input_schema]
         }}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Validates and creates a tool definition, raising on failure.
  """
  @spec new!(keyword()) :: t()
  def new!(attrs) when is_list(attrs) do
    case new(attrs) do
      {:ok, tool} -> tool
      {:error, error} -> raise error
    end
  end

  @doc false
  def validate_json_schema(value) when is_map(value), do: {:ok, value}
  def validate_json_schema(_value), do: {:error, "expected a map (JSON Schema)"}

  @doc """
  Serializes a Tool struct to a JSON-compatible map for the MCP protocol.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = tool) do
    map = %{"name" => tool.name}

    map =
      if tool.description do
        Map.put(map, "description", tool.description)
      else
        map
      end

    if tool.input_schema do
      Map.put(map, "inputSchema", tool.input_schema)
    else
      map
    end
  end
end
