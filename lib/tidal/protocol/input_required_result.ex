defmodule Tidal.Protocol.InputRequiredResult do
  @moduledoc """
  A multi-round-trip result asking the client for additional input.

  The client retries the original request with the returned `requestState` and
  its collected `inputResponses`. No server-side client session is required.
  """

  defstruct [:input_requests, :request_state]

  @type t :: %__MODULE__{
          input_requests: map() | nil,
          request_state: String.t() | nil
        }

  @doc "Builds a result, raising for malformed input requests or request state."
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

  @doc "Serializes the result to the MCP wire representation."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = result) do
    %{"resultType" => "input_required"}
    |> maybe_put("inputRequests", result.input_requests)
    |> maybe_put("requestState", result.request_state)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
