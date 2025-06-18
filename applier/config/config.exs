import Config

config :applier, Applier.Repo,
  database: "applier_#{Mix.env()}.db"

config :applier, ecto_repos: [Applier.Repo]