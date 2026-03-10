defmodule Tidal.JSONRPCTest do
  use ExUnit.Case, async: true

  alias Tidal.JSONRPC
  alias Tidal.JSONRPC.{Error, Notification, Request, Response}

  describe "encode/1" do
    test "encodes a request" do
      {:ok, req} = Request.new(%{id: "1", method: "test", params: %{"a" => 1}})
      assert {:ok, json} = JSONRPC.encode(req)
      decoded = Jason.decode!(json)
      assert decoded["jsonrpc"] == "2.0"
      assert decoded["id"] == "1"
      assert decoded["method"] == "test"
      assert decoded["params"] == %{"a" => 1}
    end

    test "encodes a notification" do
      {:ok, notif} = Notification.new(%{method: "update"})
      assert {:ok, json} = JSONRPC.encode(notif)
      decoded = Jason.decode!(json)
      assert decoded["method"] == "update"
      refute Map.has_key?(decoded, "id")
    end

    test "encodes a response" do
      {:ok, resp} = Response.new(%{id: "1", result: %{"status" => "ok"}})
      assert {:ok, json} = JSONRPC.encode(resp)
      decoded = Jason.decode!(json)
      assert decoded["result"] == %{"status" => "ok"}
    end

    test "encodes an error" do
      {:ok, err} = Error.new(%{id: "1", code: -32_600, message: "Invalid Request"})
      assert {:ok, json} = JSONRPC.encode(err)
      decoded = Jason.decode!(json)
      assert decoded["error"]["code"] == -32_600
    end

    test "encodes a batch of messages" do
      {:ok, req} = Request.new(%{id: "1", method: "foo"})
      {:ok, notif} = Notification.new(%{method: "bar"})
      assert {:ok, json} = JSONRPC.encode([req, notif])
      decoded = Jason.decode!(json)
      assert length(decoded) == 2
    end

    test "rejects non-struct input" do
      assert {:error, _} = JSONRPC.encode(%{"method" => "test"})
    end

    test "rejects batch with non-struct items" do
      assert {:error, _} = JSONRPC.encode([%{"method" => "test"}])
    end
  end

  describe "decode/1 - requests" do
    test "decodes a valid request" do
      json = ~s({"jsonrpc":"2.0","id":"1","method":"test","params":{"a":1}})

      assert {:ok, %Request{id: "1", method: "test", params: %{"a" => 1}}} =
               JSONRPC.decode(json)
    end

    test "decodes a request without params" do
      json = ~s({"jsonrpc":"2.0","id":1,"method":"test"})
      assert {:ok, %Request{id: 1, method: "test", params: nil}} = JSONRPC.decode(json)
    end
  end

  describe "decode/1 - notifications" do
    test "decodes a valid notification" do
      json = ~s({"jsonrpc":"2.0","method":"update","params":[1,2]})

      assert {:ok, %Notification{method: "update", params: [1, 2]}} =
               JSONRPC.decode(json)
    end

    test "decodes a notification without params" do
      json = ~s({"jsonrpc":"2.0","method":"cancel"})
      assert {:ok, %Notification{method: "cancel", params: nil}} = JSONRPC.decode(json)
    end
  end

  describe "decode/1 - responses" do
    test "decodes a success response" do
      json = ~s({"jsonrpc":"2.0","id":"1","result":{"status":"ok"}})

      assert {:ok, %Response{id: "1", result: %{"status" => "ok"}}} =
               JSONRPC.decode(json)
    end

    test "decodes a response with null result" do
      json = ~s({"jsonrpc":"2.0","id":"1","result":null})
      assert {:ok, %Response{id: "1", result: nil}} = JSONRPC.decode(json)
    end
  end

  describe "decode/1 - errors" do
    test "decodes an error response" do
      json = ~s({"jsonrpc":"2.0","id":"1","error":{"code":-32600,"message":"Invalid Request"}})

      assert {:ok, %Error{id: "1", code: -32_600, message: "Invalid Request"}} =
               JSONRPC.decode(json)
    end

    test "decodes an error response with data" do
      json =
        ~s({"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"Parse error","data":"unexpected token"}})

      assert {:ok, %Error{id: nil, code: -32_700, data: "unexpected token"}} =
               JSONRPC.decode(json)
    end
  end

  describe "decode/1 - batches" do
    test "decodes a batch of requests" do
      json =
        ~s([{"jsonrpc":"2.0","id":"1","method":"foo"},{"jsonrpc":"2.0","id":"2","method":"bar"}])

      assert {:ok, [%Request{id: "1"}, %Request{id: "2"}]} = JSONRPC.decode(json)
    end

    test "decodes a mixed batch" do
      json =
        ~s([{"jsonrpc":"2.0","id":"1","method":"foo"},{"jsonrpc":"2.0","method":"notify"},{"jsonrpc":"2.0","id":"2","result":"ok"}])

      assert {:ok, [%Request{}, %Notification{}, %Response{}]} = JSONRPC.decode(json)
    end

    test "invalid items in batch become error structs" do
      json = ~s([{"jsonrpc":"2.0","id":"1","method":"foo"},{"bad":"data"}])
      assert {:ok, [%Request{id: "1"}, %Error{code: -32_600}]} = JSONRPC.decode(json)
    end

    test "empty batch returns error" do
      assert {:error, %Error{code: -32_600}} = JSONRPC.decode("[]")
    end
  end

  describe "decode/1 - error handling" do
    test "returns parse error for invalid JSON" do
      assert {:error, %Error{code: -32_700, message: "Parse error"}} =
               JSONRPC.decode("not json")
    end

    test "returns error for non-string input" do
      assert {:error, %Error{code: -32_700}} = JSONRPC.decode(123)
    end

    test "returns error for missing jsonrpc field" do
      assert {:error, %Error{code: -32_600}} =
               JSONRPC.decode(~s({"id":"1","method":"test"}))
    end

    test "returns error for wrong jsonrpc version" do
      assert {:error, %Error{code: -32_600}} =
               JSONRPC.decode(~s({"jsonrpc":"1.0","id":"1","method":"test"}))
    end

    test "returns error for non-object, non-array JSON" do
      assert {:error, %Error{code: -32_700}} = JSONRPC.decode(~s("just a string"))
    end
  end

  describe "round-trip encoding/decoding" do
    test "request round-trips correctly" do
      {:ok, original} =
        Request.new(%{id: "abc", method: "tools/list", params: %{"cursor" => nil}})

      assert {:ok, json} = JSONRPC.encode(original)
      assert {:ok, decoded} = JSONRPC.decode(json)
      assert decoded.id == original.id
      assert decoded.method == original.method
      assert decoded.params == original.params
    end

    test "notification round-trips correctly" do
      {:ok, original} =
        Notification.new(%{method: "notifications/cancelled", params: %{"requestId" => "123"}})

      assert {:ok, json} = JSONRPC.encode(original)
      assert {:ok, decoded} = JSONRPC.decode(json)
      assert decoded.method == original.method
      assert decoded.params == original.params
    end

    test "response round-trips correctly" do
      {:ok, original} = Response.new(%{id: "1", result: %{"tools" => []}})
      assert {:ok, json} = JSONRPC.encode(original)
      assert {:ok, decoded} = JSONRPC.decode(json)
      assert decoded.id == original.id
      assert decoded.result == original.result
    end

    test "error round-trips correctly" do
      {:ok, original} =
        Error.new(%{
          id: "1",
          code: -32_601,
          message: "Method not found",
          data: %{"method" => "bad"}
        })

      assert {:ok, json} = JSONRPC.encode(original)
      assert {:ok, decoded} = JSONRPC.decode(json)
      assert decoded.id == original.id
      assert decoded.code == original.code
      assert decoded.message == original.message
      assert decoded.data == original.data
    end

    test "batch round-trips correctly" do
      {:ok, req} = Request.new(%{id: "1", method: "foo", params: %{"x" => 1}})
      {:ok, notif} = Notification.new(%{method: "bar"})
      {:ok, resp} = Response.new(%{id: "2", result: "ok"})

      assert {:ok, json} = JSONRPC.encode([req, notif, resp])
      assert {:ok, [decoded_req, decoded_notif, decoded_resp]} = JSONRPC.decode(json)

      assert %Request{id: "1", method: "foo"} = decoded_req
      assert %Notification{method: "bar"} = decoded_notif
      assert %Response{id: "2", result: "ok"} = decoded_resp
    end
  end
end
