defmodule Tidal.Subscriptions do
  @moduledoc """
  Publishes change notifications to modern `subscriptions/listen` streams.

  The default node-local bus is appropriate for one BEAM node. Pass the same
  resolver configured on `Tidal.Server` when publishing through a clustered or
  external bus.

  A bus can be passed as a module or `{module, options}` tuple. Publishing is
  synchronous only to the bus boundary; delivery and durability are defined by
  the selected `Tidal.SubscriptionBus` implementation.
  """

  alias Tidal.Server
  alias Tidal.Subscriptions.Local

  @doc """
  Publishes a `notifications/tools/list_changed` event.

      Tidal.Subscriptions.tools_changed()
      Tidal.Subscriptions.tools_changed({MyApp.Bus, pubsub: MyApp.PubSub})
  """
  @spec tools_changed(module() | {module(), keyword()}) :: :ok
  def tools_changed(bus \\ Local), do: publish(bus, :tools_list_changed)

  @doc """
  Publishes a `notifications/resources/list_changed` event.

  Pass the same bus configuration used by `Tidal.Plug` when it is not the local
  default.
  """
  @spec resources_list_changed(module() | {module(), keyword()}) :: :ok
  def resources_list_changed(bus \\ Local), do: publish(bus, :resources_list_changed)

  @doc """
  Publishes a resource update to streams subscribed to that exact URI.

      Tidal.Subscriptions.resource_updated("status://current")
  """
  @spec resource_updated(String.t(), module() | {module(), keyword()}) :: :ok
  def resource_updated(uri, bus \\ Local) when is_binary(uri),
    do: publish(bus, {:resource_updated, uri})

  @doc false
  @spec subscribe(Server.t(), map()) :: {:ok, map()}
  def subscribe(%Server{} = server, requested) do
    {module, opts} = bus(server.subscription_bus)
    module.subscribe(requested, server.capabilities, opts)
  end

  defp publish(bus_config, event) do
    {module, opts} = bus(bus_config)
    module.publish(event, opts)
  end

  defp bus({module, opts}) when is_atom(module) and is_list(opts), do: {module, opts}
  defp bus(module) when is_atom(module), do: {module, []}
end
