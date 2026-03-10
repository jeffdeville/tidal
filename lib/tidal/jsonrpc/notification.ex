defmodule Tidal.JSONRPC.Notification do
  @moduledoc """
  A JSON-RPC 2.0 notification (a request without an `id`).

  Required: `method`.
  Optional: `params`.
  The `jsonrpc` field is always "2.0".
  """

  @type t :: %__MODULE__{
          jsonrpc: String.t(),
          method: String.t(),
          params: map() | list() | nil
        }

  @enforce_keys [:method]
  defstruct jsonrpc: "2.0", method: nil, params: nil

  @doc "Creates a new Notification, returning `{:ok, notification}` or `{:error, reason}`."
  def new(attrs) when is_map(attrs) do
    with {:ok, method} <- validate_method(attrs),
         {:ok, params} <- validate_params(attrs) do
      {:ok, %__MODULE__{method: method, params: params}}
    end
  end

  def new(_), do: {:error, "notification must be a map"}

  defp validate_method(%{method: method}) when is_binary(method) and method != "",
    do: {:ok, method}

  defp validate_method(%{method: _}), do: {:error, "method must be a non-empty string"}
  defp validate_method(%{"method" => method}), do: validate_method(%{method: method})
  defp validate_method(_), do: {:error, "missing required field: method"}

  defp validate_params(%{params: params}) when is_map(params) or is_list(params),
    do: {:ok, params}

  defp validate_params(%{params: nil}), do: {:ok, nil}
  defp validate_params(%{params: _}), do: {:error, "params must be a map, list, or nil"}
  defp validate_params(%{"params" => params}), do: validate_params(%{params: params})
  defp validate_params(_), do: {:ok, nil}

  defimpl Jason.Encoder do
    def encode(%{method: method, params: params}, opts) do
      map = %{"jsonrpc" => "2.0", "method" => method}
      map = if params != nil, do: Map.put(map, "params", params), else: map
      Jason.Encode.map(map, opts)
    end
  end
end
