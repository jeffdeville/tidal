defmodule Tidal do
  @moduledoc """
  Builds Model Context Protocol servers in Elixir.

  Define tools with `Tidal.Tool`, resources with `Tidal.Resource`, and mount
  `Tidal.Plug` in a Phoenix router or Bandit server. MCP `2026-07-28` requests
  are independent and receive a fresh `Tidal.RequestContext`; applications that
  need continuity can use explicit `Tidal.StateHandle` values or signed
  `Tidal.RequestState` continuations without relying on load-balancer affinity.

  See the project README for a complete server and deployment examples.
  """
end
