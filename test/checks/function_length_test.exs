# synced_from_colony: true
# sync_pack: elixir
# sync_source: packs/elixir/test/checks/function_length_test.exs
# sync_version: d3fefcef
defmodule ProjectChecks.FunctionLengthTest do
  use Credo.Test.Case

  alias ProjectChecks.FunctionLength

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags public function exceeding max_lines" do
    body = Enum.map_join(1..12, "\n", fn i -> "    x = x + #{i}" end)

    """
    defmodule Foo do
      def long_func(x) do
    #{body}
        x
      end
    end
    """
    |> to_source_file()
    |> run_check(FunctionLength, max_lines: 10)
    |> assert_issue(fn issue ->
      assert issue.message =~ "long_func"
      assert issue.message =~ "max 10"
    end)
  end

  test "allows short function" do
    """
    defmodule Foo do
      def short(x) do
        x + 1
      end
    end
    """
    |> to_source_file()
    |> run_check(FunctionLength, max_lines: 20)
    |> refute_issues()
  end
end
