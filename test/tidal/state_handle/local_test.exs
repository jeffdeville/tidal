defmodule Tidal.StateHandle.LocalTest do
  use Tidal.Case, async: true

  alias Tidal.RequestContext
  alias Tidal.Server
  alias Tidal.StateHandle

  setup %{config: arena} do
    server = Server.new!()

    context = %RequestContext{
      server: server,
      protocol_version: "2026-07-28",
      client_capabilities: %{},
      auth_context: %{subject: "user-1"}
    }

    %{arena: arena, context: context}
  end

  test "an opaque handle resolves explicit application state across fresh requests", %{context: context} do
    assert {:ok, handle} = StateHandle.create(context, %{count: 1})
    assert is_binary(handle)
    refute handle =~ inspect(self())

    fresh_context = %{context | client_info: %{"name" => "another-listener", "version" => "1"}}

    assert {:ok, %{count: 1}} = StateHandle.fetch(fresh_context, handle)

    assert {:ok, 2} =
             StateHandle.transact(fresh_context, handle, fn state ->
               next = %{state | count: state.count + 1}
               {:ok, next, next.count}
             end)

    assert {:ok, %{count: 2}} = StateHandle.fetch(context, handle)
  end

  test "authorizes every handle operation", %{context: context} do
    assert {:ok, handle} = StateHandle.create(context, :secret)
    other_context = %{context | auth_context: %{subject: "user-2"}}

    assert {:error, :unauthorized} = StateHandle.fetch(other_context, handle)
    assert {:error, :unauthorized} = StateHandle.destroy(other_context, handle)
    assert {:ok, :secret} = StateHandle.fetch(context, handle)
  end

  test "serializes concurrent mutations for one handle without serializing other requests", %{
    context: context
  } do
    assert {:ok, handle} = StateHandle.create(context, 0)

    1..100
    |> Arena.Task.async_stream(
      fn _ ->
        StateHandle.transact(context, handle, fn value -> {:ok, value + 1, :incremented} end)
      end,
      max_concurrency: 20
    )
    |> Enum.each(fn result -> assert result == {:ok, {:ok, :incremented}} end)

    assert {:ok, 100} = StateHandle.fetch(context, handle)
  end

  test "Arena ownership is propagated into the state actor", %{arena: arena, context: context} do
    assert {:ok, handle} = StateHandle.create(context, :value)
    pid = Tidal.StateHandle.Local.Actor.get_pid(%{handle: handle})

    assert {:dictionary, dictionary} = Process.info(pid, :dictionary)
    assert %Arena.Config{owner: owner} = Keyword.fetch!(dictionary, :arena_config)
    assert owner == arena.owner
  end

  test "destroy makes a handle unresolvable", %{context: context} do
    assert {:ok, handle} = StateHandle.create(context, :value)
    assert :ok = StateHandle.destroy(context, handle)
    assert {:error, :not_found} = StateHandle.fetch(context, handle)
  end

  test "returns an explicit error when state handles are disabled", %{context: context} do
    context = %{context | server: Server.new!(state_resolver: nil)}

    assert {:error, :state_handles_disabled} = StateHandle.create(context, %{})
    assert {:error, :state_handles_disabled} = StateHandle.fetch(context, "missing")
  end
end
