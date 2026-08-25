defmodule Tidal.StateHandle.Resolver do
  @moduledoc """
  Resolution boundary for explicit application-state handles.

  A resolver must authorize every operation. Clustered deployments can replace
  the local resolver with a distributed directory and durable store without
  changing the handle passed in MCP tool arguments.
  """

  @type handle :: String.t()
  @type auth_context :: term()

  @doc "Creates state and returns a new opaque public handle."
  @callback create(initial_state :: term(), auth_context(), keyword()) ::
              {:ok, handle()} | {:error, term()}

  @doc "Authorizes the caller and fetches the state identified by a handle."
  @callback fetch(handle(), auth_context(), keyword()) :: {:ok, term()} | {:error, term()}

  @doc "Authorizes the caller and atomically transforms the identified state."
  @callback transact(
              handle(),
              auth_context(),
              (term() -> {:ok, term(), term()} | {:error, term()}),
              keyword()
            ) ::
              {:ok, term()} | {:error, term()}

  @doc "Authorizes the caller and permanently removes the identified state."
  @callback destroy(handle(), auth_context(), keyword()) :: :ok | {:error, term()}
end
