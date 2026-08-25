defmodule Tidal.JSONRPC.ErrorCodes do
  @moduledoc """
  Standard JSON-RPC 2.0 error codes as named constants.

  See: https://www.jsonrpc.org/specification#error_object
  """

  @parse_error -32_700
  @invalid_request -32_600
  @method_not_found -32_601
  @invalid_params -32_602
  @internal_error -32_603

  @doc "Returns the JSON-RPC parse error code (`-32700`)."
  defmacro parse_error, do: @parse_error

  @doc "Returns the JSON-RPC invalid request code (`-32600`)."
  defmacro invalid_request, do: @invalid_request

  @doc "Returns the JSON-RPC method-not-found code (`-32601`)."
  defmacro method_not_found, do: @method_not_found

  @doc "Returns the JSON-RPC invalid params code (`-32602`)."
  defmacro invalid_params, do: @invalid_params

  @doc "Returns the JSON-RPC internal error code (`-32603`)."
  defmacro internal_error, do: @internal_error

  @doc "Returns true if the code falls in the server error range (-32000 to -32099)."
  def server_error?(code) when is_integer(code), do: code >= -32_099 and code <= -32_000
  def server_error?(_), do: false

  @doc "Returns a human-readable message for standard error codes."
  def message(@parse_error), do: "Parse error"
  def message(@invalid_request), do: "Invalid Request"
  def message(@method_not_found), do: "Method not found"
  def message(@invalid_params), do: "Invalid params"
  def message(@internal_error), do: "Internal error"
  def message(code) when is_integer(code), do: "Server error"
end
