defmodule Tidal.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :ets.new(:tidal_session_cache, [:set, :public, :named_table, read_concurrency: true])

    children = [
      {Registry, keys: :unique, name: :arena_registry},
      {Registry, keys: :unique, name: Tidal.SessionRegistry},
      {Registry, keys: :duplicate, name: Tidal.SubscriptionRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Tidal.SessionSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Tidal.StateHandle.Local.Supervisor}
    ]

    opts = [strategy: :one_for_one, name: Tidal.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
