defmodule Applier.MetadataExtractor do
  require Logger

  alias Applier.{Applications, ApplicationRecord}

  def extract_metadata_async(application_id) do
    Task.start(fn ->
      perform_metadata_extraction(application_id)
    end)
  end

  defp perform_metadata_extraction(application_id) do
    with {:ok, application} <- Applications.get_application(application_id),
         job_text <- get_job_text(application),
         {:ok, metadata} <- JDInfoExtractor.extract_metadata(job_text),
         {:ok, _updated_app} <- update_application_with_metadata(application, metadata)
    do
      IO.puts("Successfully extracted metadata for application #{application_id}")
    else
      {:error, reason} ->
        Logger.error("Failed to extract metadata for application #{application_id}: #{inspect(reason)}")
        Applications.update_application(application_id, %{errors: "Metadata extraction failed: #{inspect(reason)}"})

      error ->
        Logger.error("Unexpected error extracting metadata for application #{application_id}: #{inspect(error)}")
        Applications.update_application(application_id, %{errors: "Unexpected metadata extraction error"})
    end
  end

  defp get_job_text(%ApplicationRecord{source_text: text}) when not is_nil(text), do: text
  defp get_job_text(%ApplicationRecord{source_url: url}) when not is_nil(url) do
    case JDInfoExtractor.extract_text(url) do
      {:ok, text, _questions} -> text
      {:error, reason} -> {:error, reason}
    end
  end
  defp get_job_text(_), do: {:error, "No source."}

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
