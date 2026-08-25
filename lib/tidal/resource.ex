defmodule Tidal.Resource do
  @moduledoc """
  Behaviour for defining MCP resources.

  Implement this behaviour to expose resources to MCP clients. Resources
  represent data that a server makes available, such as file contents,
  database records, or live system information.

  ## Example

      defmodule MyApp.ConfigResource do
        @behaviour Tidal.Resource

        alias Tidal.Protocol.{Resource, ResourceTemplate, TextResourceContents}

        @impl true
        def define_resources do
          [
            Resource.new!(uri: "config://app", name: "App Config", mime_type: "application/json"),
            ResourceTemplate.new!(
              uri_template: "config://app/{key}",
              name: "Config Key",
              mime_type: "text/plain"
            )
          ]
        end

        @impl true
        def handle_read_resource("config://app", _context) do
          {:ok, [
            %TextResourceContents{
              uri: "config://app",
              text: Jason.encode!(Application.get_all_env(:my_app)),
              mime_type: "application/json"
            }
          ]}
        end

        def handle_read_resource("config://app/" <> key, _context) do
          case Application.fetch_env(:my_app, String.to_existing_atom(key)) do
            {:ok, value} ->
              {:ok, [%TextResourceContents{uri: "config://app/\#{key}", text: inspect(value)}]}
            :error ->
              {:error, "config key not found: \#{key}"}
          end
        end

        @impl true
        def handle_subscribe(_uri, _context), do: :ok
      end

  ## Callbacks

    * `define_resources/0` — returns a list of `Tidal.Protocol.Resource` and/or
      `Tidal.Protocol.ResourceTemplate` structs that the server exposes.

    * `handle_read_resource/2` — called when a client reads a resource by URI.
      Receives the URI string and a modern `Tidal.RequestContext` or legacy
      session state map.
      Must return `{:ok, [content]}` where content is `TextResourceContents`
      or `BlobResourceContents`, or `{:error, reason}`.

    * `handle_subscribe/2` — called when a client subscribes to resource changes.
      Receives the URI string and a modern request context or legacy session
      state map.
      Return `:ok` to accept, `{:error, reason}` to reject.

  """

  alias Tidal.Protocol.{BlobResourceContents, Resource, ResourceTemplate, TextResourceContents}

  @type resource_definition :: Resource.t() | ResourceTemplate.t()
  @type resource_content :: TextResourceContents.t() | BlobResourceContents.t()

  @doc """
  Returns a list of resource and/or resource template definitions.
  """
  @callback define_resources() :: [resource_definition()]

  @doc """
  Handles a `resources/read` request for the given URI.

  Returns `{:ok, contents}` with a list of `TextResourceContents` or
  `BlobResourceContents`, or `{:error, reason}`.
  """
  @callback handle_read_resource(uri :: String.t(), context :: map()) ::
              {:ok, [resource_content()]} | {:error, term()}

  @doc """
  Called when a client subscribes to changes for the given URI.

  Return `:ok` to accept or `{:error, reason}` to reject.
  """
  @callback handle_subscribe(uri :: String.t(), context :: map()) :: :ok | {:error, term()}

  @optional_callbacks [handle_subscribe: 2]

  @doc """
  Publishes `notifications/resources/updated` to legacy sessions and modern
  subscription streams using the default local bus.

  Call this from your application code when a resource changes.
  """
  @spec notify_resource_updated(String.t()) :: :ok
  def notify_resource_updated(uri) when is_binary(uri) do
    notification = %Tidal.JSONRPC.Notification{
      method: "notifications/resources/updated",
      params: %{"uri" => uri}
    }

    # Find all session PIDs and notify them — each session checks its own subscriptions
    pids =
      Registry.select(Tidal.SessionRegistry, [{{:_, :"$1", :_}, [], [:"$1"]}])

    for pid <- pids do
      send(pid, {:resource_updated, uri, notification})
    end

    Tidal.Subscriptions.resource_updated(uri)

    :ok
  end
end
