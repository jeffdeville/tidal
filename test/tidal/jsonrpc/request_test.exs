defmodule Tidal.JSONRPC.RequestTest do
  use ExUnit.Case, async: true

  alias Tidal.JSONRPC.Request

  describe "new/1" do
    test "creates a valid request with string id" do
      assert {:ok, %Request{id: "1", method: "test", params: nil, jsonrpc: "2.0"}} =
               Request.new(%{id: "1", method: "test"})
    end

    test "creates a valid request with integer id" do
      assert {:ok, %Request{id: 1, method: "test"}} =
               Request.new(%{id: 1, method: "test"})
    end

    test "creates a request with map params" do
      assert {:ok, %Request{params: %{"key" => "value"}}} =
               Request.new(%{id: "1", method: "test", params: %{"key" => "value"}})
    end

    test "creates a request with list params" do
      assert {:ok, %Request{params: [1, 2, 3]}} =
               Request.new(%{id: "1", method: "test", params: [1, 2, 3]})
    end

    test "accepts string keys" do
      assert {:ok, %Request{id: "1", method: "test"}} =
               Request.new(%{"id" => "1", "method" => "test"})
    end

    test "returns error for missing id" do
      assert {:error, "missing required field: id"} = Request.new(%{method: "test"})
    end

    test "returns error for missing method" do
      assert {:error, "missing required field: method"} = Request.new(%{id: "1"})
    end

    test "returns error for empty string id" do
      assert {:error, "id must be a non-empty string or integer"} =
               Request.new(%{id: "", method: "test"})
    end

    test "returns error for empty string method" do
      assert {:error, "method must be a non-empty string"} =
               Request.new(%{id: "1", method: ""})
    end

    test "returns error for invalid params type" do
      assert {:error, "params must be a map, list, or nil"} =
               Request.new(%{id: "1", method: "test", params: "invalid"})
    end

    test "returns error for non-map input" do
      assert {:error, "request must be a map"} = Request.new("not a map")
    end
  end

  describe "Jason.Encoder" do
    test "encodes request without params" do
      request = %Request{id: "1", method: "test"}
      assert {:ok, json} = Jason.encode(request)
      assert %{"jsonrpc" => "2.0", "id" => "1", "method" => "test"} = Jason.decode!(json)
      refute Map.has_key?(Jason.decode!(json), "params")
    end

    test "encodes request with params" do
      request = %Request{id: 1, method: "test", params: %{"a" => 1}}
      assert {:ok, json} = Jason.encode(request)
      decoded = Jason.decode!(json)
      assert decoded["params"] == %{"a" => 1}
    end
  end
end
