defmodule Tidal.JSONRPC.ErrorTest do
  use ExUnit.Case, async: true

  alias Tidal.JSONRPC.Error

  describe "new/1" do
    test "creates a valid error" do
      assert {:ok, %Error{id: "1", code: -32_600, message: "Invalid Request", jsonrpc: "2.0"}} =
               Error.new(%{id: "1", code: -32_600, message: "Invalid Request"})
    end

    test "creates an error with nil id (parse error scenario)" do
      assert {:ok, %Error{id: nil, code: -32_700, message: "Parse error"}} =
               Error.new(%{id: nil, code: -32_700, message: "Parse error"})
    end

    test "creates an error with data" do
      assert {:ok, %Error{data: "extra info"}} =
               Error.new(%{id: "1", code: -32_603, message: "Internal error", data: "extra info"})
    end

    test "accepts string keys" do
      assert {:ok, %Error{id: "1", code: -32_600}} =
               Error.new(%{"id" => "1", "code" => -32_600, "message" => "Invalid Request"})
    end

    test "returns error for missing id" do
      assert {:error, "missing required field: id"} =
               Error.new(%{code: -32_600, message: "err"})
    end

    test "returns error for missing code" do
      assert {:error, "missing required field: code"} =
               Error.new(%{id: "1", message: "err"})
    end

    test "returns error for missing message" do
      assert {:error, "missing required field: message"} =
               Error.new(%{id: "1", code: -32_600})
    end

    test "returns error for non-integer code" do
      assert {:error, "code must be an integer"} =
               Error.new(%{id: "1", code: "bad", message: "err"})
    end

    test "returns error for non-map input" do
      assert {:error, "error response must be a map"} = Error.new("bad")
    end
  end

  describe "Jason.Encoder" do
    test "encodes error without data" do
      error = %Error{id: "1", code: -32_600, message: "Invalid Request"}
      assert {:ok, json} = Jason.encode(error)
      decoded = Jason.decode!(json)

      assert decoded == %{
               "jsonrpc" => "2.0",
               "id" => "1",
               "error" => %{"code" => -32_600, "message" => "Invalid Request"}
             }
    end

    test "encodes error with data" do
      error = %Error{id: nil, code: -32_700, message: "Parse error", data: "details"}
      assert {:ok, json} = Jason.encode(error)
      decoded = Jason.decode!(json)
      assert decoded["error"]["data"] == "details"
      assert decoded["id"] == nil
    end
  end
end
