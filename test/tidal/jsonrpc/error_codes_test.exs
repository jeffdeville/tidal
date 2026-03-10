defmodule Tidal.JSONRPC.ErrorCodesTest do
  use ExUnit.Case, async: true

  require Tidal.JSONRPC.ErrorCodes, as: ErrorCodes

  describe "standard error codes" do
    test "parse_error is -32700" do
      assert ErrorCodes.parse_error() == -32_700
    end

    test "invalid_request is -32600" do
      assert ErrorCodes.invalid_request() == -32_600
    end

    test "method_not_found is -32601" do
      assert ErrorCodes.method_not_found() == -32_601
    end

    test "invalid_params is -32602" do
      assert ErrorCodes.invalid_params() == -32_602
    end

    test "internal_error is -32603" do
      assert ErrorCodes.internal_error() == -32_603
    end
  end

  describe "server_error?/1" do
    test "returns true for codes in -32000 to -32099 range" do
      assert ErrorCodes.server_error?(-32_000)
      assert ErrorCodes.server_error?(-32_050)
      assert ErrorCodes.server_error?(-32_099)
    end

    test "returns false for standard error codes" do
      refute ErrorCodes.server_error?(-32_700)
      refute ErrorCodes.server_error?(-32_600)
    end

    test "returns false for non-integer values" do
      refute ErrorCodes.server_error?("error")
    end
  end

  describe "message/1" do
    test "returns human-readable message for standard codes" do
      assert ErrorCodes.message(-32_700) == "Parse error"
      assert ErrorCodes.message(-32_600) == "Invalid Request"
      assert ErrorCodes.message(-32_601) == "Method not found"
      assert ErrorCodes.message(-32_602) == "Invalid params"
      assert ErrorCodes.message(-32_603) == "Internal error"
    end

    test "returns generic message for unknown codes" do
      assert ErrorCodes.message(-32_050) == "Server error"
    end
  end
end
