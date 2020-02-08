defmodule Acquire.MixProject do
  use Mix.Project

  def project do
    [
      app: :service_acquire,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Acquire.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:definition, in_umbrella: true},
      {:ok, in_umbrella: true},
      {:properties, in_umbrella: true},
      {:definition_events, in_umbrella: true},
      {:transformer, in_umbrella: true},
      {:nimble_parsec, "~> 0.5.3"},
      {:prestige, "~> 1.0"},
      {:phoenix, "~> 1.4.11"},
      {:phoenix_pubsub, "~> 1.1"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:testing, in_umbrella: true, only: [:test]},
      {:mox, "~> 0.5.1", only: [:test]},
      {:checkov, "~> 1.0", only: [:dev, :test]},
      {:placebo, "~> 2.0.0-rc.2", only: [:dev, :test]}
    ]
  end
end