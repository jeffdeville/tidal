defmodule Tidal.Session.OptionsTest do
  use ExUnit.Case, async: true

  alias Tidal.Session.Options

  describe "validate/1" do
    test "returns defaults for empty opts" do
      assert {:ok, opts} = Options.validate([])
      assert opts[:timeout] == :timer.minutes(30)
      assert opts[:capabilities] == %{}
      assert opts[:server_info] == %{}
    end

    test "accepts valid timeout" do
      assert {:ok, opts} = Options.validate(timeout: 5_000)
      assert opts[:timeout] == 5_000
    end

    test "rejects non-positive timeout" do
      assert {:error, %NimbleOptions.ValidationError{}} = Options.validate(timeout: 0)
      assert {:error, %NimbleOptions.ValidationError{}} = Options.validate(timeout: -1)
    end

    test "rejects non-integer timeout" do
      assert {:error, %NimbleOptions.ValidationError{}} = Options.validate(timeout: "fast")
    end

    test "accepts capabilities map" do
      assert {:ok, opts} = Options.validate(capabilities: %{tools: true})
      assert opts[:capabilities] == %{tools: true}
    end

    test "rejects non-map capabilities" do
      assert {:error, %NimbleOptions.ValidationError{}} = Options.validate(capabilities: "nope")
    end

    test "rejects unknown options" do
      assert {:error, %NimbleOptions.ValidationError{}} = Options.validate(unknown: true)
    end
  end

  describe "validate!/1" do
    test "returns opts on success" do
      opts = Options.validate!(timeout: 1_000)
      assert opts[:timeout] == 1_000
    end

    test "raises on invalid opts" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Options.validate!(timeout: -1)
      end
    end
  end

  describe "schema/0" do
    test "returns the NimbleOptions schema" do
      schema = Options.schema()
      assert is_list(schema)
      assert Keyword.has_key?(schema, :timeout)
      assert Keyword.has_key?(schema, :capabilities)
      assert Keyword.has_key?(schema, :server_info)
    end
  end
end
