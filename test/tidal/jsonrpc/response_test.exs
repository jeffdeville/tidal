defmodule Tidal.JSONRPC.ResponseTest do
  use ExUnit.Case, async: true

  alias Tidal.JSONRPC.Response

  describe "new/1" do
    test "creates a valid response" do
      assert {:ok, %Response{id: "1", result: "ok", jsonrpc: "2.0"}} =
               Response.new(%{id: "1", result: "ok"})
    end

    test "creates a response with complex result" do
      result = %{"data" => [1, 2, 3]}

      assert {:ok, %Response{result: ^result}} =
               Response.new(%{id: 1, result: result})
    end

    test "accepts string keys" do
      assert {:ok, %Response{id: "1", result: nil}} =
               Response.new(%{"id" => "1", "result" => nil})
    end

    test "returns error for missing id" do
      assert {:error, "missing required field: id"} = Response.new(%{result: "ok"})
    end

    test "returns error for missing result" do
      assert {:error, "missing required field: result"} = Response.new(%{id: "1"})
    end

    test "returns error for non-map input" do
      assert {:error, "response must be a map"} = Response.new([])
    end
  end

  describe "Jason.Encoder" do
    test "encodes response" do
      response = %Response{id: "1", result: %{"status" => "ok"}}
      assert {:ok, json} = Jason.encode(response)
      decoded = Jason.decode!(json)
      assert decoded == %{"jsonrpc" => "2.0", "id" => "1", "result" => %{"status" => "ok"}}
    end

    test "encodes response with null result" do
      response = %Response{id: 1, result: nil}
      assert {:ok, json} = Jason.encode(response)
      decoded = Jason.decode!(json)
      assert decoded["result"] == nil
      assert decoded["id"] == 1
    end
  end
end
