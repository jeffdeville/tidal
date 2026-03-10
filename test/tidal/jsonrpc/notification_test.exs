defmodule Tidal.JSONRPC.NotificationTest do
  use ExUnit.Case, async: true

  alias Tidal.JSONRPC.Notification

  describe "new/1" do
    test "creates a valid notification" do
      assert {:ok, %Notification{method: "update", params: nil, jsonrpc: "2.0"}} =
               Notification.new(%{method: "update"})
    end

    test "creates a notification with params" do
      assert {:ok, %Notification{method: "update", params: %{"key" => "value"}}} =
               Notification.new(%{method: "update", params: %{"key" => "value"}})
    end

    test "accepts string keys" do
      assert {:ok, %Notification{method: "update"}} =
               Notification.new(%{"method" => "update"})
    end

    test "returns error for missing method" do
      assert {:error, "missing required field: method"} = Notification.new(%{})
    end

    test "returns error for empty method" do
      assert {:error, "method must be a non-empty string"} = Notification.new(%{method: ""})
    end

    test "returns error for non-map input" do
      assert {:error, "notification must be a map"} = Notification.new(42)
    end
  end

  describe "Jason.Encoder" do
    test "encodes notification without params" do
      notification = %Notification{method: "update"}
      assert {:ok, json} = Jason.encode(notification)
      decoded = Jason.decode!(json)
      assert decoded == %{"jsonrpc" => "2.0", "method" => "update"}
    end

    test "encodes notification with params" do
      notification = %Notification{method: "update", params: [1, 2]}
      assert {:ok, json} = Jason.encode(notification)
      assert Jason.decode!(json)["params"] == [1, 2]
    end
  end
end
