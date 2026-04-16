# synced_from_colony: true
# sync_pack: elixir
# sync_source: packs/elixir/test/checks/no_nested_control_flow_test.exs
# sync_version: d3fefcef
defmodule ProjectChecks.NoNestedControlFlowTest do
  use Credo.Test.Case

  alias ProjectChecks.NoNestedControlFlow

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags case inside case" do
    """
    defmodule Foo do
      def run(x) do
        case foo(x) do
          {:ok, y} ->
            case bar(y) do
              {:ok, z} -> z
            end
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoNestedControlFlow)
    |> assert_issue()
  end

  test "allows flat with chain" do
    """
    defmodule Foo do
      def run(x) do
        with {:ok, y} <- foo(x),
             {:ok, z} <- bar(y) do
          {:ok, z}
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoNestedControlFlow)
    |> refute_issues()
  end
end
