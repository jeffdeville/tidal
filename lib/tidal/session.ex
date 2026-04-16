defmodule Tidal.Session do
  @moduledoc """
  A GenServer that holds per-client MCP session state.

  Each connecting MCP client gets its own `Tidal.Session` process,
  supervised under `Tidal.SessionSupervisor`. Sessions are identified
  by a cryptographically random, URL-safe ID.

  The session tracks its lifecycle state through:

    * `:created` — initial state, only `initialize` is accepted
    * `:initializing` — after initialize response, awaiting `notifications/initialized`
    * `:ready` — fully initialized, all methods accepted
    * `:shutting_down` — shutdown requested, session will terminate

  Protocol message dispatch is handled by `Tidal.Protocol`.
  """

  use GenServer, restart: :temporary

  alias Tidal.Protocol
  alias Tidal.Session.Options

  require Logger

  @type session_id :: String.t()

  @type state :: %{
          session_id: session_id(),
          lifecycle: :created | :initializing | :ready | :shutting_down,
          capabilities: map(),
          server_info: map(),
          client_info: map(),
          client_capabilities: map(),
          assigns: map(),
          timeout_ms: pos_integer(),
          subscribers: MapSet.t(),
          tool_modules: [module()],
          resource_handlers: [module()],
          middleware: [module()],
          resource_subscriptions: MapSet.t()
        }

  # ── Client API ──────────────────────────────────────────────────────

  @doc """
  Starts a new session process under `Tidal.SessionSupervisor`.

  Returns `{:ok, session_id}` on success.

  ## Options

    * `:timeout` — inactivity timeout in milliseconds (default: 30 minutes)
    * `:capabilities` — server capabilities map (default: `%{}`)
    * `:server_info` — server information map (default: `%{}`)

  """
  @spec start(keyword()) :: {:ok, session_id()} | {:error, term()}
  def start(opts \\ []) do
    with {:ok, validated} <- Options.validate(opts) do
      session_id = generate_session_id()

      tool_modules = validated[:tool_modules]

      capabilities =
        if tool_modules != [] do
          Map.put(validated[:capabilities], "tools", %{})
        else
          validated[:capabilities]
        end

      init_arg = %{
        session_id: session_id,
        timeout_ms: validated[:timeout],
        capabilities: capabilities,
        server_info: validated[:server_info],
        tool_modules: tool_modules,
        resource_handlers: validated[:resource_handlers],
        middleware: validated[:middleware],
        init_assigns: validated[:init_assigns]
      }

      case DynamicSupervisor.start_child(
             Tidal.SessionSupervisor,
             {__MODULE__, init_arg}
           ) do
        {:ok, _pid} ->
          cache_session_opts(session_id, opts)
          {:ok, session_id}

        {:error, _} = error ->
          error
      end
    end
  end

  @doc """
  Looks up a session process by its ID.

  Returns `{:ok, pid}` or `{:error, :not_found}`.
  """
  @spec get(session_id()) :: {:ok, pid()} | {:error, :not_found}
  def get(session_id) do
    case Registry.lookup(Tidal.SessionRegistry, session_id) do
      [{pid, _value}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Terminates a session by its ID.

  Returns `:ok` or `{:error, :not_found}`.
  """
  @spec terminate(session_id()) :: :ok | {:error, :not_found}
  def terminate(session_id) do
    case get(session_id) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        GenServer.stop(pid, :normal)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} ->
            delete_session_cache(session_id)
            :ok
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Attempts to create a new session using cached opts from an expired session.

  When a session times out, its ETS cache entry is preserved. This function
  looks up the cached opts, creates a new session with the same configuration,
  and updates the cache so the old session_id redirects to the new one.

  Returns `{:ok, new_session_id}` or `{:error, :no_cache}`.
  """
  @spec reconnect(session_id()) :: {:ok, session_id()} | {:error, :no_cache | term()}
  def reconnect(old_session_id) do
    case lookup_session_cache(old_session_id) do
      {:ok, {:redirect, new_session_id}} ->
        # Already reconnected — follow the redirect if the target is alive
        case get(new_session_id) do
          {:ok, _pid} -> {:ok, new_session_id}
          {:error, :not_found} -> do_reconnect(old_session_id, new_session_id)
        end

      {:ok, opts} when is_list(opts) ->
        do_reconnect(old_session_id, opts)

      :error ->
        {:error, :no_cache}
    end
  end

  @doc """
  Touches the session to reset its inactivity timeout.
  """
  @spec touch(session_id()) :: :ok | {:error, :not_found}
  def touch(session_id) do
    case get(session_id) do
      {:ok, pid} -> GenServer.cast(pid, :touch)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Gets the current state of a session as a map.
  """
  @spec get_state(session_id()) :: {:ok, state()} | {:error, :not_found}
  def get_state(session_id) do
    case get(session_id) do
      {:ok, pid} -> {:ok, GenServer.call(pid, :get_state)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Reads or updates a value in the session's assigns.
  """
  @spec assign(session_id(), atom(), term()) :: :ok | {:error, :not_found}
  def assign(session_id, key, value) do
    case get(session_id) do
      {:ok, pid} -> GenServer.call(pid, {:assign, key, value})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Sends a JSON-RPC message to the session and returns the response.

  Dispatches through `Tidal.Protocol` which enforces lifecycle state
  and routes to the appropriate handler.
  """
  @spec handle_message(session_id(), struct()) ::
          {:ok, struct()} | {:ok, :no_response} | {:error, :not_found | :shutting_down}
  def handle_message(session_id, message) do
    case get(session_id) do
      {:ok, pid} ->
        try do
          GenServer.call(pid, {:handle_message, message})
        catch
          :exit, _ -> {:error, :not_found}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Registers a process to receive server-initiated SSE messages for a session.

  The caller process will receive `{:sse_message, message}` tuples.
  """
  @spec subscribe(session_id(), pid()) :: :ok | {:error, :not_found}
  def subscribe(session_id, subscriber_pid \\ self()) do
    case get(session_id) do
      {:ok, pid} -> GenServer.call(pid, {:subscribe, subscriber_pid})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Sends a server-initiated notification to all SSE subscribers for a session.
  """
  @spec notify(session_id(), struct()) :: :ok | {:error, :not_found}
  def notify(session_id, message) do
    case get(session_id) do
      {:ok, pid} -> GenServer.cast(pid, {:notify, message})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc false
  def start_link(init_arg) do
    session_id = init_arg.session_id

    GenServer.start_link(__MODULE__, init_arg, name: {:via, Registry, {Tidal.SessionRegistry, session_id}})
  end

  # ── Server Callbacks ────────────────────────────────────────────────

  @impl true
  def init(init_arg) do
    state = %{
      session_id: init_arg.session_id,
      lifecycle: :created,
      capabilities: init_arg.capabilities,
      server_info: init_arg.server_info,
      client_info: %{},
      client_capabilities: %{},
      assigns: Map.get(init_arg, :init_assigns, %{}),
      timeout_ms: init_arg.timeout_ms,
      subscribers: MapSet.new(),
      tool_modules: Map.get(init_arg, :tool_modules, []),
      resource_handlers: Map.get(init_arg, :resource_handlers, []),
      middleware: Map.get(init_arg, :middleware, []),
      resource_subscriptions: MapSet.new()
    }

    Logger.debug("Session started: #{init_arg.session_id}")
    {:ok, state, state.timeout_ms}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state, state.timeout_ms}
  end

  def handle_call({:assign, key, value}, _from, state) do
    state = put_in(state, [:assigns, key], value)
    {:reply, :ok, state, state.timeout_ms}
  end

  def handle_call({:handle_message, %Tidal.JSONRPC.Request{} = request}, _from, state) do
    {response, new_state} = Protocol.handle_request(request, state)

    if new_state.lifecycle == :shutting_down do
      {:reply, {:ok, response}, new_state, 0}
    else
      {:reply, {:ok, response}, new_state, new_state.timeout_ms}
    end
  end

  def handle_call({:handle_message, %Tidal.JSONRPC.Notification{} = notification}, _from, state) do
    case Protocol.handle_notification(notification, state) do
      {:ok, new_state} ->
        {:reply, {:ok, :no_response}, new_state, new_state.timeout_ms}

      {:error, _reason, new_state} ->
        # Notifications don't get error responses per JSON-RPC spec
        {:reply, {:ok, :no_response}, new_state, new_state.timeout_ms}
    end
  end

  def handle_call({:handle_message, _message}, _from, state) do
    {:reply, {:ok, :no_response}, state, state.timeout_ms}
  end

  def handle_call({:subscribe, subscriber_pid}, _from, state) do
    Process.monitor(subscriber_pid)
    state = update_in(state, [:subscribers], &MapSet.put(&1, subscriber_pid))
    {:reply, :ok, state, state.timeout_ms}
  end

  @impl true
  def handle_cast(:touch, state) do
    {:noreply, state, state.timeout_ms}
  end

  def handle_cast({:notify, message}, state) do
    for pid <- state.subscribers do
      send(pid, {:sse_message, message})
    end

    {:noreply, state, state.timeout_ms}
  end

  @impl true
  def handle_info(:timeout, %{lifecycle: :shutting_down} = state) do
    Logger.info("Session shutting down: #{state.session_id}")
    {:stop, :normal, state}
  end

  def handle_info(:timeout, state) do
    Logger.info("Session timed out: #{state.session_id}")
    {:stop, :normal, state}
  end

  def handle_info({:resource_updated, uri, notification}, state) do
    if MapSet.member?(state.resource_subscriptions, uri) do
      for pid <- state.subscribers do
        send(pid, {:sse_message, notification})
      end
    end

    {:noreply, state, state.timeout_ms}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state = update_in(state, [:subscribers], &MapSet.delete(&1, pid))
    {:noreply, state, state.timeout_ms}
  end

  @impl true
  def terminate(_reason, %{lifecycle: :shutting_down} = state) do
    delete_session_cache(state.session_id)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  # ── Helpers ─────────────────────────────────────────────────────────

  defp generate_session_id do
    :crypto.strong_rand_bytes(24)
    |> Base.url_encode64(padding: false)
  end

  defp do_reconnect(old_session_id, redirect_session_id) when is_binary(redirect_session_id) do
    # The redirect target is dead too — look up the original opts from the redirect chain
    case lookup_session_cache(redirect_session_id) do
      {:ok, opts} when is_list(opts) ->
        do_reconnect(old_session_id, opts)

      _ ->
        {:error, :no_cache}
    end
  end

  defp do_reconnect(old_session_id, opts) when is_list(opts) do
    case start(opts) do
      {:ok, new_session_id} ->
        # Replace old cache entry with a redirect to the new session
        :ets.insert(:tidal_session_cache, {old_session_id, {:redirect, new_session_id}})
        {:ok, new_session_id}

      {:error, _} = error ->
        error
    end
  end

  # ── Session Cache ──────────────────────────────────────────────────

  defp cache_session_opts(session_id, opts) do
    :ets.insert(:tidal_session_cache, {session_id, opts})
  end

  defp delete_session_cache(session_id) do
    :ets.delete(:tidal_session_cache, session_id)
  end

  defp lookup_session_cache(session_id) do
    case :ets.lookup(:tidal_session_cache, session_id) do
      [{^session_id, value}] -> {:ok, value}
      [] -> :error
    end
  end
end
