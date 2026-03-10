defmodule Tidal.JSONRPC do
  @moduledoc """
  JSON-RPC 2.0 message encoding and decoding.

  Provides `encode/1` and `decode/1` for converting between Elixir structs
  and JSON strings, with full support for batch messages.

  All message types are represented as structs:

  - `Tidal.JSONRPC.Request` — a request with an `id`
  - `Tidal.JSONRPC.Notification` — a request without an `id`
  - `Tidal.JSONRPC.Response` — a success response
  - `Tidal.JSONRPC.Error` — an error response

  ## Error Codes

  Standard error codes are available as compile-time constants via
  `Tidal.JSONRPC.ErrorCodes`:

      require Tidal.JSONRPC.ErrorCodes
      Tidal.JSONRPC.ErrorCodes.parse_error()   # -32700
      Tidal.JSONRPC.ErrorCodes.internal_error() # -32603
  """

  alias Tidal.JSONRPC.{Error, Notification, Request, Response}

  require Tidal.JSONRPC.ErrorCodes, as: ErrorCodes

  @doc """
  Encodes a JSON-RPC 2.0 message struct (or list of structs) to a JSON string.

  Returns `{:ok, json}` or `{:error, reason}`.
  """
  @spec encode(struct() | [struct()]) :: {:ok, String.t()} | {:error, String.t()}
  def encode(messages) when is_list(messages) do
    if Enum.all?(messages, &jsonrpc_struct?/1) do
      Jason.encode(messages)
    else
      {:error, "all batch items must be JSON-RPC message structs"}
    end
  end

  def encode(%mod{} = message) when mod in [Request, Notification, Response, Error] do
    Jason.encode(message)
  end

  def encode(_), do: {:error, "expected a JSON-RPC message struct or list of structs"}

  @doc """
  Decodes a JSON string into JSON-RPC 2.0 message struct(s).

  Returns `{:ok, struct_or_list}` or `{:error, error_struct}`.

  For batch messages (JSON arrays), returns a list of decoded messages.
  Individual items that fail validation are returned as `Tidal.JSONRPC.Error` structs.
  """
  @spec decode(String.t()) ::
          {:ok, struct() | [struct()]} | {:error, Error.t()}
  def decode(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, list} when is_list(list) ->
        decode_batch(list)

      {:ok, map} when is_map(map) ->
        decode_single(map)

      {:ok, _} ->
        {:error, parse_error_struct("top-level value must be an object or array")}

      {:error, %Jason.DecodeError{} = err} ->
        {:error, parse_error_struct(Exception.message(err))}
    end
  end

  def decode(_), do: {:error, parse_error_struct("input must be a string")}

  defp decode_batch([]) do
    {:error, invalid_request_error_struct(nil, "batch must not be empty")}
  end

  defp decode_batch(items) do
    results = Enum.map(items, &decode_batch_item/1)
    {:ok, results}
  end

  defp decode_batch_item(item) when is_map(item) do
    case decode_single(item) do
      {:ok, msg} -> msg
      {:error, err} -> err
    end
  end

  defp decode_batch_item(_) do
    invalid_request_error_struct(nil, "batch item must be an object")
  end

  defp decode_single(%{"jsonrpc" => "2.0"} = map) do
    cond do
      Map.has_key?(map, "method") and Map.has_key?(map, "id") ->
        decode_request(map)

      Map.has_key?(map, "method") ->
        decode_notification(map)

      Map.has_key?(map, "error") ->
        decode_error_response(map)

      Map.has_key?(map, "result") or (Map.has_key?(map, "id") and not Map.has_key?(map, "error")) ->
        decode_response(map)

      true ->
        id = Map.get(map, "id")
        {:error, invalid_request_error_struct(id, "unable to determine message type")}
    end
  end

  defp decode_single(%{"jsonrpc" => version}) when version != "2.0" do
    {:error,
     invalid_request_error_struct(nil, "unsupported jsonrpc version: #{inspect(version)}")}
  end

  defp decode_single(map) when is_map(map) do
    {:error, invalid_request_error_struct(Map.get(map, "id"), "missing required field: jsonrpc")}
  end

  defp decode_request(map) do
    Request.new(%{
      id: Map.get(map, "id"),
      method: Map.get(map, "method"),
      params: Map.get(map, "params")
    })
    |> wrap_decode_error(Map.get(map, "id"))
  end

  defp decode_notification(map) do
    Notification.new(%{
      method: Map.get(map, "method"),
      params: Map.get(map, "params")
    })
    |> wrap_decode_error(nil)
  end

  defp decode_response(map) do
    Response.new(%{
      id: Map.get(map, "id"),
      result: Map.get(map, "result")
    })
    |> wrap_decode_error(Map.get(map, "id"))
  end

  defp decode_error_response(%{"error" => error_map, "id" => id}) when is_map(error_map) do
    Error.new(%{
      id: id,
      code: Map.get(error_map, "code"),
      message: Map.get(error_map, "message"),
      data: Map.get(error_map, "data")
    })
    |> wrap_decode_error(id)
  end

  defp decode_error_response(%{"error" => _, "id" => id}) do
    {:error, invalid_request_error_struct(id, "error field must be an object")}
  end

  defp decode_error_response(%{"error" => error_map}) when is_map(error_map) do
    decode_error_response(%{"error" => error_map, "id" => nil})
  end

  defp decode_error_response(_) do
    {:error, invalid_request_error_struct(nil, "error response missing id")}
  end

  defp wrap_decode_error({:ok, _} = ok, _id), do: ok

  defp wrap_decode_error({:error, reason}, id) do
    {:error, invalid_request_error_struct(id, reason)}
  end

  defp parse_error_struct(detail) do
    %Error{
      id: nil,
      code: ErrorCodes.parse_error(),
      message: "Parse error",
      data: detail
    }
  end

  defp invalid_request_error_struct(id, detail) do
    %Error{
      id: id,
      code: ErrorCodes.invalid_request(),
      message: "Invalid Request",
      data: detail
    }
  end

  defp jsonrpc_struct?(%mod{}) when mod in [Request, Notification, Response, Error], do: true
  defp jsonrpc_struct?(_), do: false
end
