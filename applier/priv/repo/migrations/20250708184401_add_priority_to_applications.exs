defmodule Applier.Repo.Migrations.AddPriorityToApplications do
  use Ecto.Migration

  def change do
    alter table(:applications) do
      add :priority, :boolean, default: false
    end
  end
end
