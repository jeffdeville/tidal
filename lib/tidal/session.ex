defmodule Tidal.Session do
  @moduledoc """
  A GenServer that holds per-client MCP session state.

  Each connecting MCP client gets its own `Tidal.Session` process,
  supervised under `Tidal.SessionSupervisor`. Sessions are identified
  by a cryptographically random, URL-safe ID.

  The session GenServer is designed to receive protocol messages and
  dispatch them — actual message handling logic is added in later tasks.
  """

  use GenServer, restart: :temporary

  alias Tidal.Session.Options

  require Logger

  @type session_id :: String.t()

  @type state :: %{
          session_id: session_id(),
          capabilities: map(),
          server_info: map(),
          assigns: map(),
          timeout_ms: pos_integer()
        }

  # ── Client API ──────────────────────────────────────────────────────

  @doc """
  Starts a new session process under `Tidal.SessionSupervisor`.

  Returns `{:ok, session_id}` on success.

  ## Options

    * `:timeout` — inactivity timeout in milliseconds (default: 30 minutes)
    * `:capabilities` — initial capabilities map (default: `%{}`)
    * `:server_info` — server information map (default: `%{}`)

  """
  @spec start(keyword()) :: {:ok, session_id()} | {:error, term()}
  def start(opts \\ []) do
    with {:ok, validated} <- Options.validate(opts) do
      session_id = generate_session_id()

      init_arg = %{
        session_id: session_id,
        timeout_ms: validated[:timeout],
        capabilities: validated[:capabilities],
        server_info: validated[:server_info]
      }

      case DynamicSupervisor.start_child(
             Tidal.SessionSupervisor,
             {__MODULE__, init_arg}
           ) do
        {:ok, _pid} -> {:ok, session_id}
        {:error, _} = error -> error
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
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        end

      {:error, :not_found} ->
        {:error, :not_found}
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

  The session currently echoes the message back wrapped in a response.
  Actual method dispatch will be added in later tasks.
  """
  @spec handle_message(session_id(), struct()) :: {:ok, struct()} | {:error, :not_found}
  def handle_message(session_id, message) do
    case get(session_id) do
      {:ok, pid} -> {:ok, GenServer.call(pid, {:handle_message, message})}
      {:error, :not_found} -> {:error, :not_found}
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

    GenServer.start_link(__MODULE__, init_arg,
      name: {:via, Registry, {Tidal.SessionRegistry, session_id}}
    )
  end

  # ── Server Callbacks ────────────────────────────────────────────────

  @impl true
  def init(init_arg) do
    state = %{
      session_id: init_arg.session_id,
      capabilities: init_arg.capabilities,
      server_info: init_arg.server_info,
      assigns: %{},
      timeout_ms: init_arg.timeout_ms,
      subscribers: MapSet.new()
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
    # Stub: echo the method back as the result. Real dispatch comes in later tasks.
    response = %Tidal.JSONRPC.Response{
      id: request.id,
      result: %{"method" => request.method, "status" => "received"}
    }

    {:reply, response, state, state.timeout_ms}
  end

  def handle_call({:handle_message, %Tidal.JSONRPC.Notification{}}, _from, state) do
    # Notifications don't get responses
    {:reply, :no_response, state, state.timeout_ms}
  end

  def handle_call({:handle_message, _message}, _from, state) do
    {:reply, :no_response, state, state.timeout_ms}
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
  def handle_info(:timeout, state) do
    Logger.info("Session timed out: #{state.session_id}")
    {:stop, :normal, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state = update_in(state, [:subscribers], &MapSet.delete(&1, pid))
    {:noreply, state, state.timeout_ms}
  end

  # ── Helpers ─────────────────────────────────────────────────────────

  defp generate_session_id do
    :crypto.strong_rand_bytes(24)
    |> Base.url_encode64(padding: false)
  end
end
