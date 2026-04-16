# synced_from_colony: true
# sync_pack: elixir
# sync_source: packs/elixir/test/checks/no_bare_map_params_test.exs
# sync_version: d3fefcef
defmodule ProjectChecks.NoBareMapParamsTest do
  use Credo.Test.Case

  alias ProjectChecks.NoBareMapParams

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags bare map pattern in public function" do
    """
    defmodule Foo do
      def create(%{name: name, email: email}) do
        {name, email}
      end
    end
    """
    |> to_source_file()
    |> run_check(NoBareMapParams)
    |> assert_issue()
  end

  test "allows struct pattern in public function" do
    """
    defmodule Foo do
      def create(%User{name: name, email: email}) do
        {name, email}
      end
    end
    """
    |> to_source_file()
    |> run_check(NoBareMapParams)
    |> refute_issues()
  end
end
