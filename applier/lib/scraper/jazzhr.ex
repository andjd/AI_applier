defmodule Scraper.JazzHR do
  require Logger

  @doc """
  Extracts form questions from a JazzHR application page.
  
  Delegates to the generic scraper since JazzHR forms use standard HTML form elements.
  
  ## Parameters
  - page: Playwright page object
  
  ## Returns
  {:ok, questions} on success where questions is a list of form field maps
  {:error, reason} on failure
  """
  def extract_questions(page) do
    Logger.info("Using JazzHR scraper - delegating to generic scraper")
    Scraper.Generic.extract_questions(page)
  end
end