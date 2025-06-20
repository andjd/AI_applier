defmodule Scraper do
  @cache_dir ".cache"

  def extract_questions(page, application_id \\ nil) do
    case application_id do
      nil ->
        IO.puts("No application ID provided, extracting without cache")
        extract_questions_without_cache(page)
      app_id ->
        case read_cache(app_id) do
          {:ok, cached_result} ->
            IO.puts("Using cached scraper result")
            {:ok, cached_result}
          :miss ->
            IO.puts("Cache miss, extracting questions from page")
            extract_and_cache_questions(page, app_id)
        end
    end
  end

  defp extract_and_cache_questions(page, application_id) do
    url = Playwright.Page.url(page)
    result = extract_questions_without_cache(page)

    case result do
      {:ok, questions} ->
        write_cache(application_id, questions, url)
        {:ok, questions}
      error ->
        error
    end
  end

  defp extract_questions_without_cache(page) do
    if Helpers.FormDetector.is_greenhouse_form?(page) do
      IO.puts("Detected Greenhouse form, using Greenhouse scraper")
      Scraper.Greenhouse.extract_questions(page)
    else
      IO.puts("Using Generic scraper")
      Scraper.Generic.extract_questions(page)
    end
  end


  defp ensure_cache_dir do
    case File.mkdir_p(@cache_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to create cache directory: #{inspect(reason)}"}
    end
  end

  defp get_cache_file_path(application_id) do
    Path.join(@cache_dir, "scraper_cache_#{application_id}.json")
  end

  defp read_cache(application_id) do
    cache_file = get_cache_file_path(application_id)

    case File.read(cache_file) do
      {:ok, content} ->
        case JSON.decode(content) do
          {:ok, %{"result" => result}} -> {:ok, result}
          {:error, _} -> :miss
        end
      {:error, _} -> :miss
    end
  end

  defp write_cache(application_id, result, url) do
    with :ok <- ensure_cache_dir(),
         cache_data = %{
           timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
           url: url,
           application_id: application_id,
           result: result
         },
         json <- JSON.encode!(cache_data),
         cache_file = get_cache_file_path(application_id),
         :ok <- File.write(cache_file, json) do
      :ok
    else
      {:error, reason} ->
        IO.puts("Failed to write cache: #{inspect(reason)}")
        :error
    end
  end
end
