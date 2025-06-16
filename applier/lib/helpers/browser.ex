defmodule Helpers.Browser do
  @moduledoc """
  Module for managing Playwright browser instances and page navigation.
  """

  def launch_and_navigate(url) do
    case launch() do
      {:ok, browser} ->
        case create_page(browser) do
          {:ok, page} ->
            case navigate(page, url) do
              :ok -> {:ok, browser, page}
              error -> 
                close_page(page)
                close_browser(browser)
                error
            end
          error ->
            close_browser(browser)
            error
        end
      error -> error
    end
  end

  def launch do
    case Playwright.launch(:chromium, %{headless: false}) do
      {:ok, browser} -> {:ok, browser}
      {:error, reason} -> {:error, "Failed to start Playwright: #{inspect(reason)}"}
    end
  end

  def create_page(browser) do
    try do
      page = Playwright.Browser.new_page(browser)
      {:ok, page}
    rescue
      error -> {:error, "Failed to create page: #{inspect(error)}"}
    end
  end

  def navigate(page, url) do
    try do
      Playwright.Page.goto(page, url)
      Process.sleep(2000)
      :ok
    rescue
      error -> {:error, "Failed to navigate to #{url}: #{inspect(error)}"}
    end
  end

  def close_browser(browser) do
    try do
      Playwright.Browser.close(browser)
    rescue
      _error -> :ok
    end
  end

  def close_page(page) do
    try do
      Playwright.Page.close(page)
    rescue
      _error -> :ok
    end
  end
end
