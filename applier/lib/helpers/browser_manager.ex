defmodule Helpers.BrowserManager do
  @moduledoc """
  A GenServer that manages a single browser instance with multiple pages for concurrent tasks.
  Provides a resource-efficient way to handle multiple browser automation tasks simultaneously.
  """

  use GenServer
  require Logger

  @browser_opts %{headless: false}

  # Client API

  @doc """
  Starts the browser manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a new page from the managed browser instance.
  
  ## Returns
  {:ok, page} on success
  {:error, reason} on failure
  """
  def get_page do
    GenServer.call(__MODULE__, :get_page, 30_000)
  end

  @doc """
  Navigates a page to the specified URL.
  
  ## Parameters
  - page: Playwright page object
  - url: URL to navigate to
  
  ## Returns
  {:ok, page} on success
  {:error, reason} on failure
  """
  def navigate_page(page, url) do
    try do
      Playwright.Page.goto(page, url)
      Process.sleep(2000)  # Allow page to load
      {:ok, page}
    rescue
      error ->
        Logger.error("Failed to navigate page to #{url}: #{inspect(error)}")
        {:error, "Navigation failed: #{inspect(error)}"}
    end
  end

  @doc """
  Closes a specific page while keeping the browser alive.
  
  ## Parameters
  - page: Playwright page object to close
  """
  def close_page(page) do
    GenServer.cast(__MODULE__, {:close_page, page})
  end

  @doc """
  Shuts down the browser manager and closes the browser instance.
  This should only be called when the entire application is shutting down.
  """
  def shutdown do
    GenServer.call(__MODULE__, :shutdown, 30_000)
  end

  @doc """
  Gets the current browser instance (mainly for debugging).
  """
  def get_browser do
    GenServer.call(__MODULE__, :get_browser)
  end

  # Server Implementation

  @impl true
  def init(_opts) do
    Logger.info("Starting browser manager...")
    
    case launch_browser() do
      {:ok, browser} ->
        Logger.info("Browser launched successfully")
        {:ok, %{browser: browser, pages: []}}
      
      {:error, reason} ->
        Logger.error("Failed to launch browser: #{reason}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_page, _from, %{browser: browser, pages: pages} = state) do
    case create_new_page(browser) do
      {:ok, page} ->
        new_pages = [page | pages]
        Logger.info("Created new page. Total pages: #{length(new_pages)}")
        {:reply, {:ok, page}, %{state | pages: new_pages}}
      
      {:error, reason} ->
        Logger.error("Failed to create new page: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_browser, _from, %{browser: browser} = state) do
    {:reply, {:ok, browser}, state}
  end

  @impl true
  def handle_call(:shutdown, _from, %{browser: browser, pages: pages} = state) do
    Logger.info("Shutting down browser manager...")
    
    # Close all pages first
    Enum.each(pages, fn page ->
      try do
        Playwright.Page.close(page)
      rescue
        error ->
          Logger.warning("Error closing page during shutdown: #{inspect(error)}")
      end
    end)
    
    # Close the browser
    try do
      Playwright.Browser.close(browser)
      Logger.info("Browser closed successfully")
    rescue
      error ->
        Logger.error("Error closing browser: #{inspect(error)}")
    end
    
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_cast({:close_page, page}, %{pages: pages} = state) do
    try do
      Playwright.Page.close(page)
      updated_pages = List.delete(pages, page)
      Logger.info("Closed page. Remaining pages: #{length(updated_pages)}")
      {:noreply, %{state | pages: updated_pages}}
    rescue
      error ->
        Logger.warning("Error closing page: #{inspect(error)}")
        # Still remove it from our tracking list
        updated_pages = List.delete(pages, page)
        {:noreply, %{state | pages: updated_pages}}
    end
  end

  @impl true
  def terminate(reason, %{browser: browser, pages: pages}) do
    Logger.info("Browser manager terminating with reason: #{inspect(reason)}")
    
    # Clean up pages
    Enum.each(pages, fn page ->
      try do
        Playwright.Page.close(page)
      rescue
        error ->
          Logger.warning("Error closing page during terminate: #{inspect(error)}")
      end
    end)
    
    # Clean up browser
    try do
      Playwright.Browser.close(browser)
    rescue
      error ->
        Logger.warning("Error closing browser during terminate: #{inspect(error)}")
    end
    
    :ok
  end

  # Private Functions

  defp launch_browser do
    case Playwright.launch(:chromium, @browser_opts) do
      {:ok, browser} ->
        {:ok, browser}
      
      other_response ->
        {:error, "Failed to start Playwright: #{inspect(other_response)}"}
    end
  end

  defp create_new_page(browser) do
    try do
      page = Playwright.Browser.new_page(browser)
      {:ok, page}
    rescue
      error ->
        {:error, "Failed to create page: #{inspect(error)}"}
    end
  end
end