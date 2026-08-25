defmodule Tidal.RequestStateTest do
  use Tidal.Case, async: true

  alias Tidal.RequestContext
  alias Tidal.RequestState
  alias Tidal.Server

  @secret String.duplicate("s", 32)

  test "signs a self-contained continuation bound to authorization and expiry" do
    context = context(%{subject: "user-1"})
    assert {:ok, token} = RequestState.sign(context, %{"step" => 2}, expires_in_ms: 60_000)
    assert {:ok, %{"step" => 2}} = RequestState.verify(context, token)

    assert {:error, :authorization_mismatch} =
             RequestState.verify(context(%{subject: "user-2"}), token)

    assert {:error, :invalid_request_state} = RequestState.verify(context, token <> "tampered")
  end

  test "binds the continuation to the original request" do
    context = %{context(%{subject: "user-1"}) | request_fingerprint: "original"}
    assert {:ok, token} = RequestState.sign(context, %{"step" => 2})

    assert {:error, :request_mismatch} =
             RequestState.verify(%{context | request_fingerprint: "different"}, token)
  end

  test "rejects expired continuations" do
    context = context(%{subject: "user-1"})
    assert {:ok, token} = RequestState.sign(context, %{"step" => 2}, expires_in_ms: -1)
    assert {:error, :expired_request_state} = RequestState.verify(context, token)
  end

  test "requires an explicit deployment secret" do
    context = %RequestContext{
      server: Server.new!(),
      protocol_version: "2026-07-28",
      client_capabilities: %{}
    }

    assert {:error, :request_state_secret_not_configured} = RequestState.sign(context, %{})
  end

  defp context(auth_context) do
    %RequestContext{
      server: Server.new!(request_state_secret: @secret),
      protocol_version: "2026-07-28",
      client_capabilities: %{},
      auth_context: auth_context
    }
  end
end
