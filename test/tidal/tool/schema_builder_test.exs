defmodule Tidal.Tool.SchemaBuilderTest do
  use ExUnit.Case, async: true

  alias Tidal.Tool.SchemaBuilder

  describe "build_input_schema/1" do
    test "builds schema for simple string param" do
      params = [%{name: :message, type: :string, required: true, desc: "The message", fields: []}]

      schema = SchemaBuilder.build_input_schema(params)

      assert schema == %{
               "type" => "object",
               "properties" => %{
                 "message" => %{"type" => "string", "description" => "The message"}
               },
               "required" => ["message"]
             }
    end

    test "excludes injected params from schema" do
      params = [
        %{name: :task_id, type: :string, required: true, desc: nil, fields: [], injected: false},
        %{name: :session_id, type: :string, required: true, desc: nil, fields: [], injected: true}
      ]

      schema = SchemaBuilder.build_input_schema(params)

      assert Map.keys(schema["properties"]) == ["task_id"]
      assert schema["required"] == ["task_id"]
    end

    test "handles optional params without required array entry" do
      params = [
        %{name: :query, type: :string, required: true, desc: nil, fields: []},
        %{name: :limit, type: :integer, required: false, desc: "Max results", fields: []}
      ]

      schema = SchemaBuilder.build_input_schema(params)

      assert schema["required"] == ["query"]

      assert schema["properties"]["limit"] == %{
               "type" => "integer",
               "description" => "Max results"
             }
    end

    test "omits required key when no params are required" do
      params = [%{name: :hint, type: :string, required: false, desc: nil, fields: []}]

      schema = SchemaBuilder.build_input_schema(params)

      refute Map.has_key?(schema, "required")
    end

    test "handles enum type" do
      params = [
        %{
          name: :category,
          type: {:enum, ~w(blocked ambiguous technical)},
          required: false,
          desc: "Help category",
          fields: []
        }
      ]

      schema = SchemaBuilder.build_input_schema(params)

      assert schema["properties"]["category"] == %{
               "type" => "string",
               "enum" => ["blocked", "ambiguous", "technical"],
               "description" => "Help category"
             }
    end

    test "handles nested map with fields" do
      params = [
        %{
          name: :result,
          type: :map,
          required: true,
          desc: "Completion result",
          fields: [
            %{name: :summary, type: :string, required: true, desc: "What was done", fields: []},
            %{name: :merge_sha, type: :string, required: false, desc: "Git SHA", fields: []}
          ]
        }
      ]

      schema = SchemaBuilder.build_input_schema(params)

      result_schema = schema["properties"]["result"]
      assert result_schema["type"] == "object"

      assert result_schema["properties"]["summary"] == %{
               "type" => "string",
               "description" => "What was done"
             }

      assert result_schema["required"] == ["summary"]
    end

    test "handles list type with item schema" do
      params = [
        %{
          name: :tasks,
          type: :list,
          required: true,
          desc: "Task list",
          fields: [
            %{name: :title, type: :string, required: true, desc: nil, fields: []},
            %{name: :priority, type: :integer, required: false, desc: nil, fields: []}
          ]
        }
      ]

      schema = SchemaBuilder.build_input_schema(params)

      tasks_schema = schema["properties"]["tasks"]
      assert tasks_schema["type"] == "array"
      assert tasks_schema["items"]["type"] == "object"
      assert tasks_schema["items"]["properties"]["title"] == %{"type" => "string"}
      assert tasks_schema["items"]["required"] == ["title"]
    end

    test "handles boolean and number types" do
      params = [
        %{name: :verbose, type: :boolean, required: false, desc: nil, fields: []},
        %{name: :score, type: :number, required: false, desc: nil, fields: []}
      ]

      schema = SchemaBuilder.build_input_schema(params)

      assert schema["properties"]["verbose"] == %{"type" => "boolean"}
      assert schema["properties"]["score"] == %{"type" => "number"}
    end
  end

  describe "build_output_schema/1" do
    test "returns nil for empty fields" do
      assert SchemaBuilder.build_output_schema([]) == nil
    end

    test "builds object schema from success fields" do
      fields = [
        %{name: :task_id, type: :string, required: false, desc: "Task UUID", fields: []},
        %{name: :verified, type: :boolean, required: false, desc: nil, fields: []}
      ]

      schema = SchemaBuilder.build_output_schema(fields)

      assert schema["type"] == "object"

      assert schema["properties"]["task_id"] == %{
               "type" => "string",
               "description" => "Task UUID"
             }

      assert schema["properties"]["verified"] == %{"type" => "boolean"}
    end
  end
end
