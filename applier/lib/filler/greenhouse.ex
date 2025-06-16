defmodule Filler.Greenhouse do
  require Logger

  @doc """
  Fills a Greenhouse form with the provided responses.

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
    with :ok <- (Logger.info("Starting form fill process..."); :ok),
         {:ok, :form_filled} <- fill_all_fields(page, responses),
         {:ok, :documents_uploaded} <- handle_document_uploads(page, resume_text, cover_letter_text),
         :ok <- (Logger.info("Form fill completed successfully"); :ok)
    do
      {:ok, :form_filled}
    else
      {:error, reason} ->
        Logger.error("Form fill failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fill_all_fields(page, responses) do
    results = Enum.map(Map.values(responses), fn response ->
      fill_single_field(page, response)
    end)

    # Check if any field failed to fill
    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil -> {:ok, :form_filled}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fill_single_field(page, %{"id" => id, "label" => label, "response" => response})
       when is_binary(id) and response != "" do
    Logger.info("Filling field '#{label}' (#{id}) with: #{response}")

    cond do
      is_greenhouse_select?(page, id) ->
        fill_greenhouse_select(page, id, response)

      is_regular_input?(page, id) ->
        fill_regular_input(page, id, response)

      true ->
        Logger.warning("Field #{id} not found or unsupported")
        {:ok, :skipped}
    end
  end

  defp fill_single_field(_page, %{"response" => response}) when response == "" do
    {:ok, :skipped}
  end

  defp fill_single_field(_page, _response) do
    {:ok, :skipped}
  end

  defp is_greenhouse_select?(page, id) do
    selector = ".select__container input[id='#{id}']"
    element = Playwright.Page.locator(page, selector)
    Playwright.Locator.count(element) > 0
  end

  defp is_regular_input?(page, id) do
    selector = "input[id='#{id}'], textarea[id='#{id}'], select[id='#{id}']"
    element = Playwright.Page.locator(page, selector)
    Playwright.Locator.count(element) > 0
  end

  defp fill_greenhouse_select(page, id, value) do
    with {:ok, input} <- find_greenhouse_select_input(page, id),
         :ok <- click_and_wait_for_options(page, input),
         {:ok, option} <- find_matching_option(page, value),
         :ok <- select_option(option)
    do
      Logger.info("Successfully filled Greenhouse select #{id}")
      {:ok, :filled}
    else
      {:error, reason} ->
        Logger.error("Failed to fill Greenhouse select #{id}: #{reason}")
        {:error, reason}
    end
  end

  defp find_greenhouse_select_input(page, id) do
    selector = ".select__container input[id='#{id}']"
    input = Playwright.Page.locator(page, selector)

    case Playwright.Locator.count(input) do
      0 -> {:error, "Greenhouse select input not found for id: #{id}"}
      _ -> {:ok, input}
    end
  end

  defp click_and_wait_for_options(page, input) do
    try do
      Playwright.Locator.click(input)
      Playwright.Page.wait_for_selector(page, ".select__option", %{timeout: 5000})
      :ok
    rescue
      error ->
        {:error, "Failed to open select options: #{inspect(error)}"}
    end
  end

  defp find_matching_option(page, value) do
    options_locator = Playwright.Page.locator(page, ".select__option")
    options = if Playwright.Locator.count(options_locator) > 0 do
      Playwright.Locator.all(options_locator)
    else
      []
    end

    IO.puts(length(options))

    matching_option = Enum.find(options, fn option ->
      IO.puts(Playwright.Locator.inner_text(option))
      text = Playwright.Locator.inner_text(option) |> String.trim()
      String.contains?(String.downcase(text), String.downcase(value)) or
      String.contains?(String.downcase(value), String.downcase(text))
    end)

    case matching_option do
      nil -> {:error, "No matching option found for value: #{value}"}
      option -> {:ok, option}
    end
  end

  defp select_option(option) do
    try do
      Playwright.Locator.click(option)
      :ok
    rescue
      error ->
        {:error, "Failed to click option: #{inspect(error)}"}
    end
  end

  defp fill_regular_input(page, id, value) do
    selector = "input[id='#{id}'], textarea[id='#{id}'], select[id='#{id}']"
    element = Playwright.Page.locator(page, selector)

    case Playwright.Locator.count(element) do
      0 ->
        Logger.warning("Regular input not found for id: #{id}")
        {:ok, :skipped}

      _ ->
        try do
          # Clear existing content and fill with new value
          Playwright.Locator.clear(element)
          Playwright.Locator.fill(element, value)
          Logger.info("Successfully filled regular input #{id}")
          {:ok, :filled}
        rescue
          error ->
            Logger.error("Failed to fill regular input #{id}: #{inspect(error)}")
            {:error, "Failed to fill input: #{inspect(error)}"}
        end
    end
  end

  defp handle_document_uploads(page, resume_text, cover_letter_text) do
    with {:ok, :resume_handled} <- handle_resume_upload(page, resume_text),
         {:ok, :cover_letter_handled} <- handle_cover_letter_upload(page, cover_letter_text)
    do
      {:ok, :documents_uploaded}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_resume_upload(_page, nil) do
    Logger.info("No resume text provided, skipping resume upload")
    {:ok, :resume_handled}
  end

  defp handle_resume_upload(page, resume_text) when is_binary(resume_text) and resume_text != "" do
    Logger.info("Handling resume upload via 'enter manually'")

    with {:ok, enter_button} <- find_resume_enter_manually_button(page),
         :ok <- click_enter_manually_button(enter_button),
         {:ok, textarea} <- find_resume_textarea(page),
         :ok <- fill_resume_textarea(textarea, resume_text)
    do
      Logger.info("Successfully uploaded resume via text entry")
      {:ok, :resume_handled}
    else
      {:error, reason} ->
        Logger.error("Failed to handle resume upload: #{reason}")
        {:error, reason}
    end
  end

  defp handle_resume_upload(_page, _resume_text) do
    Logger.info("Invalid resume text, skipping resume upload")
    {:ok, :resume_handled}
  end

  defp handle_cover_letter_upload(page, nil) do
    Logger.info("No cover letter text provided, skipping cover letter upload")
    {:ok, :cover_letter_handled}
  end

  defp handle_cover_letter_upload(page, cover_letter_text) when is_binary(cover_letter_text) and cover_letter_text != "" do
    Logger.info("Handling cover letter upload via 'enter manually'")

    with {:ok, enter_button} <- find_cover_letter_enter_manually_button(page),
         :ok <- click_enter_manually_button(enter_button),
         {:ok, textarea} <- find_cover_letter_textarea(page),
         :ok <- fill_cover_letter_textarea(textarea, cover_letter_text)
    do
      Logger.info("Successfully uploaded cover letter via text entry")
      {:ok, :cover_letter_handled}
    else
      {:error, reason} ->
        Logger.error("Failed to handle cover letter upload: #{reason}")
        {:error, reason}
    end
  end

  defp handle_cover_letter_upload(_page, _cover_letter_text) do
    Logger.info("Invalid cover letter text, skipping cover letter upload")
    {:ok, :cover_letter_handled}
  end

  defp find_resume_enter_manually_button(page) do
    # Look for the "Enter manually" button in the resume section
    selector = "[data-testid='resume-text'], button:has-text('Enter manually')"
    button = Playwright.Page.locator(page, selector).first()

    case Playwright.Locator.count(button) do
      0 -> {:error, "Resume 'Enter manually' button not found"}
      _ -> {:ok, button}
    end
  end

  defp find_cover_letter_enter_manually_button(page) do
    # Look for the "Enter manually" button in the cover letter section
    selector = "[data-testid='cover_letter-text'], button:has-text('Enter manually')"
    button = Playwright.Page.locator(page, selector).first()

    case Playwright.Locator.count(button) do
      0 -> {:error, "Cover letter 'Enter manually' button not found"}
      _ -> {:ok, button}
    end
  end

  defp click_enter_manually_button(button) do
    try do
      Playwright.Locator.click(button)
      # Wait a moment for the textarea to appear
      :timer.sleep(1000)
      :ok
    rescue
      error ->
        {:error, "Failed to click 'Enter manually' button: #{inspect(error)}"}
    end
  end

  defp find_resume_textarea(page) do
    selector = "textarea[id='resume_text']"
    textarea = Playwright.Page.locator(page, selector)

    case Playwright.Locator.count(textarea) do
      0 -> {:error, "Resume textarea not found after clicking 'Enter manually'"}
      _ -> {:ok, textarea}
    end
  end

  defp find_cover_letter_textarea(page) do
    selector = "textarea[id='cover_letter_text']"
    textarea = Playwright.Page.locator(page, selector)

    case Playwright.Locator.count(textarea) do
      0 -> {:error, "Cover letter textarea not found after clicking 'Enter manually'"}
      _ -> {:ok, textarea}
    end
  end

  defp fill_resume_textarea(textarea, resume_text) do
    try do
      Playwright.Locator.clear(textarea)
      Playwright.Locator.fill(textarea, resume_text)
      Logger.info("Successfully filled resume textarea")
      :ok
    rescue
      error ->
        {:error, "Failed to fill resume textarea: #{inspect(error)}"}
    end
  end

  defp fill_cover_letter_textarea(textarea, cover_letter_text) do
    try do
      Playwright.Locator.clear(textarea)
      Playwright.Locator.fill(textarea, cover_letter_text)
      Logger.info("Successfully filled cover letter textarea")
      :ok
    rescue
      error ->
        {:error, "Failed to fill cover letter textarea: #{inspect(error)}"}
    end
  end
end
