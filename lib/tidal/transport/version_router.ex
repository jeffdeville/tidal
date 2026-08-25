defmodule Tidal.Transport.VersionRouter do
  @moduledoc false

  alias Tidal.JSONRPC.{Notification, Request}
  alias Tidal.Server

  @spec route(Plug.Conn.t(), term()) :: :modern | :legacy
  def route(conn, message) do
    header_version = first_header(conn, "mcp-protocol-version")
    body_version = body_version(message)

    cond do
      header_version not in [nil, Server.legacy_protocol_version()] -> :modern
      body_version == Server.modern_protocol_version() -> :modern
      modern_method?(message) -> :modern
      true -> :legacy
    end
  end

  @spec modern_http_request?(Plug.Conn.t()) :: boolean()
  def modern_http_request?(conn) do
    case first_header(conn, "mcp-protocol-version") do
      nil -> false
      version -> version != Server.legacy_protocol_version()
    end
  end

  defp body_version(%Request{params: params}), do: version_from_params(params)
  defp body_version(%Notification{params: params}), do: version_from_params(params)
  defp body_version(_message), do: nil

  defp version_from_params(%{"_meta" => meta}) when is_map(meta),
    do: meta["io.modelcontextprotocol/protocolVersion"]

  defp version_from_params(_params), do: nil

  defp modern_method?(%Request{method: "server/discover"}), do: true
  defp modern_method?(_message), do: false

  defp first_header(conn, name) do
    case Plug.Conn.get_req_header(conn, name) do
      [value | _] -> value
      [] -> nil
    end
  end
end
