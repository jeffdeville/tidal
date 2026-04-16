# synced_from_colony: true
# sync_pack: elixir
# sync_source: packs/elixir/checks/no_bare_map_params.ex
# sync_version: d3fefcef
defmodule ProjectChecks.NoBareMapParams do
  @moduledoc """
  Credo check that flags bare map patterns in public function parameters.

  Structs make the contract explicit. Bare maps in public APIs often hide it.
  """

  use Credo.Check,
    base_priority: :low,
    category: :design,
    param_defaults: [
      excluded_function_names: ~w(
        handle_event handle_info handle_call handle_cast handle_params
        handle_async handle_continue handle_in
        call init log execute icon input button
      )a
    ]

  alias Credo.SourceFile

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    excluded = params |> Params.get(:excluded_function_names, __MODULE__) |> MapSet.new()
    impl_fns = find_impl_function_names(source_file)
    skip_fns = MapSet.union(impl_fns, excluded)

    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta, skip_fns))
  end

  defp find_impl_function_names(source_file) do
    {_names, acc} =
      Credo.Code.prewalk(source_file, &collect_impl_fns/2, {false, MapSet.new()})

    acc
  end

  defp collect_impl_fns({:@, _, [{:impl, _, [value]}]} = ast, {_pending, names}) when value != false and value != nil,
    do: {ast, {true, names}}

  defp collect_impl_fns({:def, _, args} = ast, {true, names}) when is_list(args) do
    {ast, {false, MapSet.put(names, extract_fn_name(args))}}
  end

  defp collect_impl_fns({:def, _, _} = ast, {_pending, names}), do: {ast, {false, names}}
  defp collect_impl_fns(ast, acc), do: {ast, acc}

  defp traverse({:def, meta, args} = ast, issues, issue_meta, skip_fns) when is_list(args) do
    name = extract_fn_name(args)

    if not MapSet.member?(skip_fns, name) and bare_map_in_params?(args) do
      issue =
        format_issue(issue_meta,
          message: "Public function accepts a bare map — prefer a struct to document the contract.",
          line_no: meta[:line]
        )

      {ast, [issue | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta, _skip_fns), do: {ast, issues}

  defp extract_fn_name([{:when, _, [{name, _, _} | _]}]) when is_atom(name), do: name
  defp extract_fn_name([{name, _, _} | _]) when is_atom(name), do: name
  defp extract_fn_name(_), do: nil

  defp bare_map_in_params?([{:when, _, [call | _guards]}]) do
    case call do
      {_name, _, params} when is_list(params) -> Enum.any?(params, &bare_map?/1)
      _ -> false
    end
  end

  defp bare_map_in_params?([{_name, _, params} | _]) when is_list(params), do: Enum.any?(params, &bare_map?/1)
  defp bare_map_in_params?(_), do: false

  defp bare_map?({:%{}, _, pairs}) when is_list(pairs), do: not all_string_keys?(pairs)
  defp bare_map?({:%{}, _, _}), do: true
  defp bare_map?({:=, _, [left, right]}), do: bare_map?(left) or bare_map?(right)
  defp bare_map?(_), do: false

  defp all_string_keys?([]), do: false
  defp all_string_keys?(pairs), do: Enum.all?(pairs, fn {key, _val} -> is_binary(key) end)
end
