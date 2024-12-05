defmodule ExZk.MixProject do
  use Mix.Project

  @description "Fast, resilient Zookeeper driver for Elixir."
  @version "0.1.0"
  @repo_url "https://github.com/flier/ex_zk"

  @elixir_requirement "~> 1.14"

  def project do
    [
      app: :ex_zk,
      version: @version,
      elixir: @elixir_requirement,
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Tests
      test_coverage: [tool: ExCoveralls],

      # Hex
      package: package(),
      source_url: @repo_url,
      description: @description,

      # Docs
      name: "ExZk",
      docs: [
        main: "ExZk",
        source_ref: "v#{@version}",
        source_url: @repo_url,
        extras: [
          "README.md",
          "CHANGELOG.md",
          "LICENSE.txt": [title: "License"]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ExZk, []},
      extra_applications: [:logger, :eex, :ssl, :runtime_tools],
      env: [
        logger: true
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Flier Lu <flier.lu@gmail.com>"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:castore, "~> 1.0", optional: true},
      {:nimble_options, "~> 1.0"},
      {:telemetry, "~> 1.3"},

      # Dev and test dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: [:dev, :doc]},
      {:excoveralls, "~> 0.18", only: :test},
      {:mock, "~> 0.3", only: :test},
      {:nimble_parsec, "~> 1.4", only: [:dev, :doc, :test]}
    ]
  end
end
