defmodule Scraper do
  @cache_dir ".cache"

  def extract_questions(page) do
    url = Playwright.Page.url(page)
    cache_key = generate_cache_key(url)

    case read_cache(cache_key) do
      {:ok, cached_result} ->
        IO.puts("Using cached scraper result")
        {:ok, cached_result}
      :miss ->
        IO.puts("Cache miss, extracting questions from page")
        extract_and_cache_questions(page, url, cache_key)
    end
  end

  def extract_visible_text(page) do
    with {:ok, page} <- navigate_to_jd_if_necessary(page),
          _ <- :timer.sleep(400),
         cleaned_text = Playwright.Page.locator(page, "body")
                        |> Playwright.Locator.inner_text()
                        |> String.trim()
    do
      IO.puts(cleaned_text)
      {:ok, cleaned_text}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp navigate_to_jd_if_necessary(page) do
    cond do
      Helpers.FormDetector.is_lever_form?(page) ->
        navigate_to_lever_jd(page)
      Helpers.FormDetector.is_ashbyhq_form?(page) ->
        navigate_to_ashbyhq_jd(page)
      true ->
        {:ok, page}
    end
  end

  defp navigate_to_lever_jd(page) do
    url = Playwright.Page.url(page)

    if String.contains?(url, "/apply") do
      # Remove /apply to get the JD page
      jd_url = String.replace(url, "/apply", "")
      IO.puts("Navigating to Lever JD page: #{jd_url}")

      response = Playwright.Page.goto(page, jd_url)
      :timer.sleep(200)
      if response.status == 200 do
        {:ok, page}
      else
        {:error, inspect(response)}
      end
    else
      # Already on JD page
      {:ok, page}
    end
  end

  defp navigate_to_ashbyhq_jd(page) do
    url = Playwright.Page.url(page)

    if String.contains?(url, "/application") do
      # Remove /application to get the JD page
      jd_url = String.replace(url, "/application", "")
      IO.puts("Navigating to AshbyHQ JD page: #{jd_url}")

      response = Playwright.Page.goto(page, jd_url)
      :timer.sleep(200)
      if response.status == 200 do
        {:ok, page}
      else
        {:error, inspect(response)}
      end
    else
      # Already on JD page
      {:ok, page}
    end
  end

  defp extract_and_cache_questions(page, url, cache_key) do
    result = cond do
      Helpers.FormDetector.is_greenhouse_form?(page) ->
        IO.puts("Detected Greenhouse form, using Greenhouse scraper")
        Scraper.Greenhouse.extract_questions(page)

      Helpers.FormDetector.is_jazzhr_form?(page) ->
        IO.puts("Detected JazzHR form, using JazzHR scraper")
        Scraper.JazzHR.extract_questions(page)

      Helpers.FormDetector.is_lever_form?(page) ->
        IO.puts("Detected Lever form, using Lever scraper")
        Scraper.Lever.extract_questions(page)

      Helpers.FormDetector.is_ashbyhq_form?(page) ->
        IO.puts("Detected AshbyHQ form, using AshbyHQ scraper")
        Scraper.AshbyHQ.extract_questions(page)

      true ->
        IO.puts("Using Generic scraper")
        Scraper.Generic.extract_questions(page)
    end

    case result do
      {:ok, questions} ->
        write_cache(cache_key, questions, url)
        {:ok, questions}
      error ->
        error
    end
  end

  defp generate_cache_key(url) do
    url
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> String.slice(0..8)
  end

  defp ensure_cache_dir do
    case File.mkdir_p(@cache_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to create cache directory: #{inspect(reason)}"}
    end
  end

  defp get_cache_file_path(cache_key) do
    Path.join(@cache_dir, "scraper_cache_#{cache_key}.json")
  end

  defp read_cache(cache_key) do
    cache_file = get_cache_file_path(cache_key)

    case File.read(cache_file) do
      {:ok, content} ->
        case JSON.decode(content) do
          {:ok, %{"result" => result}} -> {:ok, result}
          {:error, _} -> :miss
        end
      {:error, _} -> :miss
    end
  end

  defp write_cache(cache_key, result, url) do
    with :ok <- ensure_cache_dir(),
         cache_data = %{
           timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
           url: url,
           cache_key: cache_key,
           result: result
         },
         json <- JSON.encode!(cache_data),
         cache_file = get_cache_file_path(cache_key),
         :ok <- File.write(cache_file, json) do
      :ok
    else
      {:error, reason} ->
        IO.puts("Failed to write cache: #{inspect(reason)}")
        :error
    end
  end
end
