defmodule Tidal.RegistryTest do
  use ExUnit.Case, async: true

  # ── Test tool modules ─────────────────────────────────────────────

  defmodule EchoTool do
    use Tidal.Tool.Operation

    defop :echo do
      desc("Echoes input")
      param(:message, :string, required: true)

      error(:empty, 400, retryable: false, desc: "Empty message")
    end

    @impl true
    def execute(:echo, %{message: msg}, _session), do: {:ok, %{echoed: msg}}
  end

  defmodule MathTool do
    use Tidal.Tool.Operation

    defop :add do
      desc("Adds two numbers")
      param(:a, :integer, required: true)
      param(:b, :integer, required: true)

      success do
        field(:result, :integer)
      end
    end

    @impl true
    def execute(:add, %{a: a, b: b}, _session), do: {:ok, %{result: a + b}}
  end

  # ── Tests ─────────────────────────────────────────────────────────

  describe "start_link/1 and register/1" do
    setup do
      # Start a unique registry per test to avoid conflicts
      name = :"registry_#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        Agent.start_link(
          fn ->
            %{operations: [], tools: [], modules: []}
          end,
          name: name
        )

      # We'll test the Tidal.Registry module functions by starting
      # the real registry with initial modules
      :ok
    end

    test "starts with initial modules" do
      {:ok, _} = start_supervised({Tidal.Registry, modules: [EchoTool]})

      ops = Tidal.Registry.all()
      assert length(ops) == 1
      assert hd(ops).name == :echo
    end

    test "register/1 adds additional modules" do
      {:ok, _} = start_supervised({Tidal.Registry, modules: [EchoTool]})

      assert length(Tidal.Registry.all()) == 1

      Tidal.Registry.register([MathTool])

      assert length(Tidal.Registry.all()) == 2
      names = Enum.map(Tidal.Registry.all(), & &1.name)
      assert :echo in names
      assert :add in names
    end

    test "starts empty with no modules" do
      {:ok, _} = start_supervised({Tidal.Registry, modules: []})

      assert Tidal.Registry.all() == []
      assert Tidal.Registry.tools() == []
      assert Tidal.Registry.modules() == []
    end
  end

  describe "by_name/1" do
    setup do
      {:ok, _} = start_supervised({Tidal.Registry, modules: [EchoTool, MathTool]})
      :ok
    end

    test "finds operation by atom name" do
      op = Tidal.Registry.by_name(:echo)

      assert op.name == :echo
      assert op.desc == "Echoes input"
      assert op.module == EchoTool
    end

    test "returns nil for unknown name" do
      assert Tidal.Registry.by_name(:nonexistent) == nil
    end
  end

  describe "tools/0" do
    test "returns Tool structs for all registered modules" do
      {:ok, _} = start_supervised({Tidal.Registry, modules: [EchoTool, MathTool]})

      tools = Tidal.Registry.tools()
      assert length(tools) == 2

      names = Enum.map(tools, & &1.name)
      assert "echo" in names
      assert "add" in names
    end
  end

  describe "errors/1" do
    setup do
      {:ok, _} = start_supervised({Tidal.Registry, modules: [EchoTool, MathTool]})
      :ok
    end

    test "returns error catalog for operation with errors" do
      errors = Tidal.Registry.errors(:echo)

      assert [error] = errors
      assert error.name == :empty
      assert error.status == 400
    end

    test "returns empty list for operation with no errors" do
      assert Tidal.Registry.errors(:add) == []
    end

    test "returns empty list for unknown operation" do
      assert Tidal.Registry.errors(:nonexistent) == []
    end
  end

  describe "modules/0" do
    test "returns all registered modules" do
      {:ok, _} = start_supervised({Tidal.Registry, modules: [EchoTool, MathTool]})

      modules = Tidal.Registry.modules()
      assert EchoTool in modules
      assert MathTool in modules
    end
  end
end
