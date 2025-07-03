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
    field :salary_range_min, :integer
    field :salary_range_max, :integer
    field :salary_period, :string
    field :office_location, :string
    field :office_attendance, :string
    field :parsed, :boolean, default: false
    field :approved, :boolean, default: false
    field :docs_generated, :boolean, default: false
    field :form_filled, :boolean, default: false
    field :submitted, :boolean, default: false
    field :rejected, :boolean, default: false
    field :errors, :string

    timestamps()
  end

  def changeset(application, attrs) do
    attrs = cast_salary_fields(attrs)

    application
    |> cast(attrs, [:id, :source_url, :source_text, :form_url, :company_name, :job_title,
                    :salary_range_min, :salary_range_max, :salary_period, :office_location,
                    :office_attendance, :parsed, :approved, :docs_generated,
                    :form_filled, :submitted, :rejected, :errors])
    |> validate_required([:id])
    |> validate_source_present()
    |> unique_constraint(:id)
  end

  defp cast_salary_fields(attrs) do
    attrs
    |> cast_salary_field(:salary_range_min)
    |> cast_salary_field(:salary_range_max)
    |> cast_salary_field("salary_range_min")
    |> cast_salary_field("salary_range_max")
  end

  defp cast_salary_field(attrs, field) when is_map(attrs) do
    case Map.get(attrs, field) do
      nil -> attrs
      value when is_integer(value) -> attrs
      value when is_binary(value) ->
        case parse_salary_string(value) do
          {:ok, integer_value} -> Map.put(attrs, field, integer_value)
          :error -> attrs
        end
      _ -> attrs
    end
  end

  defp parse_salary_string(value) when is_binary(value) do
    # Remove common currency symbols and commas, then try to parse
    cleaned = value
    |> String.replace(~r/[$,£€¥]/, "")
    |> String.replace(~r/[k|K]$/, "000")
    |> String.trim()

    case Integer.parse(cleaned) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
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
