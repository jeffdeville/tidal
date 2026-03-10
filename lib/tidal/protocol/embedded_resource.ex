defmodule Tidal.Protocol.EmbeddedResource do
  @moduledoc """
  Represents an embedded resource in a tool result.

  Corresponds to the MCP `EmbeddedResource` content type.
  """

  @type t :: %__MODULE__{
          type: String.t(),
          resource: map()
        }

  @enforce_keys [:resource]
  defstruct type: "resource", resource: nil

  @doc """
  Serializes an EmbeddedResource struct to a JSON-compatible map.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = content) do
    %{"type" => content.type, "resource" => content.resource}
  end
end
