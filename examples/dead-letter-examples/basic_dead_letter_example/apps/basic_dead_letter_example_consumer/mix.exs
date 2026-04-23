defmodule BasicDeadLetterExampleConsumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :basic_dead_letter_example_consumer,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {BasicDeadLetterExampleConsumer.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:basic_dead_letter_example_core, in_umbrella: true},
      # Kafkaesque
      {:kafkaesque, path: "../../../../.."},
      # Fresha
      {:heartbeats, "~> 0.7", organization: "fresha"},
      {:monitor, "~> 1.0", organization: "fresha"},
      {:spandex, "~> 4.1", hex: :spandex_fresha, organization: "fresha", override: true},
      {:spandex_datadog, "~> 1.6.7",
       hex: :spandex_datadog_fresha, organization: "fresha", override: true}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
