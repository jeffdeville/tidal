defmodule Tidal.Checks.NoNestedCaseTest do
  use Credo.Test.Case

  alias Tidal.Checks.NoNestedCase

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "rejects nested case statements" do
    """
    defmodule Foo do
      def bar(x) do
        case foo(x) do
          {:ok, y} ->
            case baz(y) do
              {:ok, z} -> z
              :error -> nil
            end
          :error -> nil
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoNestedCase)
    |> assert_issue()
  end

  test "accepts flat case statements" do
    """
    defmodule Foo do
      def bar(x) do
        case foo(x) do
          {:ok, y} -> y
          :error -> nil
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoNestedCase)
    |> refute_issues()
  end

  test "accepts with chains" do
    """
    defmodule Foo do
      def bar(x) do
        with {:ok, y} <- foo(x),
             {:ok, z} <- baz(y) do
          z
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoNestedCase)
    |> refute_issues()
  end

  test "detects nested case in block body" do
    """
    defmodule Foo do
      def bar(x) do
        case foo(x) do
          {:ok, y} ->
            Logger.info("got y")
            case baz(y) do
              {:ok, z} -> z
            end
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(NoNestedCase)
    |> assert_issue()
  end
end
