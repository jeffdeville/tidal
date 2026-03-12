defmodule Tidal.Session.Options do
  @moduledoc """
  NimbleOptions schema for session configuration.
  """

  @schema [
    timeout: [
      type: :pos_integer,
      default: :timer.minutes(30),
      doc: "Inactivity timeout in milliseconds before the session is automatically terminated."
    ],
    capabilities: [
      type: :map,
      default: %{},
      doc: "Initial capabilities map for the session."
    ],
    server_info: [
      type: :map,
      default: %{},
      doc: "Server information map passed to the session."
    ],
    tool_modules: [
      type: {:list, :atom},
      default: [],
      doc: "List of modules implementing the Tidal.Tool behaviour."
    ],
    resource_handlers: [
      type: {:list, :atom},
      default: [],
      doc: "List of modules implementing the Tidal.Resource behaviour."
    ],
    middleware: [
      type: {:list, :atom},
      default: [],
      doc: "List of modules implementing the Tidal.Tool.Middleware behaviour, applied in order."
    ],
    init_assigns: [
      type: :map,
      default: %{},
      doc: "Initial assigns map merged into the session state on creation. Use for server-side context that middleware needs (e.g., arena config, role)."
    ]
  ]

  @doc """
  Returns the NimbleOptions schema for session options.
  """
  def schema, do: @schema

  @doc """
  Validates session options against the schema.

  Returns `{:ok, validated_opts}` or `{:error, %NimbleOptions.ValidationError{}}`.
  """
  @spec validate(keyword()) :: {:ok, keyword()} | {:error, NimbleOptions.ValidationError.t()}
  def validate(opts) do
    NimbleOptions.validate(opts, @schema)
  end

  @doc """
  Validates session options, raising on failure.
  """
  @spec validate!(keyword()) :: keyword()
  def validate!(opts) do
    NimbleOptions.validate!(opts, @schema)
  end
end
