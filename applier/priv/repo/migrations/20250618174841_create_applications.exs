defmodule Applier.Repo.Migrations.CreateApplications do
  use Ecto.Migration

  def change do
    create table(:applications, primary_key: false) do
      add :id, :string, primary_key: true
      add :source_url, :string
      add :source_text, :text
      add :form_url, :string
      add :parsed, :boolean, default: false, null: false
      add :approved, :boolean, default: false, null: false
      add :docs_generated, :boolean, default: false, null: false
      add :form_filled, :boolean, default: false, null: false
      add :submitted, :boolean, default: false, null: false
      add :errors, :text

      timestamps()
    end
  end
end
