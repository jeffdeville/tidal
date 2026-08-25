defmodule Tidal.Protocol.InputRequiredResultTest do
  use ExUnit.Case, async: true

  alias Tidal.Protocol.InputRequiredResult

  test "accepts either input requests, request state, or both" do
    assert InputRequiredResult.new!(request_state: "opaque") |> InputRequiredResult.to_map() == %{
             "requestState" => "opaque",
             "resultType" => "input_required"
           }

    assert InputRequiredResult.new!(input_requests: %{"question" => %{}})
           |> InputRequiredResult.to_map() == %{
             "inputRequests" => %{"question" => %{}},
             "resultType" => "input_required"
           }
  end

  test "rejects a result with neither continuation mechanism" do
    assert_raise ArgumentError, ~r/at least one/, fn ->
      InputRequiredResult.new!([])
    end
  end
end
