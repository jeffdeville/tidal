defmodule Tidal.RequestContext do
  @moduledoc """
  Immutable context for one stateless MCP request.

  The context is reconstructed from the current request and is never used as an
  implicit cross-request session. Application state that survives a request must
  be addressed explicitly by a tool argument or extension handle.

  Tool and resource handlers normally consume these fields:

    * `auth_context` — copied from `conn.assigns.tidal_auth_context`.
    * `assigns` — application values returned by the configured context builder.
    * `client_capabilities` and `client_info` — validated request metadata.
    * `input_responses` and `request_state` — multi-round-trip retry values.
    * `transport` — current host, method, path, peer, and scheme.

  The remaining fields support protocol validation and observability. Treat the
  struct as immutable and request-scoped.
  """

  alias Tidal.Server

  @enforce_keys [:server, :protocol_version, :client_capabilities]
  defstruct [
    :server,
    :protocol_version,
    :client_info,
    :log_level,
    :auth_context,
    :input_responses,
    :request_state,
    :request_fingerprint,
    client_capabilities: %{},
    trace_context: %{},
    assigns: %{},
    transport: %{}
  ]

  @typedoc "Validated application and transport context for one MCP request."
  @type t :: %__MODULE__{
          server: Server.t(),
          protocol_version: String.t(),
          client_capabilities: map(),
          client_info: map() | nil,
          log_level: String.t() | nil,
          trace_context: map(),
          auth_context: term(),
          input_responses: map() | nil,
          request_state: String.t() | nil,
          request_fingerprint: String.t() | nil,
          assigns: map(),
          transport: map()
        }

  @doc """
  Builds context from validated request metadata and the current connection.

  Applications usually configure `Tidal.Plug` with `:context_builder` instead
  of calling this function. The builder receives the same connection and
  metadata map and may return a map, `{:ok, map}`, or `{:error, reason}`.
  Exceptions become `{:error, {:context_builder_failed, exception}}`; other
  invalid return values become `{:error, {:invalid_context_builder_result,
  value}}`.
  """
  @spec new(Server.t(), Plug.Conn.t(), map()) :: {:ok, t()} | {:error, term()}
  def new(%Server{} = server, %Plug.Conn{} = conn, metadata) when is_map(metadata) do
    with {:ok, assigns} <- build_assigns(server, conn, metadata) do
      {:ok,
       %__MODULE__{
         server: server,
         protocol_version: Map.fetch!(metadata, :protocol_version),
         client_capabilities: Map.fetch!(metadata, :client_capabilities),
         client_info: Map.get(metadata, :client_info),
         log_level: Map.get(metadata, :log_level),
         trace_context: Map.get(metadata, :trace_context, %{}),
         auth_context: Map.get(conn.assigns, :tidal_auth_context),
         input_responses: Map.get(metadata, :input_responses),
         request_state: Map.get(metadata, :request_state),
         request_fingerprint: Map.get(metadata, :request_fingerprint),
         assigns: assigns,
         transport: transport_context(conn)
       }}
    end
  end

  defp build_assigns(%Server{context_builder: nil, init_assigns: assigns}, _conn, _metadata),
    do: {:ok, assigns}

  defp build_assigns(%Server{context_builder: builder}, conn, metadata) do
    case builder.(conn, metadata) do
      {:ok, assigns} when is_map(assigns) -> {:ok, assigns}
      {:error, _reason} = error -> error
      assigns when is_map(assigns) -> {:ok, assigns}
      other -> {:error, {:invalid_context_builder_result, other}}
    end
  rescue
    exception -> {:error, {:context_builder_failed, exception}}
  end

  defp transport_context(conn) do
    %{
      host: conn.host,
      method: conn.method,
      path: conn.request_path,
      peer: conn.remote_ip,
      scheme: conn.scheme
    }
  end
end
