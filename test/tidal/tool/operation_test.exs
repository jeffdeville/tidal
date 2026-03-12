defmodule Tidal.Tool.OperationTest do
  use ExUnit.Case, async: true

  alias Tidal.Protocol.{Tool, ToolResult}

  # ── Test tool module using defop ──────────────────────────────────

  defmodule EchoTool do
    use Tidal.Tool.Operation

    defop :echo do
      desc("Echoes back the provided message")

      param(:message, :string, required: true, desc: "The message to echo")
      param(:uppercase, :boolean, desc: "Whether to uppercase")

      success do
        field(:echoed, :string, desc: "The echoed message")
      end

      error(:empty_message, 400,
        retryable: false,
        desc: "Message was empty",
        recovery: "Provide a non-empty message."
      )

      guidance("Call this to test connectivity.")
    end

    @impl true
    def execute(:echo, %{message: message} = params, _session) do
      if message == "" do
        {:error, :empty_message}
      else
        result =
          if params[:uppercase],
            do: String.upcase(message),
            else: message

        {:ok, %{echoed: result}}
      end
    end
  end

  defmodule MultiTool do
    use Tidal.Tool.Operation

    defop :greet do
      desc("Greets a person")
      param(:name, :string, required: true)
    end

    defop :farewell do
      desc("Says goodbye")
      mutation(true)
      param(:name, :string, required: true)
    end

    @impl true
    def execute(:greet, %{name: name}, _session), do: {:ok, %{message: "Hello, #{name}!"}}
    def execute(:farewell, %{name: name}, _session), do: {:ok, %{message: "Goodbye, #{name}!"}}
  end

  defmodule NestedParamTool do
    use Tidal.Tool.Operation

    defop :submit do
      desc("Submit with nested result")

      param(:task_id, :string, required: true)
      param(:session_id, :string, injected: true)

      param :result, :map, required: true, desc: "Completion data" do
        field(:summary, :string, required: true, desc: "What was done")
        field(:merge_sha, :string, desc: "Git SHA")
      end

      success do
        field(:accepted, :boolean)
      end

      error(:missing_summary, 400,
        retryable: true,
        desc: "Summary is required",
        recovery: "Include a summary in result."
      )
    end

    @impl true
    def execute(:submit, %{task_id: _tid, result: result}, _session) do
      if result["summary"] || result[:summary] do
        {:ok, %{accepted: true}}
      else
        {:error, :missing_summary}
      end
    end
  end

  # ── Tests ─────────────────────────────────────────────────────────

  describe "define_tools/0" do
    test "generates Tool structs from defop" do
      tools = EchoTool.define_tools()

      assert [%Tool{name: "echo"}] = tools
      tool = hd(tools)

      assert tool.description == "Echoes back the provided message"
      assert tool.input_schema["type"] == "object"
      assert tool.input_schema["required"] == ["message"]
      assert tool.input_schema["properties"]["message"]["type"] == "string"
      assert tool.input_schema["properties"]["uppercase"]["type"] == "boolean"
    end

    test "generates multiple tools from multiple defops" do
      tools = MultiTool.define_tools()

      assert length(tools) == 2
      names = Enum.map(tools, & &1.name)
      assert "greet" in names
      assert "farewell" in names
    end

    test "nested map params produce nested JSON Schema" do
      tools = NestedParamTool.define_tools()
      tool = hd(tools)

      # session_id should be excluded (injected)
      refute Map.has_key?(tool.input_schema["properties"], "session_id")

      result_schema = tool.input_schema["properties"]["result"]
      assert result_schema["type"] == "object"
      assert result_schema["properties"]["summary"]["type"] == "string"
      assert result_schema["required"] == ["summary"]
    end
  end

  describe "handle_tool_call/3" do
    test "dispatches to execute and wraps success in ToolResult" do
      session = %{assigns: %{}}

      assert {:ok, %ToolResult{content: [content], is_error: false}} =
               EchoTool.handle_tool_call("echo", %{"message" => "hello"}, session)

      assert %{"echoed" => "hello"} = Jason.decode!(content.text)
    end

    test "handles optional params" do
      session = %{assigns: %{}}

      assert {:ok, %ToolResult{content: [content]}} =
               EchoTool.handle_tool_call(
                 "echo",
                 %{"message" => "hi", "uppercase" => true},
                 session
               )

      assert %{"echoed" => "HI"} = Jason.decode!(content.text)
    end

    test "returns structured error from error catalog" do
      session = %{assigns: %{}}

      assert {:ok, %ToolResult{content: [content], is_error: true}} =
               EchoTool.handle_tool_call("echo", %{"message" => ""}, session)

      error = Jason.decode!(content.text)
      assert error["status"] == "error"
      assert error["error"] == "empty_message"
      assert error["retryable"] == false
      assert error["recovery"] == "Provide a non-empty message."
    end

    test "returns error for unknown tool" do
      session = %{assigns: %{}}

      assert {:error, "Unknown tool: nonexistent"} =
               EchoTool.handle_tool_call("nonexistent", %{}, session)
    end

    test "dispatches correct tool in multi-tool module" do
      session = %{assigns: %{}}

      assert {:ok, %ToolResult{content: [content]}} =
               MultiTool.handle_tool_call("greet", %{"name" => "Alice"}, session)

      assert %{"message" => "Hello, Alice!"} = Jason.decode!(content.text)

      assert {:ok, %ToolResult{content: [content]}} =
               MultiTool.handle_tool_call("farewell", %{"name" => "Bob"}, session)

      assert %{"message" => "Goodbye, Bob!"} = Jason.decode!(content.text)
    end
  end

  describe "__tidal_operations__/0" do
    test "returns operation metadata" do
      ops = EchoTool.__tidal_operations__()

      assert [op] = ops
      assert op.name == :echo
      assert op.desc == "Echoes back the provided message"
      assert op.mutation == false
      assert op.guidance == "Call this to test connectivity."

      assert length(op.params) == 2
      assert length(op.success_fields) == 1
      assert length(op.errors) == 1
    end

    test "captures mutation annotation" do
      ops = MultiTool.__tidal_operations__()
      farewell = Enum.find(ops, &(&1.name == :farewell))

      assert farewell.mutation == true
    end

    test "captures nested param fields" do
      ops = NestedParamTool.__tidal_operations__()
      [op] = ops

      result_param = Enum.find(op.params, &(&1.name == :result))
      assert length(result_param.fields) == 2

      summary = Enum.find(result_param.fields, &(&1.name == :summary))
      assert summary.required == true
      assert summary.desc == "What was done"
    end
  end

  describe "__tidal_errors__/1" do
    test "returns error catalog for operation" do
      errors = EchoTool.__tidal_errors__(:echo)

      assert [error] = errors
      assert error.name == :empty_message
      assert error.status == 400
      assert error.retryable == false
      assert error.desc == "Message was empty"
      assert error.recovery == "Provide a non-empty message."
    end

    test "returns empty list for unknown operation" do
      assert [] = EchoTool.__tidal_errors__(:nonexistent)
    end
  end
end
