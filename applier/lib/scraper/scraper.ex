defmodule Scraper do
  def extract_questions(page) do
    if Helpers.FormDetector.is_greenhouse_form?(page) do
      IO.puts("Detected Greenhouse form, using Greenhouse scraper")
      Scraper.Greenhouse.extract_questions(page)
    else
      IO.puts("Using Generic scraper")
      Scraper.Generic.extract_questions(page)
    end
  end
end
