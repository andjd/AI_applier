defmodule Applier.Repo.Migrations.AddCompanyNameAndJobTitleToApplications do
  use Ecto.Migration

  def change do
    alter table(:applications) do
      add :company_name, :string
      add :job_title, :string
    end
  end
end
