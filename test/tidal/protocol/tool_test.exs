defmodule Tidal.Protocol.ToolTest do
  use ExUnit.Case, async: true

  alias Tidal.Protocol.Tool

  describe "new/1" do
    test "creates tool with all fields" do
      assert {:ok, tool} =
               Tool.new(
                 name: "test",
                 description: "A test tool",
                 input_schema: %{"type" => "object"}
               )

      assert tool.name == "test"
      assert tool.description == "A test tool"
      assert tool.input_schema == %{"type" => "object"}
    end

    test "creates tool with only required fields" do
      assert {:ok, tool} = Tool.new(name: "minimal")
      assert tool.name == "minimal"
      assert tool.description == nil
      assert tool.input_schema == nil
    end

    test "returns error for missing name" do
      assert {:error, %NimbleOptions.ValidationError{}} = Tool.new([])
    end
  end

  describe "new!/1" do
    test "raises on invalid input" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Tool.new!([])
      end
    end
  end

  describe "to_map/1" do
    test "serializes full tool" do
      tool = %Tool{
        name: "test",
        description: "desc",
        input_schema: %{"type" => "object"}
      }

      map = Tool.to_map(tool)

      assert map == %{
               "name" => "test",
               "description" => "desc",
               "inputSchema" => %{"type" => "object"}
             }
    end

    test "omits nil fields" do
      tool = %Tool{name: "minimal"}
      map = Tool.to_map(tool)
      assert map == %{"name" => "minimal"}
      refute Map.has_key?(map, "description")
      refute Map.has_key?(map, "inputSchema")
    end
  end
end
