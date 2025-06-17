defmodule Helpers.Browser do
  @moduledoc """
  Module for managing Playwright browser instances and page navigation.
  """

  def launch_and_navigate(url) do
    case Playwright.launch(:chromium, %{headless: false}) do
      {:ok, browser} ->
        page = Playwright.Browser.new_page(browser)
        Playwright.Page.goto(page, url)
        Process.sleep(2000)
        {:ok, browser, page}

      other_response ->
        {:error, "Failed to start Playwright: #{inspect(other_response)}"}
    end
  end

  def close_browser(browser) do
    Playwright.Browser.close(browser)
  end

  def close_page(page) do
    Playwright.Page.close(page)
  end
end
