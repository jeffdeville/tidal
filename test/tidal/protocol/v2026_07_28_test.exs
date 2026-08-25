defmodule Tidal.Protocol.V20260728Test do
  use Tidal.Case, async: true

  alias Tidal.JSONRPC.Request
  alias Tidal.Protocol.V20260728
  alias Tidal.RequestContext
  alias Tidal.Server

  test "a graceful subscription result carries its subscription id" do
    context = %RequestContext{
      server: Server.new!(),
      protocol_version: "2026-07-28",
      client_capabilities: %{}
    }

    request = %Request{id: "subscription-1", method: "subscriptions/listen", params: %{}}
    {200, response} = V20260728.handle(request, context)

    assert response.result["_meta"]["io.modelcontextprotocol/subscriptionId"] ==
             "subscription-1"
  end
end
