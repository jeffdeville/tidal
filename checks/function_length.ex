# synced_from_colony: true
# sync_pack: elixir
# sync_source: packs/elixir/checks/function_length.ex
# sync_version: d3fefcef
defmodule ProjectChecks.FunctionLength do
  @moduledoc """
  Credo check that flags functions exceeding a configurable line count.
  """

  use Credo.Check,
    base_priority: :normal,
    category: :refactor,
    param_defaults: [max_lines: 20]

  alias Credo.SourceFile

  @impl true
  def run(%SourceFile{} = source_file, params) do
    max_lines = Params.get(params, :max_lines, __MODULE__)
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta, max_lines))
  end

  defp traverse({kind, meta, args} = ast, issues, issue_meta, max_lines) when kind in [:def, :defp] and is_list(args) do
    line_start = meta[:line]
    line_end = meta[:end_of_expression][:line] || meta[:end][:line]

    case check_function_length(line_start, line_end, max_lines, args) do
      {:over, fn_name, length} ->
        issue =
          format_issue(issue_meta,
            message: "Function `#{fn_name}` is #{length} lines (max #{max_lines}). Extract helper functions.",
            line_no: line_start
          )

        {ast, [issue | issues]}

      :ok ->
        {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta, _max_lines), do: {ast, issues}

  defp check_function_length(_start, nil, _max, _args), do: :ok

  defp check_function_length(start, finish, max, args) do
    length = finish - start + 1
    if length > max, do: {:over, extract_fn_name(args), length}, else: :ok
  end

  defp extract_fn_name([{:when, _, [{name, _, _} | _]} | _]) when is_atom(name), do: name
  defp extract_fn_name([{name, _, _} | _]) when is_atom(name), do: name
  defp extract_fn_name(_), do: "?"
end
