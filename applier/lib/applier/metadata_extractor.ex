defmodule Applier.MetadataExtractor do
  require Logger

  alias Applier.{Applications, ApplicationRecord}

  def process(job_text, application_id) do
    with {:ok, metadata} <- JDInfoExtractor.extract_metadata(job_text, application_id),
         {:ok, updated_app} <- update_application_with_metadata(application_id, metadata)
    do
      IO.puts("Successfully extracted metadata for application #{application_id}")
      {:ok, updated_app}
    else
      {:error, reason} ->
        Logger.error("Failed to extract metadata for application #{application_id}: #{inspect(reason)}")
        Applications.update_application(application_id, %{errors: "Metadata extraction failed: #{inspect(reason)}"})
        {:error, reason}

      error ->
        Logger.error("Unexpected error extracting metadata for application #{application_id}: #{inspect(error)}")
        Applications.update_application(application_id, %{errors: "Unexpected metadata extraction error"})
        {:error, error}
    end
  end


  defp update_application_with_metadata(id, metadata) do
    with {:ok, existing_app} <- Applications.get_application(id) do
      new_attrs = %{
        company_name: metadata["company_name"],
        job_title: metadata["job_title"],
        salary_range_min: cast_salary_value(metadata["salary_range_min"]),
        salary_range_max: cast_salary_value(metadata["salary_range_max"]),
        salary_period: metadata["salary_period"],
        office_location: metadata["office_location"],
        office_attendance: metadata["office_attendance"],
        parsed: true
      }

      # Only update fields that are nil in the existing application
      # Log discrepancies when existing data differs from new data
      attrs_to_update = Enum.reduce(new_attrs, %{}, fn {field, new_value}, acc ->
        existing_value = Map.get(existing_app, field)

        cond do
          # Always update the parsed field
          field == :parsed ->
            Map.put(acc, field, new_value)

          # If existing value is nil, update with new value
          is_nil(existing_value) ->
            Map.put(acc, field, new_value)

          # If new value is nil, keep existing value (don't update)
          is_nil(new_value) ->
            acc

          # If both values exist but are different, log discrepancy and keep existing
          existing_value != new_value ->
            Logger.warn("Metadata discrepancy for application #{id}, field #{field}: existing='#{existing_value}', new='#{new_value}' - keeping existing value")
            acc

          # If values are the same, no update needed
          true ->
            acc
        end
      end)

      Applications.update_application(id, attrs_to_update)
    end
  end

  defp cast_salary_value(nil), do: nil
  defp cast_salary_value(value) when is_integer(value), do: value
  defp cast_salary_value(value) when is_binary(value) do
    # Remove common currency symbols and commas, then try to parse
    cleaned = value
    |> String.replace(~r/[$,£€¥]/, "")
    |> String.replace(~r/[k|K]$/, "000")
    |> String.trim()

    case Integer.parse(cleaned) do
      {integer, ""} -> integer
      _ -> nil
    end
  end
  defp cast_salary_value(_), do: nil
end
