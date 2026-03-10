defmodule Tidal.Protocol.ResourceTemplate do
  @moduledoc """
  An MCP resource template definition.

  Resource templates use URI templates (RFC 6570) to describe parameterized
  resources that clients can request with specific values.

  ## Fields

    * `:uri_template` — URI template string (required, e.g., `"file:///{path}"`)
    * `:name` — human-readable name (required)
    * `:description` — optional description
    * `:mime_type` — MIME type of the resource content

  """

  @type t :: %__MODULE__{
          uri_template: String.t(),
          name: String.t(),
          description: String.t() | nil,
          mime_type: String.t() | nil
        }

  @enforce_keys [:uri_template, :name]
  defstruct [:uri_template, :name, :description, :mime_type]

  @schema [
    uri_template: [
      type: :string,
      required: true,
      doc: "URI template (RFC 6570) for this resource."
    ],
    name: [
      type: :string,
      required: true,
      doc: "Human-readable name for this resource template."
    ],
    description: [
      type: :string,
      doc: "Optional description of this resource template."
    ],
    mime_type: [
      type: :string,
      doc: "MIME type of the resource content."
    ]
  ]

  @doc """
  Returns the NimbleOptions schema for resource template definitions.
  """
  def schema, do: @schema

  @doc """
  Creates a new ResourceTemplate from a keyword list, validating with NimbleOptions.

  Returns `{:ok, template}` or `{:error, %NimbleOptions.ValidationError{}}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, NimbleOptions.ValidationError.t()}
  def new(opts) when is_list(opts) do
    with {:ok, validated} <- NimbleOptions.validate(opts, @schema) do
      {:ok,
       %__MODULE__{
         uri_template: validated[:uri_template],
         name: validated[:name],
         description: validated[:description],
         mime_type: validated[:mime_type]
       }}
    end
  end

  @doc """
  Serializes the resource template to a map suitable for JSON encoding (MCP wire format).
  """
  @spec to_protocol(t()) :: map()
  def to_protocol(%__MODULE__{} = template) do
    map = %{"uriTemplate" => template.uri_template, "name" => template.name}

    map =
      if template.description, do: Map.put(map, "description", template.description), else: map

    map = if template.mime_type, do: Map.put(map, "mimeType", template.mime_type), else: map
    map
  end
end
