defmodule Tidal.SessionTest do
  use ExUnit.Case, async: true

  alias Tidal.Session

  describe "start/1" do
    test "creates a session and returns a session ID" do
      assert {:ok, session_id} = Session.start()
      assert is_binary(session_id)
      assert byte_size(session_id) > 0
    end

    test "generates unique session IDs" do
      {:ok, id1} = Session.start()
      {:ok, id2} = Session.start()
      assert id1 != id2
    end

    test "session IDs are URL-safe base64" do
      {:ok, session_id} = Session.start()
      # URL-safe base64 only contains [A-Za-z0-9_-]
      assert session_id =~ ~r/^[A-Za-z0-9_-]+$/
    end

    test "accepts custom timeout option" do
      assert {:ok, session_id} = Session.start(timeout: 5_000)
      {:ok, state} = Session.get_state(session_id)
      assert state.timeout_ms == 5_000
    end

    test "accepts capabilities option" do
      caps = %{tools: true}
      assert {:ok, session_id} = Session.start(capabilities: caps)
      {:ok, state} = Session.get_state(session_id)
      assert state.capabilities == caps
    end

    test "accepts server_info option" do
      info = %{name: "test-server", version: "1.0"}
      assert {:ok, session_id} = Session.start(server_info: info)
      {:ok, state} = Session.get_state(session_id)
      assert state.server_info == info
    end

    test "rejects invalid options" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Session.start(timeout: -1)
    end

    test "rejects unknown options" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Session.start(bogus: true)
    end
  end

  describe "get/1" do
    test "returns {:ok, pid} for an existing session" do
      {:ok, session_id} = Session.start()
      assert {:ok, pid} = Session.get(session_id)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "returns {:error, :not_found} for a non-existent session" do
      assert {:error, :not_found} = Session.get("nonexistent-id")
    end
  end

  describe "terminate/1" do
    test "terminates an existing session" do
      {:ok, session_id} = Session.start()
      {:ok, pid} = Session.get(session_id)
      assert Process.alive?(pid)

      assert :ok = Session.terminate(session_id)

      # Process should be dead
      refute Process.alive?(pid)

      # terminate/1 waits for deregistration, but Registry cleanup is async
      wait_for_registry_cleanup(session_id)
      assert {:error, :not_found} = Session.get(session_id)
    end

    test "returns {:error, :not_found} for a non-existent session" do
      assert {:error, :not_found} = Session.terminate("nonexistent-id")
    end

    test "terminated session returns :not_found on subsequent lookup" do
      {:ok, session_id} = Session.start()

      :ok = Session.terminate(session_id)

      wait_for_registry_cleanup(session_id)
      assert {:error, :not_found} = Session.get(session_id)
      assert {:error, :not_found} = Session.get_state(session_id)
    end
  end

  describe "session isolation" do
    test "each session runs in its own process" do
      {:ok, id1} = Session.start()
      {:ok, id2} = Session.start()

      {:ok, pid1} = Session.get(id1)
      {:ok, pid2} = Session.get(id2)

      assert pid1 != pid2
    end

    test "crashing one session does not affect others" do
      {:ok, id1} = Session.start()
      {:ok, id2} = Session.start()

      {:ok, pid1} = Session.get(id1)
      {:ok, pid2} = Session.get(id2)

      # Monitor session 2 to ensure it stays alive
      ref = Process.monitor(pid2)

      # Crash session 1
      ref1 = Process.monitor(pid1)
      Process.exit(pid1, :kill)
      assert_receive {:DOWN, ^ref1, :process, ^pid1, :killed}

      # Session 2 should still be alive
      assert Process.alive?(pid2)
      assert {:ok, ^pid2} = Session.get(id2)

      # Session 1 should be gone
      wait_for_registry_cleanup(id1)
      assert {:error, :not_found} = Session.get(id1)

      # Clean up monitor
      Process.demonitor(ref, [:flush])
    end
  end

  describe "session timeout" do
    test "session auto-terminates after timeout" do
      {:ok, session_id} = Session.start(timeout: 50)
      {:ok, pid} = Session.get(session_id)
      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 200

      wait_for_registry_cleanup(session_id)
      assert {:error, :not_found} = Session.get(session_id)
    end

    test "touching a session resets the timeout" do
      {:ok, session_id} = Session.start(timeout: 100)
      {:ok, pid} = Session.get(session_id)
      ref = Process.monitor(pid)

      # Touch at 60ms (before the 100ms timeout)
      Process.sleep(60)
      :ok = Session.touch(session_id)

      # At 120ms from start, original timeout would have fired, but we touched
      Process.sleep(60)
      assert Process.alive?(pid)

      # Eventually it should time out
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 200
    end

    test "API calls reset the timeout" do
      {:ok, session_id} = Session.start(timeout: 100)
      {:ok, pid} = Session.get(session_id)
      ref = Process.monitor(pid)

      # Make an API call at 60ms
      Process.sleep(60)
      {:ok, _state} = Session.get_state(session_id)

      # At 120ms from start, original timeout would have fired
      Process.sleep(60)
      assert Process.alive?(pid)

      # Eventually it should time out
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 200
    end
  end

  describe "assigns" do
    test "can set and retrieve assigns" do
      {:ok, session_id} = Session.start()
      :ok = Session.assign(session_id, :user_id, 42)

      {:ok, state} = Session.get_state(session_id)
      assert state.assigns[:user_id] == 42
    end

    test "assign returns error for non-existent session" do
      assert {:error, :not_found} = Session.assign("nonexistent", :key, "value")
    end
  end

  describe "init_assigns" do
    test "initial assigns are available in session state" do
      {:ok, session_id} = Session.start(init_assigns: %{role: :admin, project_id: "abc"})
      {:ok, state} = Session.get_state(session_id)

      assert state.assigns[:role] == :admin
      assert state.assigns[:project_id] == "abc"
    end

    test "defaults to empty map when not provided" do
      {:ok, session_id} = Session.start()
      {:ok, state} = Session.get_state(session_id)

      assert state.assigns == %{}
    end

    test "can be updated via assign/3 after creation" do
      {:ok, session_id} = Session.start(init_assigns: %{role: :admin})
      :ok = Session.assign(session_id, :extra, "value")
      {:ok, state} = Session.get_state(session_id)

      assert state.assigns[:role] == :admin
      assert state.assigns[:extra] == "value"
    end
  end

  describe "get_state/1" do
    test "returns full session state" do
      {:ok, session_id} = Session.start(capabilities: %{tools: true})
      {:ok, state} = Session.get_state(session_id)

      assert state.session_id == session_id
      assert state.capabilities == %{tools: true}
      assert state.server_info == %{}
      assert state.assigns == %{}
      assert is_integer(state.timeout_ms)
    end

    test "returns error for non-existent session" do
      assert {:error, :not_found} = Session.get_state("nonexistent")
    end
  end

  describe "secure session IDs" do
    test "session IDs have sufficient entropy (24 random bytes = 32 chars base64)" do
      {:ok, session_id} = Session.start()
      # 24 bytes encoded as base64url without padding = 32 chars
      assert byte_size(session_id) == 32
    end

    test "session IDs are cryptographically random (no collisions in 100 sessions)" do
      ids =
        for _i <- 1..100 do
          {:ok, id} = Session.start()
          id
        end

      assert length(Enum.uniq(ids)) == 100
    end
  end

  # Registry cleanup is asynchronous — the Registry process must handle
  # the DOWN message from the terminated GenServer before the key is removed.
  defp wait_for_registry_cleanup(session_id, attempts \\ 50) do
    case Registry.lookup(Tidal.SessionRegistry, session_id) do
      [] ->
        :ok

      _entries when attempts > 0 ->
        Process.sleep(1)
        wait_for_registry_cleanup(session_id, attempts - 1)

      _entries ->
        flunk("Registry did not clean up session #{session_id} in time")
    end
  end
end
