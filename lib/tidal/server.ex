defmodule Tidal.Server do
  @moduledoc """
  Immutable configuration and catalog for one MCP endpoint.

  A server is built once by `Tidal.Plug.init/1` and shared by independent
  requests. It contains no client lifecycle state. The modern protocol path
  combines it with a fresh `Tidal.RequestContext` for every request.
  """

  alias Tidal.Protocol.{Resource, ResourceTemplate, Tool}
  alias Tidal.Transport.V20260728.ToolHeaderSchema

  @modern_version "2026-07-28"
  @legacy_version "2025-11-25"

  @enforce_keys [
    :supported_versions,
    :server_info,
    :capabilities,
    :tools,
    :tool_handlers,
    :resources,
    :resource_templates,
    :resource_handlers,
    :middleware,
    :cache,
    :init_assigns
  ]
  defstruct [
    :instructions,
    :context_builder,
    :state_resolver,
    :subscription_bus,
    :request_state_secret,
    :allowed_origins,
    supported_versions: [],
    server_info: %{},
    capabilities: %{},
    tools: [],
    tool_handlers: %{},
    resources: [],
    resource_templates: [],
    resource_handlers: [],
    middleware: [],
    cache: %{ttl_ms: 0, scope: "private"},
    init_assigns: %{}
  ]

  @type t :: %__MODULE__{
          supported_versions: [String.t()],
          server_info: map(),
          capabilities: map(),
          instructions: String.t() | nil,
          tools: [Tool.t()],
          tool_handlers: %{String.t() => module()},
          resources: [Resource.t()],
          resource_templates: [ResourceTemplate.t()],
          resource_handlers: [module()],
          middleware: [module()],
          cache: %{ttl_ms: non_neg_integer(), scope: String.t()},
          context_builder: nil | (Plug.Conn.t(), map() -> map() | {:ok, map()} | {:error, term()}),
          init_assigns: map(),
          state_resolver: module() | {module(), keyword()} | nil,
          subscription_bus: module() | {module(), keyword()} | nil,
          request_state_secret: binary() | nil,
          allowed_origins: [String.t()]
        }

  @doc "The current stateless MCP protocol revision."
  @spec modern_protocol_version() :: String.t()
  def modern_protocol_version, do: @modern_version

  @doc "The latest handshake-era revision served by the compatibility path."
  @spec legacy_protocol_version() :: String.t()
  def legacy_protocol_version, do: @legacy_version

  @doc "Builds a server, raising when its configuration or catalog is invalid."
  @spec new!(keyword()) :: t()
  def new!(opts \\ []) when is_list(opts) do
    tool_modules = Keyword.get(opts, :tool_modules, [])
    resource_handlers = Keyword.get(opts, :resource_handlers, [])
    subscription_bus = Keyword.get(opts, :subscription_bus, Tidal.Subscriptions.Local)
    {tools, tool_handlers} = build_tools(tool_modules)
    {resources, templates} = build_resources(resource_handlers)

    capabilities =
      tools
      |> derived_capabilities(resources, templates, subscription_bus)
      |> Map.merge(normalize_map(Keyword.get(opts, :capabilities, %{})))

    %__MODULE__{
      supported_versions: [@modern_version, @legacy_version],
      server_info: normalize_server_info(Keyword.get(opts, :server_info, %{})),
      capabilities: capabilities,
      instructions: Keyword.get(opts, :instructions),
      tools: tools,
      tool_handlers: tool_handlers,
      resources: resources,
      resource_templates: templates,
      resource_handlers: resource_handlers,
      middleware: Keyword.get(opts, :middleware, []),
      cache: normalize_cache(Keyword.get(opts, :cache, [])),
      context_builder: validate_context_builder!(Keyword.get(opts, :context_builder)),
      init_assigns: Keyword.get(opts, :init_assigns, %{}),
      state_resolver: Keyword.get(opts, :state_resolver, Tidal.StateHandle.Local),
      subscription_bus: subscription_bus,
      request_state_secret: validate_request_state_secret!(Keyword.get(opts, :request_state_secret)),
      allowed_origins: validate_allowed_origins!(Keyword.get(opts, :allowed_origins, []))
    }
  end

  defp build_tools(modules) do
    entries =
      Enum.flat_map(modules, fn module ->
        ensure_exported!(module, :define_tools, 0)

        Enum.map(module.define_tools(), fn
          %Tool{} = tool ->
            ToolHeaderSchema.validate!(tool)
            {tool, module}

          other ->
            raise ArgumentError,
                  "expected #{inspect(module)}.define_tools/0 to return Tool structs, got: #{inspect(other)}"
        end)
      end)

    handlers =
      Enum.reduce(entries, %{}, fn {%Tool{name: name}, module}, handlers ->
        if Map.has_key?(handlers, name) do
          raise ArgumentError, "duplicate tool name: #{name}"
        end

        Map.put(handlers, name, module)
      end)

    tools = entries |> Enum.map(&elem(&1, 0)) |> Enum.sort_by(& &1.name)
    {tools, handlers}
  end

  defp build_resources(handlers) do
    definitions =
      Enum.flat_map(handlers, fn handler ->
        ensure_exported!(handler, :define_resources, 0)
        handler.define_resources()
      end)

    resources =
      definitions
      |> Enum.filter(&match?(%Resource{}, &1))
      |> Enum.sort_by(& &1.uri)

    templates =
      definitions
      |> Enum.filter(&match?(%ResourceTemplate{}, &1))
      |> Enum.sort_by(& &1.uri_template)

    {resources, templates}
  end

  defp ensure_exported!(module, function, arity) do
    if Code.ensure_loaded?(module) and function_exported?(module, function, arity) do
      :ok
    else
      raise ArgumentError, "expected #{inspect(module)} to export #{function}/#{arity}"
    end
  end

  defp derived_capabilities(tools, resources, templates, subscription_bus) do
    subscription_capabilities? = not is_nil(subscription_bus)

    %{}
    |> maybe_put_capability(
      "tools",
      tools != [],
      if(subscription_capabilities?, do: %{"listChanged" => true}, else: %{})
    )
    |> maybe_put_capability(
      "resources",
      resources != [] or templates != [],
      if(subscription_capabilities?,
        do: %{"listChanged" => true, "subscribe" => true},
        else: %{}
      )
    )
  end

  defp maybe_put_capability(capabilities, _name, false, _settings), do: capabilities
  defp maybe_put_capability(capabilities, name, true, settings), do: Map.put(capabilities, name, settings)

  defp normalize_server_info(info) when map_size(info) == 0 do
    %{"name" => "tidal", "version" => "0.1.0"}
  end

  defp normalize_server_info(info) when is_map(info) do
    normalized = normalize_map(info)

    normalized
    |> Map.put_new("name", "tidal")
    |> Map.put_new("version", "0.1.0")
  end

  defp normalize_server_info(other) do
    raise ArgumentError, "server_info must be a map, got: #{inspect(other)}"
  end

  defp normalize_map(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      pair -> pair
    end)
  end

  defp normalize_cache(opts) when is_list(opts) do
    ttl_ms = Keyword.get(opts, :ttl_ms, 0)
    scope = Keyword.get(opts, :scope, :private)

    unless is_integer(ttl_ms) and ttl_ms >= 0 do
      raise ArgumentError, "cache ttl_ms must be a non-negative integer"
    end

    %{ttl_ms: ttl_ms, scope: normalize_cache_scope(scope)}
  end

  defp normalize_cache(other) do
    raise ArgumentError, "cache must be a keyword list, got: #{inspect(other)}"
  end

  defp normalize_cache_scope(scope) when scope in [:private, "private"], do: "private"
  defp normalize_cache_scope(scope) when scope in [:public, "public"], do: "public"

  defp normalize_cache_scope(scope) do
    raise ArgumentError, "cache scope must be :private or :public, got: #{inspect(scope)}"
  end

  defp validate_context_builder!(nil), do: nil
  defp validate_context_builder!(builder) when is_function(builder, 2), do: builder

  defp validate_context_builder!(builder) do
    raise ArgumentError, "context_builder must be a function of arity 2, got: #{inspect(builder)}"
  end

  defp validate_request_state_secret!(nil), do: nil

  defp validate_request_state_secret!(secret) when is_binary(secret) and byte_size(secret) >= 32,
    do: secret

  defp validate_request_state_secret!(secret) do
    raise ArgumentError,
          "request_state_secret must be at least 32 bytes, got: #{inspect(secret)}"
  end

  defp validate_allowed_origins!(origins) when is_list(origins) do
    if Enum.all?(origins, &valid_origin?/1) do
      Enum.map(origins, &normalize_origin/1)
    else
      raise ArgumentError,
            "allowed_origins must contain only HTTP(S) origins, got: #{inspect(origins)}"
    end
  end

  defp validate_allowed_origins!(origins) do
    raise ArgumentError,
          "allowed_origins must be a list, got: #{inspect(origins)}"
  end

  defp valid_origin?(origin) when is_binary(origin) do
    case URI.parse(origin) do
      %URI{scheme: scheme, host: host, path: path, query: nil, fragment: nil, userinfo: nil}
      when scheme in ["http", "https"] and is_binary(host) and path in [nil, ""] ->
        true

      _ ->
        false
    end
  end

  defp valid_origin?(_origin), do: false

  defp normalize_origin(origin) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(origin)
    URI.to_string(%URI{scheme: scheme, host: String.downcase(host), port: normalize_port(scheme, port)})
  end

  defp normalize_port("http", 80), do: nil
  defp normalize_port("https", 443), do: nil
  defp normalize_port(_scheme, port), do: port
end
