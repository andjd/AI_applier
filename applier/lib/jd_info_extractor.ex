defmodule JDInfoExtractor do
  @moduledoc """
  Module for extracting job description information from web pages using Playwright.
  """

  def extract_text(url_or_page, application_id \\ nil)

  def extract_text(url, application_id) when is_binary(url) do
    case Helpers.Browser.get_page_and_navigate(url) do
      {:ok, page} ->
          case extract_text(page, application_id) do
            {:ok, text, questions} ->
              Helpers.Browser.close_managed_page(page)
              {:ok, text, questions}
            {:error, reason} ->
              Helpers.Browser.close_managed_page(page)
              {:error, reason}
          end
      {:error, reason} ->
        {:error, reason}
    end
  end

  def extract_text(page, _application_id) do
    with {:ok, text} <- Scraper.extract_visible_text(page),
         {:ok, questions} <- Scraper.extract_questions(page)
    do
      {:ok, text, questions}
    else
      {:error, reason} -> {:error, reason}
    end
  end



  def extract_metadata(text, application_id \\ nil) do
    system_prompt = File.read!("prompts/metadata.txt")
    options = %{
      system: system_prompt,
      model: "claude-3-haiku-20240307"
    }

    with {:ok, response} <- (IO.puts("Extracting metadata from job description..."); Helpers.LLM.ask(text, application_id, options)),
         {:ok, metadata} <- (IO.puts("Parsing metadata JSON..."); parse_metadata_json(response))
    do
      IO.puts("Metadata extraction completed successfully!")
      {:ok, metadata}
    else
      {:error, reason} ->
        IO.puts("Error extracting metadata: #{reason}")
        {:error, reason}
    end
  end


  defp parse_metadata_json(response) do
    case JSON.decode(response) do
      {:ok, metadata} -> validate_and_filter_metadata(metadata)
      {:error, _reason} -> {:error, "Failed to parse metadata JSON response"}
    end
  end

  defp validate_and_filter_metadata(metadata) when is_map(metadata) do
    required_fields = [
      "company_name",
      "job_title",
      "salary_range_min",
      "salary_range_max",
      "salary_period",
      "office_location",
      "office_attendance"
    ]

    missing_fields = required_fields -- Map.keys(metadata)

    case missing_fields do
      [] ->
        filtered_metadata = Map.take(metadata, required_fields)
        {:ok, filtered_metadata}
      _ ->
        {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp validate_and_filter_metadata(_), do: {:error, "Invalid metadata format"}

end
