defmodule Tidal.Registry do
  @moduledoc """
  Queryable catalog of all registered tool operations.

  The registry collects operation metadata from modules that use
  `Tidal.Tool.Operation` and provides query functions for introspection,
  documentation generation, and tool discovery.

  ## Usage

      # Register modules (typically at application startup)
      Tidal.Registry.register([MyApp.TaskTools, MyApp.QueryTools])

      # Query
      Tidal.Registry.all()                      # All operations
      Tidal.Registry.by_name(:finish_task)       # Single operation
      Tidal.Registry.tools()                     # Tidal.Protocol.Tool structs
      Tidal.Registry.errors(:finish_task)         # Error catalog for a tool

  ## Application Config

  Tool modules can also be configured via application env:

      config :tidal, :tool_modules, [MyApp.TaskTools, MyApp.QueryTools]
  """

  use Agent

  @doc "Start the registry. Called by Tidal.Application."
  def start_link(opts \\ []) do
    modules = Keyword.get(opts, :modules, [])
    Agent.start_link(fn -> build_state(modules) end, name: __MODULE__)
  end

  @doc "Register additional tool modules."
  @spec register([module()]) :: :ok
  def register(modules) when is_list(modules) do
    Agent.update(__MODULE__, fn state ->
      new_entries = collect_operations(modules)
      new_tools = collect_tools(modules)

      %{
        state
        | operations: state.operations ++ new_entries,
          tools: state.tools ++ new_tools,
          modules: state.modules ++ modules
      }
    end)
  end

  @doc "All registered operations with full metadata."
  @spec all() :: [map()]
  def all do
    Agent.get(__MODULE__, & &1.operations)
  end

  @doc "Find an operation by name."
  @spec by_name(atom()) :: map() | nil
  def by_name(name) when is_atom(name) do
    Enum.find(all(), &(&1.name == name))
  end

  @doc "All tool definitions as `Tidal.Protocol.Tool` structs."
  @spec tools() :: [Tidal.Protocol.Tool.t()]
  def tools do
    Agent.get(__MODULE__, & &1.tools)
  end

  @doc "Error catalog for a specific operation."
  @spec errors(atom()) :: [Tidal.Tool.ErrorSpec.t()]
  def errors(name) when is_atom(name) do
    case by_name(name) do
      %{module: module} -> module.__tidal_errors__(name)
      nil -> []
    end
  end

  @doc "All registered modules."
  @spec modules() :: [module()]
  def modules do
    Agent.get(__MODULE__, & &1.modules)
  end

  # ── Internals ──────────────────────────────────────────────────────

  defp build_state(modules) do
    %{
      operations: collect_operations(modules),
      tools: collect_tools(modules),
      modules: modules
    }
  end

  defp collect_operations(modules) do
    Enum.flat_map(modules, fn mod ->
      if function_exported?(mod, :__tidal_operations__, 0) do
        mod.__tidal_operations__()
        |> Enum.map(&Map.put(&1, :module, mod))
      else
        []
      end
    end)
  end

  defp collect_tools(modules) do
    Enum.flat_map(modules, fn mod ->
      if function_exported?(mod, :define_tools, 0) do
        mod.define_tools()
      else
        []
      end
    end)
  end
end
