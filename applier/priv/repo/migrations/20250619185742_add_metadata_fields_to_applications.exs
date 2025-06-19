defmodule Applier.Repo.Migrations.AddMetadataFieldsToApplications do
  use Ecto.Migration

  def change do
    alter table(:applications) do
      add :salary_range_min, :integer
      add :salary_range_max, :integer
      add :salary_period, :string
      add :office_location, :string
      add :office_attendance, :string
    end
  end
end
