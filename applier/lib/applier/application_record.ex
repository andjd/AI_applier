defmodule Applier.ApplicationRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  schema "applications" do
    field :source_url, :string
    field :source_text, :string
    field :form_url, :string
    field :company_name, :string
    field :job_title, :string
    field :parsed, :boolean, default: false
    field :approved, :boolean, default: false
    field :docs_generated, :boolean, default: false
    field :form_filled, :boolean, default: false
    field :submitted, :boolean, default: false
    field :errors, :string

    timestamps()
  end

  def changeset(application, attrs) do
    application
    |> cast(attrs, [:id, :source_url, :source_text, :form_url, :company_name, :job_title,
                    :parsed, :approved, :docs_generated, :form_filled, :submitted, :errors])
    |> validate_required([:id])
    |> validate_source_present()
    |> unique_constraint(:id)
  end

  defp validate_source_present(changeset) do
    source_url = get_field(changeset, :source_url)
    source_text = get_field(changeset, :source_text)

    if is_nil(source_url) and is_nil(source_text) do
      add_error(changeset, :source_url, "Either source_url or source_text must be provided")
    else
      changeset
    end
  end
end
