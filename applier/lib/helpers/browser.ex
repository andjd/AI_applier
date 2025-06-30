defmodule Helpers.Browser do
  @moduledoc """
  Module for managing Playwright browser instances and page navigation.
  
  This module works with the shared BrowserManager to provide efficient
  browser resource management for concurrent tasks.
  """

  require Logger
  
  @doc """
  Gets a new page from the managed browser and navigates to the specified URL.
  
  ## Parameters
  - url: URL to navigate to
  
  ## Returns
  {:ok, page} on success
  {:error, reason} on failure
  """
  def get_page_and_navigate(url) do
    with {:ok, page} <- Helpers.BrowserManager.get_page(),
         {:ok, page} <- Helpers.BrowserManager.navigate_page(page, url)
    do
      {:ok, page}
    else
      {:error, reason} ->
        Logger.error("Failed to get page and navigate to #{url}: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Closes a page using the BrowserManager.
  The browser instance remains alive for other tasks.
  
  ## Parameters
  - page: Playwright page object to close
  """
  def close_managed_page(page) do
    Helpers.BrowserManager.close_page(page)
  end

  @doc """
  Gets a new page from the managed browser without navigation.
  
  ## Returns
  {:ok, page} on success  
  {:error, reason} on failure
  """
  def get_page do
    Helpers.BrowserManager.get_page()
  end

  @doc """
  Navigates an existing page to a URL.
  
  ## Parameters
  - page: Playwright page object
  - url: URL to navigate to
  
  ## Returns
  {:ok, page} on success
  {:error, reason} on failure
  """
  def navigate_page(page, url) do
    Helpers.BrowserManager.navigate_page(page, url)
  end
end
