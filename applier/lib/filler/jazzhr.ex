defmodule Filler.JazzHR do
  require Logger

  @doc """
  Fills a JazzHR web form with the provided responses.
  
  JazzHR forms require clicking a "Paste resume" link to make the resume textarea appear.
  After handling this special case, delegates to the generic filler.

  ## Parameters
  - page: Playwright page object
  - responses: List of maps with "id", "label", and "response" keys
  - resume_text: Resume content as text (optional)
  - cover_letter_text: Cover letter content as text (optional)

  ## Returns
  {:ok, :form_filled} on success
  {:error, reason} on failure
  """
  def fill_form(page, responses, resume_text \\ nil, cover_letter_text \\ nil) when is_map(responses) do
    with :ok <- (Logger.info("Starting JazzHR form fill process..."); :ok),
         {:ok, :paste_resume_handled} <- handle_paste_resume_link(page),
         {:ok, :form_filled} <- Filler.Generic.fill_form(page, responses, resume_text, cover_letter_text),
         :ok <- (Logger.info("JazzHR form fill completed successfully"); :ok)
    do
      {:ok, :form_filled}
    else
      {:error, reason} ->
        Logger.error("JazzHR form fill failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_paste_resume_link(page) do
    Logger.info("Looking for 'Paste resume' link")
    
    # First check if the resume textarea is already visible
    resume_textarea = Playwright.Page.locator(page, "#resumator-resumetext-field")
    
    if Playwright.Locator.count(resume_textarea) > 0 and Playwright.Locator.is_visible(resume_textarea) do
      Logger.info("Resume textarea is already visible")
      {:ok, :paste_resume_handled}
    else
      # Look for links or buttons with "Paste resume" text
      paste_resume_selectors = [
        "a:has-text('Paste resume')",
        "button:has-text('Paste resume')",
        "span:has-text('Paste resume')",
        "[role='button']:has-text('Paste resume')"
      ]
      
      found_element = Enum.find_value(paste_resume_selectors, fn selector ->
        element = Playwright.Page.locator(page, selector)
        case Playwright.Locator.count(element) do
          0 -> nil
          _ -> element
        end
      end)
      
      case found_element do
        nil ->
          Logger.error("Resume textarea not visible and no 'Paste resume' link found")
          {:error, "Resume textarea not visible and no 'Paste resume' link found"}
        
        element ->
          try do
            Logger.info("Found 'Paste resume' link, clicking to reveal textarea")
            Playwright.Locator.click(element)
            # Wait a moment for the textarea to appear
            Process.sleep(1000)
            
            # Verify the textarea is now visible
            if Playwright.Locator.count(resume_textarea) > 0 and Playwright.Locator.is_visible(resume_textarea) do
              Logger.info("Successfully clicked 'Paste resume' link and textarea is now visible")
              {:ok, :paste_resume_handled}
            else
              Logger.error("Clicked 'Paste resume' link but textarea is still not visible")
              {:error, "Resume textarea not visible after clicking 'Paste resume' link"}
            end
          rescue
            error ->
              Logger.error("Failed to click 'Paste resume' link: #{inspect(error)}")
              {:error, "Failed to click 'Paste resume' link: #{inspect(error)}"}
          end
      end
    end
  end
end