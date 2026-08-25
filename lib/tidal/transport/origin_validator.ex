defmodule Tidal.Transport.OriginValidator do
  @moduledoc false

  alias Tidal.JSONRPC.Error
  alias Tidal.Server

  require Tidal.JSONRPC.ErrorCodes, as: ErrorCodes

  @spec validate(Plug.Conn.t(), Server.t()) :: :ok | {:error, 403, Error.t()}
  def validate(%Plug.Conn{} = conn, %Server{} = server) do
    case Plug.Conn.get_req_header(conn, "origin") do
      [] -> :ok
      [origin] -> if normalize(origin) in server.allowed_origins, do: :ok, else: forbidden()
      _multiple -> forbidden()
    end
  end

  defp normalize(origin) do
    case URI.parse(origin) do
      %URI{scheme: scheme, host: host, port: port, path: path, query: nil, fragment: nil, userinfo: nil}
      when scheme in ["http", "https"] and is_binary(host) and path in [nil, ""] ->
        URI.to_string(%URI{
          scheme: scheme,
          host: String.downcase(host),
          port: normalize_port(scheme, port)
        })

      _ ->
        nil
    end
  end

  defp normalize_port("http", 80), do: nil
  defp normalize_port("https", 443), do: nil
  defp normalize_port(_scheme, port), do: port

  defp forbidden do
    {:error, 403,
     %Error{
       id: nil,
       code: ErrorCodes.invalid_request(),
       message: "Invalid Request",
       data: "Origin is not allowed"
     }}
  end
end
