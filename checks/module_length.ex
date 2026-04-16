# synced_from_colony: true
# sync_pack: elixir
# sync_source: packs/elixir/checks/module_length.ex
# sync_version: d3fefcef
defmodule ProjectChecks.ModuleLength do
  @moduledoc """
  Credo check that flags modules exceeding a configurable line count.
  """

  use Credo.Check,
    base_priority: :normal,
    category: :refactor,
    param_defaults: [max_lines: 300]

  alias Credo.SourceFile

  @impl true
  def run(%SourceFile{} = source_file, params) do
    max_lines = Params.get(params, :max_lines, __MODULE__)
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta, max_lines))
  end

  defp traverse({:defmodule, meta, [{:__aliases__, _, name_parts}, _body]} = ast, issues, issue_meta, max_lines) do
    line_start = meta[:line]
    line_end = meta[:end_of_expression][:line] || meta[:end][:line]

    case check_module_length(line_start, line_end, max_lines, name_parts) do
      {:over, module_name, length} ->
        issue =
          format_issue(issue_meta,
            message: "Module `#{module_name}` is #{length} lines (max #{max_lines}). Split it into focused modules.",
            line_no: line_start
          )

        {ast, [issue | issues]}

      :ok ->
        {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta, _max_lines), do: {ast, issues}

  defp check_module_length(_start, nil, _max, _parts), do: :ok

  defp check_module_length(start, finish, max, name_parts) do
    length = finish - start + 1
    if length > max, do: {:over, Enum.join(name_parts, "."), length}, else: :ok
  end
end
