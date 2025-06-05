defmodule JDInfoExtractor do
  @moduledoc """
  Module for extracting job description information from web pages using Playwright.
  """

  def extract_text_from_url(url) do
    case Playwright.launch(:chromium, %{headless: false}) do
      {:ok, browser} ->
        try do
          extract_with_playwright(browser, url)
        after
          Playwright.Browser.close(browser)
        end

      {:error, reason} ->
        {:error, "Failed to start Playwright: #{inspect(reason)}"}
    end
  end

  defp extract_with_playwright(browser, url) do
    page = Playwright.Browser.new_page(browser)
    try do
      Playwright.Page.goto(page, url)
      Process.sleep(2000)

      with {:ok, text} <- extract_visible_text(page),
           {:ok, questions} <- Scraper.extract_questions(page)
      do
        {:ok, text, questions}
      else
        {:error, reason} -> {:error, reason}
      end
    after
      Playwright.Page.close(page)
    end
  end

  defp extract_visible_text(page) do
    # Extract visible text from body
    cleaned_text = Playwright.Page.locator(page, "body")
      |> Playwright.Locator.inner_text()
      |> String.trim()
    {:ok, cleaned_text}
  end


end
