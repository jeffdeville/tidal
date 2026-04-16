# synced_from_colony: true
# sync_pack: elixir
# sync_source: packs/elixir/checks/no_nested_control_flow.ex
# sync_version: d3fefcef
defmodule ProjectChecks.NoNestedControlFlow do
  @moduledoc """
  Credo check that detects nested control flow statements.

  Any nesting of `if`, `case`, `cond`, or `with` inside another
  control flow statement reduces readability.
  """

  use Credo.Check,
    base_priority: :low,
    category: :readability

  @control_flow_nodes [:case, :cond, :if, :with]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse({node_type, meta, args} = ast, issues, issue_meta)
       when node_type in @control_flow_nodes and is_list(args) do
    body = extract_body(node_type, args)

    if nested_control_flow?(body) do
      {ast, [issue_for(issue_meta, meta[:line], node_type) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp extract_body(:case, [_expr, [do: clauses]]), do: clauses
  defp extract_body(:cond, [[do: clauses]]), do: clauses
  defp extract_body(:if, [_condition, blocks]), do: blocks
  defp extract_body(:with, args), do: with_body(args)
  defp extract_body(_, _), do: nil

  defp with_body(args) when is_list(args) do
    case List.last(args) do
      [do: body] -> body
      [do: body, else: else_clauses] -> [body | else_clauses]
      _ -> nil
    end
  end

  defp nested_control_flow?(nil), do: false
  defp nested_control_flow?({node_type, _, _}) when node_type in @control_flow_nodes, do: true
  defp nested_control_flow?({:->, _, [_pattern, body]}), do: nested_control_flow?(body)
  defp nested_control_flow?({:__block__, _, exprs}) when is_list(exprs), do: Enum.any?(exprs, &nested_control_flow?/1)

  defp nested_control_flow?(blocks) when is_list(blocks) do
    Enum.any?(blocks, fn
      {:do, body} -> nested_control_flow?(body)
      {:else, body} -> nested_control_flow?(body)
      item -> nested_control_flow?(item)
    end)
  end

  defp nested_control_flow?(_), do: false

  defp issue_for(issue_meta, line_no, outer_type) do
    format_issue(issue_meta,
      message: "Nested control flow inside `#{outer_type}` — extract a helper or flatten the flow.",
      line_no: line_no
    )
  end
end
