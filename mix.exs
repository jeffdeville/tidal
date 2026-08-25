defmodule Tidal.MixProject do
  use Mix.Project

  def project do
    [
      app: :tidal,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [
        tool: ExCoveralls,
        summary: [threshold: 90]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Tidal.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "lib_dev", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "lib_dev"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:plug, "~> 1.16"},
      {:bandit, "~> 1.6"},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:arena, git: "https://github.com/jeffdeville/arena.git", ref: "37cbe7d565e6fcb0ab2717739d7d7826e0cbffaf"},

      # Dev/Test
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp aliases do
    [
      quality: ["format --check-formatted", "credo --strict"],
      precommit: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "test"
      ],
      "ci.test": ["coveralls.json --raise"]
    ]
  end
end
