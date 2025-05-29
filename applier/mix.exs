defmodule Applier.MixProject do
  use Mix.Project

  def project do
    [
      app: :applier,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :yaml_elixir]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:yaml_elixir, "~> 2.11"},
      {:req, "~> 0.3"},
      {:jason, "~> 1.4"},
      {:dotenv, "~> 3.0.0", only: [:dev, :test]},
      {:playwright, "~> 1.49"},
      {:iona, "~> 0.4"},
    ]
  end
end
