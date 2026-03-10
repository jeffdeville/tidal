defmodule Tidal.JSONRPC.Response do
  @moduledoc """
  A JSON-RPC 2.0 success response object.

  Required: `id`, `result`.
  The `jsonrpc` field is always "2.0".
  """

  @type t :: %__MODULE__{
          jsonrpc: String.t(),
          id: String.t() | integer(),
          result: term()
        }

  @enforce_keys [:id, :result]
  defstruct jsonrpc: "2.0", id: nil, result: nil

  @doc "Creates a new Response, returning `{:ok, response}` or `{:error, reason}`."
  def new(attrs) when is_map(attrs) do
    with {:ok, id} <- validate_id(attrs),
         {:ok, result} <- validate_result(attrs) do
      {:ok, %__MODULE__{id: id, result: result}}
    end
  end

  def new(_), do: {:error, "response must be a map"}

  defp validate_id(%{id: id}) when is_binary(id) and id != "", do: {:ok, id}
  defp validate_id(%{id: id}) when is_integer(id), do: {:ok, id}
  defp validate_id(%{id: _}), do: {:error, "id must be a non-empty string or integer"}
  defp validate_id(%{"id" => id}), do: validate_id(%{id: id})
  defp validate_id(_), do: {:error, "missing required field: id"}

  defp validate_result(%{result: result}), do: {:ok, result}
  defp validate_result(%{"result" => result}), do: {:ok, result}
  defp validate_result(_), do: {:error, "missing required field: result"}

  defimpl Jason.Encoder do
    def encode(%{id: id, result: result}, opts) do
      Jason.Encode.map(%{"jsonrpc" => "2.0", "id" => id, "result" => result}, opts)
    end
  end
end
