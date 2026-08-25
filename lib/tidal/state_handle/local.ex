defmodule Tidal.StateHandle.Local do
  @moduledoc """
  Single-node resolver backed by one Arena-aware GenServer per handle.

  This implementation is ideal for local development and for state that may
  expire when a node exits. It deliberately does not pretend to be a durable or
  cross-node store. Production deployments that promise either property should
  configure another `Tidal.StateHandle.Resolver`.
  """

  @behaviour Tidal.StateHandle.Resolver

  alias Tidal.StateHandle.Local.Actor

  @supervisor __MODULE__.Supervisor
  @default_idle_timeout :timer.minutes(30)

  @impl true
  def create(initial_state, auth_context, opts) do
    handle = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    input = %{
      handle: handle,
      value: initial_state,
      auth_context: auth_context,
      idle_timeout: Keyword.get(opts, :idle_timeout, @default_idle_timeout)
    }

    child = {Actor, Arena.wrap(Arena.Config.current(), input)}

    case DynamicSupervisor.start_child(@supervisor, child) do
      {:ok, _pid} -> {:ok, handle}
      {:error, {:already_started, _pid}} -> create(initial_state, auth_context, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def fetch(handle, auth_context, _opts) do
    call(handle, {:fetch, auth_context})
  end

  @impl true
  def transact(handle, auth_context, function, _opts) do
    call(handle, {:transact, auth_context, function})
  end

  @impl true
  def destroy(handle, auth_context, _opts) do
    call(handle, {:destroy, auth_context})
  end

  defp call(handle, message) do
    case Actor.get_pid(%{handle: handle}) do
      nil -> {:error, :not_found}
      pid -> safe_call(pid, message)
    end
  end

  defp safe_call(pid, message) do
    GenServer.call(pid, message)
  catch
    :exit, _reason -> {:error, :not_found}
  end
end
