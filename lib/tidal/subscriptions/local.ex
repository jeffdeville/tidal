defmodule Tidal.Subscriptions.Local do
  @moduledoc """
  Node-local subscription bus backed by a duplicate-key Registry.

  Each open `subscriptions/listen` request registers its own Plug process for
  exactly the event keys it accepted. Registry automatically removes entries
  when that request process exits.
  """

  @behaviour Tidal.SubscriptionBus

  @registry Tidal.SubscriptionRegistry

  @impl true
  def subscribe(requested, capabilities, _opts) when is_map(requested) do
    honored = honored_filter(requested, capabilities)

    honored
    |> registry_keys()
    |> Enum.uniq()
    |> Enum.each(fn key -> {:ok, _value} = Registry.register(@registry, key, nil) end)

    {:ok, honored}
  end

  @impl true
  def publish(event, _opts) do
    event
    |> event_key()
    |> dispatch(event)

    :ok
  end

  defp honored_filter(requested, capabilities) do
    %{}
    |> maybe_honor(
      "toolsListChanged",
      requested["toolsListChanged"] == true and
        get_in(capabilities, ["tools", "listChanged"]) == true,
      true
    )
    |> maybe_honor(
      "resourcesListChanged",
      requested["resourcesListChanged"] == true and
        get_in(capabilities, ["resources", "listChanged"]) == true,
      true
    )
    |> maybe_honor(
      "resourceSubscriptions",
      get_in(capabilities, ["resources", "subscribe"]) == true,
      valid_resource_uris(requested["resourceSubscriptions"])
    )
  end

  defp valid_resource_uris(uris) when is_list(uris), do: Enum.filter(uris, &is_binary/1)
  defp valid_resource_uris(_uris), do: []

  defp maybe_honor(filter, _key, false, _value), do: filter
  defp maybe_honor(filter, _key, true, []), do: filter
  defp maybe_honor(filter, key, true, value), do: Map.put(filter, key, value)

  defp registry_keys(filter) do
    []
    |> maybe_add_key(filter["toolsListChanged"] == true, :tools_list_changed)
    |> maybe_add_key(filter["resourcesListChanged"] == true, :resources_list_changed)
    |> add_resource_keys(filter["resourceSubscriptions"] || [])
  end

  defp maybe_add_key(keys, true, key), do: [key | keys]
  defp maybe_add_key(keys, false, _key), do: keys

  defp add_resource_keys(keys, uris) do
    Enum.reduce(uris, keys, fn uri, keys -> [{:resource_updated, uri} | keys] end)
  end

  defp event_key(:tools_list_changed), do: :tools_list_changed
  defp event_key(:resources_list_changed), do: :resources_list_changed
  defp event_key({:resource_updated, uri}), do: {:resource_updated, uri}

  defp dispatch(key, event) do
    Registry.dispatch(@registry, key, fn entries ->
      Enum.each(entries, fn {pid, _value} -> send(pid, {:tidal_subscription, event}) end)
    end)
  end
end
