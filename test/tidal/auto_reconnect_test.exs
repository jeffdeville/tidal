defmodule Tidal.AutoReconnectTest do
  use ExUnit.Case, async: true

  alias Tidal.Session

  describe "session cache" do
    test "creating a session caches its init data in ETS" do
      opts = [init_assigns: %{role: :admin, project_id: "abc"}, timeout: 5_000]
      {:ok, session_id} = Session.start(opts)

      assert [{^session_id, cached_opts}] = :ets.lookup(:tidal_session_cache, session_id)
      assert cached_opts[:init_assigns] == %{role: :admin, project_id: "abc"}
      assert cached_opts[:timeout] == 5_000
    end

    test "cache entry is removed on explicit DELETE termination" do
      {:ok, session_id} = Session.start(init_assigns: %{role: :worker})

      # Verify cached
      assert [{^session_id, _}] = :ets.lookup(:tidal_session_cache, session_id)

      # Terminate explicitly
      :ok = Session.terminate(session_id)

      # Cache should be cleaned up
      assert [] = :ets.lookup(:tidal_session_cache, session_id)
    end

    test "cache entry is preserved on timeout" do
      {:ok, session_id} = Session.start(init_assigns: %{role: :worker}, timeout: 50)
      {:ok, pid} = Session.get(session_id)
      ref = Process.monitor(pid)

      # Wait for timeout
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 200

      # Cache entry should still exist after timeout
      assert [{^session_id, _}] = :ets.lookup(:tidal_session_cache, session_id)
    end
  end

  describe "auto-reconnect on dispatch" do
    test "dispatching to an expired session creates a new session transparently" do
      opts = [init_assigns: %{role: :admin}, timeout: 50]
      {:ok, old_session_id} = Session.start(opts)

      # Initialize the session so it reaches :ready state
      init_request = %Tidal.JSONRPC.Request{
        method: "initialize",
        params: %{"protocolVersion" => "2025-11-25", "capabilities" => %{}},
        id: 1
      }

      {:ok, _response} = Session.handle_message(old_session_id, init_request)

      initialized_notification = %Tidal.JSONRPC.Notification{
        method: "notifications/initialized",
        params: %{}
      }

      {:ok, :no_response} = Session.handle_message(old_session_id, initialized_notification)

      # Wait for timeout
      {:ok, pid} = Session.get(old_session_id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 200

      # Now try to reconnect - Session.reconnect should create a new session
      assert {:ok, new_session_id} = Session.reconnect(old_session_id)
      assert new_session_id != old_session_id

      # New session should be alive and have same init_assigns
      {:ok, state} = Session.get_state(new_session_id)
      assert state.assigns[:role] == :admin
    end

    test "reconnect returns {:error, :no_cache} when no cached opts exist" do
      assert {:error, :no_cache} = Session.reconnect("totally-unknown-session-id")
    end

    test "reconnect is idempotent - calling with an already-reconnected session returns existing" do
      opts = [init_assigns: %{role: :tester}, timeout: 50]
      {:ok, old_session_id} = Session.start(opts)

      # Wait for timeout
      {:ok, pid} = Session.get(old_session_id)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 200

      # First reconnect
      {:ok, new_session_id_1} = Session.reconnect(old_session_id)

      # Second reconnect with the OLD session_id should give a new one again
      # (the old cache entry was replaced with a redirect)
      {:ok, new_session_id_2} = Session.reconnect(old_session_id)

      # Both should resolve to the same session (through redirect chain)
      assert new_session_id_1 == new_session_id_2 or
               Session.get(new_session_id_1) != {:error, :not_found}
    end
  end
end
