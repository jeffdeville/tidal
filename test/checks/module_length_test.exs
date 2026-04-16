# synced_from_colony: true
# sync_pack: elixir
# sync_source: packs/elixir/test/checks/module_length_test.exs
# sync_version: d3fefcef
defmodule ProjectChecks.ModuleLengthTest do
  use Credo.Test.Case

  alias ProjectChecks.ModuleLength

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags module exceeding max_lines" do
    lines = Enum.map_join(1..12, "\n", fn i -> "  def func_#{i}, do: :ok" end)

    """
    defmodule BigModule do
    #{lines}
    end
    """
    |> to_source_file()
    |> run_check(ModuleLength, max_lines: 10)
    |> assert_issue(fn issue ->
      assert issue.message =~ "BigModule"
      assert issue.message =~ "max 10"
    end)
  end

  test "allows module under max_lines" do
    """
    defmodule SmallModule do
      def foo, do: :ok
      def bar, do: :ok
    end
    """
    |> to_source_file()
    |> run_check(ModuleLength, max_lines: 300)
    |> refute_issues()
  end
end
