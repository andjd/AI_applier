defmodule Applier.Repo.Migrations.AddRejectedColumn do
  use Ecto.Migration

  def change do
    alter table(:applications) do
      add :rejected, :boolean, default: false, null: false
    end
  end
end
