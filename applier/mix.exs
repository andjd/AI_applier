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
      extra_applications: [:logger, :yaml_elixir],
      mod: {Applier.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:yaml_elixir, "~> 2.11"},
      {:req, "~> 0.3"},
      {:dotenv, "~> 3.0.0", only: [:dev, :test]},
      {:playwright, "~> 1.49"},
      {:iona, "~> 0.4"},
      {:sqids, "~> 0.2"},
      {:yugo, "~> 1.0"},
      {:mail, "~> 0.4"},
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.17"},
      {:plug, "~> 1.16"},
      {:bandit, "~> 1.7"},
      {:phoenix_html, "~> 4.1"},
      {:temple, "~> 0.14"},
      {:exsync, "~> 0.4", only: :dev}
    ]
  end
end
