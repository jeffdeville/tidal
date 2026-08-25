defmodule Tidal.SubscriptionBus do
  @moduledoc """
  Event-bus boundary for `subscriptions/listen` streams.

  The built-in bus is node-local. A clustered deployment can provide an
  implementation backed by distributed PubSub or an external broker so a
  publisher reaches whichever node owns the open HTTP response stream.
  """

  @type filter :: map()
  @type event :: :tools_list_changed | :resources_list_changed | {:resource_updated, String.t()}

  @callback subscribe(filter(), capabilities :: map(), keyword()) :: {:ok, filter()}
  @callback publish(event(), keyword()) :: :ok
end
