defmodule Applier.Repo do
  use Ecto.Repo,
    otp_app: :applier,
    adapter: Ecto.Adapters.SQLite3
end