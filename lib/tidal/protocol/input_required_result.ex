defmodule Tidal.Protocol.InputRequiredResult do
  @moduledoc """
  A multi-round-trip result asking the client for additional input.

  The client retries the original request with the returned `requestState` and
  its collected `inputResponses`. No server-side client session is required.

  `input_requests` is keyed by an application-chosen ID. Each value contains an
  MCP client-request `method` and `params`; the client uses the same ID in its
  retry's `inputResponses` map.
  """

  defstruct [:input_requests, :request_state]

  @type t :: %__MODULE__{
          input_requests: map() | nil,
          request_state: String.t() | nil
        }

  @doc """
  Builds an input-required result.

  At least one of `:input_requests` or `:request_state` is required.
  `:input_requests`, when present, must be a map and `:request_state` must be a
  string. Invalid options raise `ArgumentError`.

      Tidal.Protocol.InputRequiredResult.new!(
        input_requests: %{
          "confirmation" => %{
            "method" => "elicitation/create",
            "params" => %{"message" => "Continue?"}
          }
        },
        request_state: token
      )
  """
  @spec new!(keyword()) :: t()
  def new!(opts) when is_list(opts) do
    input_requests = Keyword.get(opts, :input_requests)
    request_state = Keyword.get(opts, :request_state)

    unless is_nil(input_requests) or is_map(input_requests) do
      raise ArgumentError, "input_requests must be a map or nil"
    end

    unless is_nil(request_state) or is_binary(request_state) do
      raise ArgumentError, "request_state must be a string or nil"
    end

    if is_nil(input_requests) and is_nil(request_state) do
      raise ArgumentError, "at least one of input_requests or request_state is required"
    end

    %__MODULE__{input_requests: input_requests, request_state: request_state}
  end

  @doc """
  Serializes the result to its JSON-compatible MCP wire representation.

  The returned map always contains `"resultType" => "input_required"` and
  includes only the optional fields present in the struct.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = result) do
    %{"resultType" => "input_required"}
    |> maybe_put("inputRequests", result.input_requests)
    |> maybe_put("requestState", result.request_state)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
