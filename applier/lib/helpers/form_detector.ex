defmodule Helpers.FormDetector do
  @doc """
  Detects if a page contains a Greenhouse form by checking URL and HTML content.
  
  ## Parameters
  - page: Playwright page object
  
  ## Returns
  Boolean indicating whether this is a Greenhouse form
  """
  def is_greenhouse_form?(page) do
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
    html_content = Playwright.Page.content(page)
    if html_content && String.length(html_content) > 0 do
      html_lower = String.downcase(html_content)
      String.contains?(html_lower, "greenhouse.io")
    else
      false
    end
  end
end