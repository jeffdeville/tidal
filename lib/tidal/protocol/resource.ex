defmodule Tidal.Protocol.Resource do
  @moduledoc """
  An MCP resource definition.

  Resources represent data that an MCP server makes available to clients,
  such as file contents, database records, or API responses.

  ## Fields

    * `:uri` — unique identifier for this resource (required)
    * `:name` — human-readable name (required)
    * `:description` — optional description
    * `:mime_type` — MIME type of the resource content (e.g., `"text/plain"`)

  """

  @type t :: %__MODULE__{
          uri: String.t(),
          name: String.t(),
          description: String.t() | nil,
          mime_type: String.t() | nil
        }

  @enforce_keys [:uri, :name]
  defstruct [:uri, :name, :description, :mime_type]

  @schema [
    uri: [
      type: :string,
      required: true,
      doc: "Unique URI identifying this resource."
    ],
    name: [
      type: :string,
      required: true,
      doc: "Human-readable name for this resource."
    ],
    description: [
      type: :string,
      doc: "Optional description of this resource."
    ],
    mime_type: [
      type: :string,
      doc: "MIME type of the resource content (e.g., \"text/plain\")."
    ]
  ]

  @doc """
  Returns the NimbleOptions schema for resource definitions.
  """
  def schema, do: @schema

  @doc """
  Creates a new Resource from a keyword list, validating with NimbleOptions.

  Returns `{:ok, resource}` or `{:error, %NimbleOptions.ValidationError{}}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, NimbleOptions.ValidationError.t()}
  def new(opts) when is_list(opts) do
    with {:ok, validated} <- NimbleOptions.validate(opts, @schema) do
      {:ok,
       %__MODULE__{
         uri: validated[:uri],
         name: validated[:name],
         description: validated[:description],
         mime_type: validated[:mime_type]
       }}
    end
  end

  @doc """
  Serializes the resource to a map suitable for JSON encoding (MCP wire format).
  """
  @spec to_protocol(t()) :: map()
  def to_protocol(%__MODULE__{} = resource) do
    map = %{"uri" => resource.uri, "name" => resource.name}

    map =
      if resource.description, do: Map.put(map, "description", resource.description), else: map

    map = if resource.mime_type, do: Map.put(map, "mimeType", resource.mime_type), else: map
    map
  end
end
