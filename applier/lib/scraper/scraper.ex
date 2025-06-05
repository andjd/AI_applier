defmodule Scraper do
  def extract_questions(page) do
    if is_greenhouse_form?(page) do
      IO.puts("Detected Greenhouse form, using Greenhouse scraper")
      Scraper.Greenhouse.extract_questions(page)
    else
      IO.puts("Using Generic scraper")
      Scraper.Generic.extract_questions(page)
    end
  end

  defp is_greenhouse_form?(page) do
    is_greenhouse_url?(page) or is_greenhouse_html?(page)
  end

  defp is_greenhouse_url?(page) do
    url = Playwright.Page.url(page)
    if url && String.length(url) > 0 do
      url_lower = String.downcase(url)
      String.contains?(url_lower, "greenhouse.io")
    else
      false
    end
  end

  defp is_greenhouse_html?(page) do
    # Get the HTML content of the page
    html_content = Playwright.Page.content(page)
    if html_content && String.length(html_content) > 0 do
      html_lower = String.downcase(html_content)
      String.contains?(html_lower, "greenhouse.io")
    else
      false
    end
  end
end
