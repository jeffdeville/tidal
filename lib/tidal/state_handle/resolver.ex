defmodule Tidal.StateHandle.Resolver do
  @moduledoc """
  Resolution boundary for explicit application-state handles.

  A resolver must authorize every operation. Clustered deployments can replace
  the local resolver with a distributed directory and durable store without
  changing the handle passed in MCP tool arguments.
  """

  @type handle :: String.t()
  @type auth_context :: term()

  @callback create(initial_state :: term(), auth_context(), keyword()) ::
              {:ok, handle()} | {:error, term()}
  @callback fetch(handle(), auth_context(), keyword()) :: {:ok, term()} | {:error, term()}
  @callback transact(handle(), auth_context(), (term() -> term()), keyword()) ::
              {:ok, term()} | {:error, term()}
  @callback destroy(handle(), auth_context(), keyword()) :: :ok | {:error, term()}
end
