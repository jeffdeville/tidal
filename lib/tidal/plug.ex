defmodule Tidal.Plug do
  @moduledoc """
  A Plug router implementing the MCP Streamable HTTP transport.

  Handles three HTTP methods on the MCP endpoint:

    * `POST` — receives JSON-RPC messages, routes to the appropriate session,
      returns `application/json` responses
    * `GET` — opens a Server-Sent Events (SSE) stream for server-initiated messages
    * `DELETE` — terminates the session identified by the `Mcp-Session-Id` header

  ## Usage

  Mount this plug in your endpoint or router:

      # In a Plug.Router
      forward "/mcp", to: Tidal.Plug

      # Or start directly with Bandit
      Bandit.start_link(plug: Tidal.Plug, port: 4000)

  ## Headers

    * `Mcp-Session-Id` — required for established sessions (POST with existing session,
      GET, DELETE). Generated automatically for new sessions on the first POST (initialize).
    * `Accept` — must include both `application/json` and `text/event-stream` for
      POST and GET requests per the MCP spec.
    * `Content-Type` — must be `application/json` for POST requests.
  """

  use Plug.Router

  alias Tidal.JSONRPC
  alias Tidal.Session

  require Tidal.JSONRPC.ErrorCodes, as: ErrorCodes

  plug(:match)
  plug(:dispatch)

  @doc """
  Initializes the plug with session options.

  Options are passed through to `Tidal.Session.start/1` when creating new sessions.
  Accepts all options supported by `Tidal.Session.Options`.
  """
  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    conn = Plug.Conn.put_private(conn, :tidal_session_opts, opts)
    super(conn, opts)
  end

  # ── POST — Client sends JSON-RPC messages ────────────────────────────

  post "/" do
    with :ok <- validate_accept(conn),
         :ok <- validate_content_type(conn),
         {:ok, body} <- read_body_string(conn),
         {:ok, message} <- decode_message(body) do
      handle_post(conn, message)
    else
      {:error, status, body} ->
        send_json_response(conn, status, body)
    end
  end

  # ── GET — SSE stream for server-initiated messages ───────────────────

  get "/" do
    with :ok <- validate_accept(conn),
         {:ok, session_id} <- require_session_header(conn),
         {:ok_or_reconnected, resolved_session_id} <- resolve_session(session_id) do
      serve_sse(conn, resolved_session_id)
    else
      {:error, status, body} ->
        send_json_response(conn, status, body)
    end
  end

  # ── DELETE — Terminate session ───────────────────────────────────────

  delete "/" do
    with {:ok, session_id} <- require_session_header(conn),
         :ok <- Session.terminate(session_id) do
      send_resp(conn, 204, "")
    else
      {:error, :not_found} ->
        send_json_response(conn, 404, %{"error" => "session not found"})

      {:error, status, body} ->
        send_json_response(conn, status, body)
    end
  end

  # Catch-all for unsupported methods
  match _ do
    send_resp(conn, 405, "Method Not Allowed")
  end

  # ── POST handling ────────────────────────────────────────────────────

  defp handle_post(conn, %JSONRPC.Request{method: "initialize"} = request) do
    case get_session_id(conn) do
      {:ok, session_id} ->
        # Session already exists — route to it (will be rejected by protocol state machine)
        dispatch_to_session(conn, session_id, request)

      :no_session ->
        create_and_initialize(conn, request)
    end
  end

  defp handle_post(conn, message) do
    case get_session_id(conn) do
      {:ok, session_id} ->
        dispatch_to_session(conn, session_id, message)

      :no_session ->
        send_json_response(conn, 400, %{
          "error" => "Mcp-Session-Id header required for non-initialize requests"
        })
    end
  end

  defp create_and_initialize(conn, request) do
    session_opts = Map.get(conn.private, :tidal_session_opts, [])

    case Session.start(session_opts) do
      {:ok, session_id} ->
        {:ok, response} = Session.handle_message(session_id, request)

        conn
        |> put_resp_header("mcp-session-id", session_id)
        |> send_json_response(200, response)

      {:error, reason} ->
        send_json_response(conn, 500, internal_error(request.id, inspect(reason)))
    end
  end

  defp dispatch_to_session(conn, session_id, %JSONRPC.Request{} = request) do
    case Session.handle_message(session_id, request) do
      {:ok, response} ->
        conn
        |> put_resp_header("mcp-session-id", session_id)
        |> send_json_response(200, response)

      {:error, :not_found} ->
        maybe_reconnect_and_dispatch(conn, session_id, request)
    end
  end

  defp dispatch_to_session(conn, session_id, %JSONRPC.Notification{} = notification) do
    case Session.handle_message(session_id, notification) do
      {:ok, :no_response} ->
        conn
        |> put_resp_header("mcp-session-id", session_id)
        |> send_resp(202, "")

      {:error, :not_found} ->
        maybe_reconnect_and_dispatch(conn, session_id, notification)
    end
  end

  defp dispatch_to_session(conn, session_id, messages) when is_list(messages) do
    responses =
      messages
      |> Enum.map(&dispatch_batch_item(session_id, &1))
      |> Enum.reject(&is_nil/1)

    case responses do
      [] ->
        conn
        |> put_resp_header("mcp-session-id", session_id)
        |> send_resp(202, "")

      responses ->
        conn
        |> put_resp_header("mcp-session-id", session_id)
        |> send_json_response(200, responses)
    end
  end

  defp dispatch_batch_item(session_id, %JSONRPC.Request{} = request) do
    case Session.handle_message(session_id, request) do
      {:ok, response} -> response
      {:error, :not_found} -> nil
    end
  end

  defp dispatch_batch_item(session_id, %JSONRPC.Notification{} = notification) do
    Session.handle_message(session_id, notification)
    nil
  end

  defp dispatch_batch_item(_session_id, %JSONRPC.Error{} = error), do: error
  defp dispatch_batch_item(_session_id, _other), do: nil

  # ── SSE stream ───────────────────────────────────────────────────────

  defp serve_sse(conn, session_id) do
    :ok = Session.subscribe(session_id)

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("mcp-session-id", session_id)
      |> send_chunked(200)

    sse_loop(conn)
  end

  defp sse_loop(conn) do
    receive do
      {:sse_message, message} ->
        case format_sse_event(message) do
          {:ok, event_data} ->
            case Plug.Conn.chunk(conn, event_data) do
              {:ok, conn} -> sse_loop(conn)
              {:error, _reason} -> conn
            end

          {:error, _} ->
            sse_loop(conn)
        end

      :close ->
        conn
    end
  end

  defp format_sse_event(message) do
    case JSONRPC.encode(message) do
      {:ok, json} ->
        {:ok, "event: message\ndata: #{json}\n\n"}

      error ->
        error
    end
  end

  # ── Validation helpers ───────────────────────────────────────────────

  defp validate_accept(conn) do
    accept = get_req_header(conn, "accept") |> Enum.join(", ")

    has_json = String.contains?(accept, "application/json")
    has_sse = String.contains?(accept, "text/event-stream")
    has_wildcard = String.contains?(accept, "*/*")

    if (has_json and has_sse) or has_wildcard do
      :ok
    else
      {:error, 406,
       %{"error" => "Accept header must include both application/json and text/event-stream"}}
    end
  end

  defp validate_content_type(conn) do
    content_type = get_req_header(conn, "content-type") |> Enum.join("")

    if String.contains?(content_type, "application/json") do
      :ok
    else
      {:error, 400, %{"error" => "Content-Type must be application/json"}}
    end
  end

  # When the body has already been parsed (e.g., by Phoenix's Plug.Parsers in
  # the endpoint), Plug.Conn.read_body/1 returns an empty binary. In that case,
  # re-encode the parsed body_params back to JSON. This lets Tidal.Plug work
  # behind framework endpoints that consume the body before routing.
  defp read_body_string(conn) do
    case conn.body_params do
      %Plug.Conn.Unfetched{} ->
        read_raw_body(conn)

      params when is_map(params) and map_size(params) > 0 ->
        {:ok, Jason.encode!(params)}

      _ ->
        read_raw_body(conn)
    end
  end

  defp read_raw_body(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, _conn} -> {:ok, body}
      {:more, _partial, _conn} -> {:error, 413, %{"error" => "Request body too large"}}
      {:error, reason} -> {:error, 400, %{"error" => "Failed to read body: #{inspect(reason)}"}}
    end
  end

  defp decode_message(body) do
    case JSONRPC.decode(body) do
      {:ok, message} ->
        {:ok, message}

      {:error, %JSONRPC.Error{} = error} ->
        {:error, 400, error}
    end
  end

  defp get_session_id(conn) do
    case get_req_header(conn, "mcp-session-id") do
      [session_id | _] -> {:ok, session_id}
      [] -> :no_session
    end
  end

  defp require_session_header(conn) do
    case get_session_id(conn) do
      {:ok, session_id} ->
        {:ok, session_id}

      :no_session ->
        {:error, 400, %{"error" => "Mcp-Session-Id header is required"}}
    end
  end

  defp resolve_session(session_id) do
    case Session.get(session_id) do
      {:ok, _pid} ->
        {:ok_or_reconnected, session_id}

      {:error, :not_found} ->
        case Session.reconnect(session_id) do
          {:ok, new_session_id} -> {:ok_or_reconnected, new_session_id}
          _ -> {:error, 404, %{"error" => "session not found"}}
        end
    end
  end

  defp maybe_reconnect_and_dispatch(conn, old_session_id, message) do
    case Session.reconnect(old_session_id) do
      {:ok, new_session_id} ->
        # Re-initialize the new session before dispatching
        reconnect_and_reinitialize(conn, new_session_id, message)

      _ ->
        send_json_response(conn, 404, %{"error" => "session not found"})
    end
  end

  defp reconnect_and_reinitialize(conn, new_session_id, %JSONRPC.Request{} = request) do
    # The new session is in :created state — initialize it first
    init_request = %JSONRPC.Request{
      method: "initialize",
      params: %{"protocolVersion" => "2025-11-25", "capabilities" => %{}},
      id: "__reconnect_init__"
    }

    initialized = %Tidal.JSONRPC.Notification{
      method: "notifications/initialized",
      params: %{}
    }

    with {:ok, _init_response} <- Session.handle_message(new_session_id, init_request),
         {:ok, :no_response} <- Session.handle_message(new_session_id, initialized),
         {:ok, response} <- Session.handle_message(new_session_id, request) do
      conn
      |> put_resp_header("mcp-session-id", new_session_id)
      |> send_json_response(200, response)
    else
      {:error, _reason} ->
        send_json_response(conn, 500, %{"error" => "reconnect failed"})
    end
  end

  defp reconnect_and_reinitialize(conn, new_session_id, %JSONRPC.Notification{} = notification) do
    init_request = %JSONRPC.Request{
      method: "initialize",
      params: %{"protocolVersion" => "2025-11-25", "capabilities" => %{}},
      id: "__reconnect_init__"
    }

    initialized = %Tidal.JSONRPC.Notification{
      method: "notifications/initialized",
      params: %{}
    }

    with {:ok, _init_response} <- Session.handle_message(new_session_id, init_request),
         {:ok, :no_response} <- Session.handle_message(new_session_id, initialized) do
      case Session.handle_message(new_session_id, notification) do
        {:ok, :no_response} ->
          conn
          |> put_resp_header("mcp-session-id", new_session_id)
          |> send_resp(202, "")

        {:error, _reason} ->
          send_json_response(conn, 500, %{"error" => "reconnect failed"})
      end
    else
      {:error, _reason} ->
        send_json_response(conn, 500, %{"error" => "reconnect failed"})
    end
  end

  defp send_json_response(conn, status, body) do
    {:ok, json} = Jason.encode(body)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
  end

  defp internal_error(id, detail) do
    %JSONRPC.Error{
      id: id,
      code: ErrorCodes.internal_error(),
      message: "Internal error",
      data: detail
    }
  end
end
