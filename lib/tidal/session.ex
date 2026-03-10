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
      timeout_ms: init_arg.timeout_ms
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

  @impl true
  def handle_cast(:touch, state) do
    {:noreply, state, state.timeout_ms}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.info("Session timed out: #{state.session_id}")
    {:stop, :normal, state}
  end

  # ── Helpers ─────────────────────────────────────────────────────────

  defp generate_session_id do
    :crypto.strong_rand_bytes(24)
    |> Base.url_encode64(padding: false)
  end
end
