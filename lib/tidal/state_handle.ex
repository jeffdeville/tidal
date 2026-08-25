defmodule Tidal.StateHandle do
  @moduledoc """
  Operations on explicit, server-minted application-state handles.

  MCP `2026-07-28` removes implicit protocol sessions, not application state.
  Tools may return an opaque handle and accept it on later calls. This module
  resolves that handle through the server's configured resolver and supplies the
  current request's authorization context on every operation.

  `Tidal.StateHandle.Local` is the single-node default. Configure a resolver
  implementing `Tidal.StateHandle.Resolver` when handles must survive node loss
  or resolve across independently deployed BEAM clusters.
  """

  alias Tidal.RequestContext

  @typedoc "Opaque, URL-safe identifier minted by the configured resolver."
  @type handle :: String.t()

  @doc """
  Creates an opaque handle bound to the current authorization context.

  Resolver-specific options are merged over the options configured on the
  server. The local resolver accepts `:idle_timeout` in milliseconds and
  defaults to 30 minutes.

      {:ok, handle} = Tidal.StateHandle.create(context, %{items: []})

  Return the handle to the client and require it explicitly on later calls.
  """
  @spec create(RequestContext.t(), term(), keyword()) :: {:ok, handle()} | {:error, term()}
  def create(%RequestContext{} = context, initial_state, opts \\ []) do
    with {:ok, {resolver, resolver_opts}} <- resolver(context) do
      resolver.create(initial_state, context.auth_context, Keyword.merge(resolver_opts, opts))
    end
  end

  @doc """
  Fetches the current state after authorizing this request.

  The built-in resolver returns `{:error, :not_found}` when a handle is absent
  or its actor has expired, and `{:error, :unauthorized}` when it belongs to a
  different authorization context. Custom resolver errors pass through.
  """
  @spec fetch(RequestContext.t(), handle()) :: {:ok, term()} | {:error, term()}
  def fetch(%RequestContext{} = context, handle) when is_binary(handle) do
    with {:ok, {resolver, opts}} <- resolver(context) do
      resolver.fetch(handle, context.auth_context, opts)
    end
  end

  @doc """
  Atomically transforms handle state and returns the transaction result.

  The function receives the current state and returns either
  `{:ok, new_state, result}` or `{:error, reason}`. A successful transaction
  stores `new_state` and returns `{:ok, result}` to the caller.

      Tidal.StateHandle.transact(context, handle, fn state ->
        new_state = Map.update!(state, :count, &(&1 + 1))
        {:ok, new_state, new_state.count}
      end)
  """
  @spec transact(RequestContext.t(), handle(), (term() -> {:ok, term(), term()} | {:error, term()})) ::
          {:ok, term()} | {:error, term()}
  def transact(%RequestContext{} = context, handle, function)
      when is_binary(handle) and is_function(function, 1) do
    with {:ok, {resolver, opts}} <- resolver(context) do
      resolver.transact(handle, context.auth_context, function, opts)
    end
  end

  @doc """
  Destroys a handle after authorizing this request.

  Returns `:ok` only after the configured resolver has removed the state. The
  local resolver otherwise returns `{:error, :not_found}` or
  `{:error, :unauthorized}`.
  """
  @spec destroy(RequestContext.t(), handle()) :: :ok | {:error, term()}
  def destroy(%RequestContext{} = context, handle) when is_binary(handle) do
    with {:ok, {resolver, opts}} <- resolver(context) do
      resolver.destroy(handle, context.auth_context, opts)
    end
  end

  defp resolver(%RequestContext{server: %{state_resolver: {module, opts}}})
       when is_atom(module) and is_list(opts),
       do: {:ok, {module, opts}}

  defp resolver(%RequestContext{server: %{state_resolver: nil}}),
    do: {:error, :state_handles_disabled}

  defp resolver(%RequestContext{server: %{state_resolver: module}}) when is_atom(module),
    do: {:ok, {module, []}}
end
