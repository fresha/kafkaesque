defmodule Kafkaesque.MixProject do
  use Mix.Project

  def project do
    [
      app: :kafkaesque,
      version: "4.3.0",
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        plt_add_apps: [:ex_unit, :kafka_ex, :mix],
        plt_add_deps: :app_tree,
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        list_unused_filters: true
      ],
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: preferred_cli_env(),
      description: description(),
      package: package(),
      xref: [exclude: Mix.Tasks.Hex.Publish]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger], mod: {Kafkaesque.Application, []}]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:uniq, "~> 0.6"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:protobuf, "~> 0.15.0", only: [:test]},
      {:kafka_ex, "~> 0.15.0"},
      {:jason, "~> 1.0"},
      {:monitor, "~> 2.0.0", organization: "fresha", optional: true},
      {:telemetry, "~> 1.0"},
      {:mimic, "~> 1.7", only: :test},
      {:testcontainers, "~> 1.11", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      static_check: static_check_alias(),
      test: test_alias(),
      check: all_checks_alias()
    ]
  end

  defp static_check_alias do
    [
      "format --check-formatted",
      "credo --strict",
      "compile --warnings-as-errors --force",
      "dialyzer --underspecs --force-check"
    ]
  end

  defp test_alias do
    [
      "test --color"
    ]
  end

  defp all_checks_alias do
    static_check_alias() ++ test_alias()
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*"],
      licenses: [],
      links: %{"GitHub" => "https://github.com/surgeventures/kafkaesque"},
      organization: "fresha"
    ]
  end

  defp description do
    """
    Kafkaesque: Abstracts the complexity of interacting with Kafka at Fresha
    """
  end

  defp preferred_cli_env do
    [
      check: :test,
      static_check: :dev,
      test: :test
    ]
  end
end
