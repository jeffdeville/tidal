defmodule Tidal.JSONRPC.Error do
  @moduledoc """
  A JSON-RPC 2.0 error response object.

  Required: `id`, `code`, `message`.
  Optional: `data`.
  The `jsonrpc` field is always "2.0".
  """

  @type t :: %__MODULE__{
          jsonrpc: String.t(),
          id: String.t() | integer() | nil,
          code: integer(),
          message: String.t(),
          data: term()
        }

  @enforce_keys [:id, :code, :message]
  defstruct jsonrpc: "2.0", id: nil, code: nil, message: nil, data: nil

  @doc "Creates a new Error, returning `{:ok, error}` or `{:error, reason}`."
  def new(attrs) when is_map(attrs) do
    with {:ok, id} <- validate_id(attrs),
         {:ok, code} <- validate_code(attrs),
         {:ok, message} <- validate_message(attrs),
         {:ok, data} <- validate_data(attrs) do
      {:ok, %__MODULE__{id: id, code: code, message: message, data: data}}
    end
  end

  def new(_), do: {:error, "error response must be a map"}

  # id can be nil for parse errors where the request id is unknown
  defp validate_id(%{id: nil}), do: {:ok, nil}
  defp validate_id(%{id: id}) when is_binary(id) and id != "", do: {:ok, id}
  defp validate_id(%{id: id}) when is_integer(id), do: {:ok, id}
  defp validate_id(%{id: _}), do: {:error, "id must be a non-empty string, integer, or nil"}
  defp validate_id(%{"id" => id}), do: validate_id(%{id: id})
  defp validate_id(_), do: {:error, "missing required field: id"}

  defp validate_code(%{code: code}) when is_integer(code), do: {:ok, code}
  defp validate_code(%{code: _}), do: {:error, "code must be an integer"}
  defp validate_code(%{"code" => code}), do: validate_code(%{code: code})
  defp validate_code(_), do: {:error, "missing required field: code"}

  defp validate_message(%{message: msg}) when is_binary(msg), do: {:ok, msg}
  defp validate_message(%{message: _}), do: {:error, "message must be a string"}
  defp validate_message(%{"message" => msg}), do: validate_message(%{message: msg})
  defp validate_message(_), do: {:error, "missing required field: message"}

  defp validate_data(%{data: data}), do: {:ok, data}
  defp validate_data(%{"data" => data}), do: {:ok, data}
  defp validate_data(_), do: {:ok, nil}

  defimpl Jason.Encoder do
    def encode(%{id: id, code: code, message: message, data: data}, opts) do
      error_obj = %{"code" => code, "message" => message}
      error_obj = if data != nil, do: Map.put(error_obj, "data", data), else: error_obj

      Jason.Encode.map(%{"jsonrpc" => "2.0", "id" => id, "error" => error_obj}, opts)
    end
  end
end
