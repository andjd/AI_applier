defmodule Applier.MetadataExtractor do
  require Logger

  alias Applier.{Applications, ApplicationRecord}

  def process(job_text, application_id) do
    with {:ok, metadata} <- JDInfoExtractor.extract_metadata(job_text, application_id),
         {:ok, _updated_app} <- update_application_with_metadata(application, metadata)
    do
      IO.puts("Successfully extracted metadata for application #{application_id}")
      {:ok, metadata}
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


  defp update_application_with_metadata(application, metadata) do
    attrs = %{
      company_name: metadata["company_name"],
      job_title: metadata["job_title"],
      salary_range_min: cast_salary_value(metadata["salary_range_min"]),
      salary_range_max: cast_salary_value(metadata["salary_range_max"]),
      salary_period: metadata["salary_period"],
      office_location: metadata["office_location"],
      office_attendance: metadata["office_attendance"],
      parsed: true
    }

    Applications.update_application(application.id, attrs)
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
