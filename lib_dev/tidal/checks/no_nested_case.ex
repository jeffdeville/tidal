defmodule Tidal.Checks.NoNestedCase do
  @moduledoc """
  Credo check that detects nested `case` statements.

  Nested `case` blocks reduce readability. This check flags them so
  developers use `with` blocks or extract inner matches to helper
  functions instead.
  """

  use Credo.Check,
    base_priority: :high,
    category: :readability,
    explanations: [
      check: """
      Nested `case` statements reduce readability.
      Use `with` or extract inner matches to helper functions.

      # Bad
      case foo() do
        {:ok, x} ->
          case bar(x) do
            {:ok, y} -> ...
          end
      end

      # Good
      with {:ok, x} <- foo(),
           {:ok, y} <- bar(x) do
        ...
      end
      """
    ]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  # Match a `case` node whose clauses contain another `case`
  defp traverse({:case, meta, [_expr, [do: clauses]]} = ast, issues, issue_meta) do
    if nested_case?(clauses) do
      {ast, [issue_for(issue_meta, meta[:line]) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  # Recursively check if any branch of the clauses contains a `case`
  defp nested_case?({:case, _, _}), do: true
  defp nested_case?({:->, _, [_pattern, body]}), do: nested_case?(body)

  defp nested_case?({:__block__, _, exprs}) when is_list(exprs),
    do: Enum.any?(exprs, &nested_case?/1)

  defp nested_case?(list) when is_list(list), do: Enum.any?(list, &nested_case?/1)
  defp nested_case?(_), do: false

  defp issue_for(issue_meta, line_no) do
    format_issue(issue_meta,
      message:
        "Nested `case` detected — consider using `with` or extracting to a helper function.",
      line_no: line_no
    )
  end
end
