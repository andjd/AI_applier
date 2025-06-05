defmodule JDInfoExtractor do
  @moduledoc """
  Module for extracting job description information from web pages using Playwright.
  """

  def extract_text(page) do
    with {:ok, text} <- extract_visible_text(page),
         {:ok, questions} <- Scraper.extract_questions(page)
    do
      {:ok, text, questions}
    else
      {:error, reason} -> {:error, reason}
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
