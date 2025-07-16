defmodule Filler.Lever do
  require Logger

  @doc """
  Fills a Lever form with the provided responses.

  ## Parameters
  - page: Playwright page object
  - responses: List of maps with "id", "label", and "response" keys
  - resume_text: Resume content as text (optional)
  - cover_letter_text: Cover letter content as text (optional)

  ## Returns
  {:ok, :form_filled} on success
  {:error, reason} on failure
  """
  def fill_form(page, responses, short_id) when is_map(responses) do
    with :ok <- (Logger.info("Starting Lever form fill process..."); :ok),
         {:ok, page} <- navigate_to_application_form(page),
         {:ok, :resume_uploaded} <- handle_resume_upload(page, short_id),
         {:ok, :form_filled} <- fill_all_fields(page, responses),
         {:ok, :additional_info_filled} <- fill_additional_information(page, short_id),
         :ok <- (Logger.info("Lever form fill completed successfully"); :ok)
    do
      {:ok, :form_filled}
    else
      {:error, reason} ->
        Logger.error("Lever form fill failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp navigate_to_application_form(page) do
    url = Playwright.Page.url(page)
    if String.contains?(url, "/apply") do
      {:ok, page}
    else
      apply_url = url <> "/apply"
      Logger.info("Navigating to application form: #{apply_url}")
      response = Playwright.Page.goto(page, apply_url)
      if response.status == 200 do
        {:ok, page}
      else
        {:error, "Failed to navigate to application form: #{response}"}
      end
    end
  end

  defp handle_resume_upload(page, short_id) do
    case Helpers.DocumentFetcher.get_resume(short_id, :txt) do
      {:ok, resume_text} when is_binary(resume_text) and resume_text != "" ->
        upload_resume_file(page, resume_text)
      {:error, reason} ->
        Logger.info("No resume text available: #{reason}")
        {:ok, :resume_uploaded}
      {:ok, _} ->
        Logger.info("Resume text is empty, skipping upload")
        {:ok, :resume_uploaded}
    end
  end

  defp upload_resume_file(page, resume_text) do
    try do
      # Create temporary file with resume content
      temp_file = create_temp_resume_file(resume_text)

      # Find the file upload input
      upload_input = Playwright.Page.locator(page, "input[type='file'][name='resume']")

      if Playwright.Locator.count(upload_input) > 0 do
        Logger.info("Uploading resume file...")

        # Upload the file
        Playwright.Locator.set_input_files(upload_input, temp_file)

        # Wait for upload to complete
        :timer.sleep(2000)

        # Check for success indicator
        success_indicator = Playwright.Page.locator(page, ".resume-upload-success")
        if Playwright.Locator.count(success_indicator) > 0 do
          Logger.info("Resume upload completed successfully")
          cleanup_temp_file(temp_file)
          {:ok, :resume_uploaded}
        else
          Logger.warning("Resume upload may have failed - no success indicator found")
          cleanup_temp_file(temp_file)
          {:ok, :resume_uploaded}
        end
      else
        Logger.error("Resume upload input not found")
        {:error, "Resume upload input not found"}
      end
    rescue
      error ->
        Logger.error("Error during resume upload: #{inspect(error)}")
        {:error, "Resume upload failed: #{inspect(error)}"}
    end
  end

  defp create_temp_resume_file(resume_text) do
    # Create a temporary file with the resume content
    temp_dir = System.tmp_dir()
    temp_file = Path.join(temp_dir, "resume_#{:os.system_time(:millisecond)}.txt")
    File.write!(temp_file, resume_text)
    temp_file
  end

  defp cleanup_temp_file(temp_file) do
    try do
      File.rm(temp_file)
    rescue
      _ -> :ok
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
      is_multi_select_field?(id) ->
        fill_multi_select_field(page, id, response)

      is_custom_card_field?(id) ->
        fill_custom_card_field(page, id, response)

      is_select_field?(page, id) ->
        fill_select_field(page, id, response)

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

  defp is_multi_select_field?(id) do
    id in ["pronouns"]
  end

  defp is_custom_card_field?(id) do
    String.contains?(id, "cards[")
  end

  defp is_select_field?(page, id) do
    selector = "select[id='#{id}'], select[name='#{id}']"
    element = Playwright.Page.locator(page, selector)
    Playwright.Locator.count(element) > 0
  end

  defp is_regular_input?(page, id) do
    selector = "input[id='#{id}'], input[name='#{id}'], textarea[id='#{id}'], textarea[name='#{id}']"
    element = Playwright.Page.locator(page, selector)
    Playwright.Locator.count(element) > 0
  end

  defp fill_multi_select_field(page, id, response) do
    case id do
      "pronouns" ->
        fill_pronouns_field(page, response)
      _ ->
        Logger.warning("Unknown multi-select field: #{id}")
        {:ok, :skipped}
    end
  end

  defp fill_pronouns_field(page, response) do
    try do
      # Handle both single and multiple pronoun selections
      pronouns_to_select = if is_list(response) do
        response
      else
        [response]
      end

      # Find all pronoun checkboxes
      checkboxes = Playwright.Page.locator(page, "input[type='checkbox'][name='pronouns']")

      if Playwright.Locator.count(checkboxes) > 0 do
        checkbox_elements = Playwright.Locator.all(checkboxes)

        Enum.each(checkbox_elements, fn checkbox ->
          value = Playwright.Locator.get_attribute(checkbox, "value")
          if value in pronouns_to_select do
            Playwright.Locator.check(checkbox)
            Logger.info("Selected pronoun: #{value}")
          end
        end)

        {:ok, :filled}
      else
        Logger.error("Pronoun checkboxes not found")
        {:error, "Pronoun checkboxes not found"}
      end
    rescue
      error ->
        Logger.error("Error filling pronouns field: #{inspect(error)}")
        {:error, "Failed to fill pronouns: #{inspect(error)}"}
    end
  end

  defp fill_custom_card_field(page, id, response) do
    try do
      # Handle radio buttons for custom card fields
      radio_selector = "input[type='radio'][name='#{id}']"
      radio_buttons = Playwright.Page.locator(page, radio_selector)

      if Playwright.Locator.count(radio_buttons) > 0 do
        radio_elements = Playwright.Locator.all(radio_buttons)

        # Find the radio button that matches the response
        matching_radio = Enum.find(radio_elements, fn radio ->
          value = Playwright.Locator.get_attribute(radio, "value")
          value && String.contains?(String.downcase(value), String.downcase(response))
        end)

        if matching_radio do
          Playwright.Locator.check(matching_radio)
          Logger.info("Selected custom card option: #{response}")
          {:ok, :filled}
        else
          Logger.warning("No matching option found for custom card field #{id} with response: #{response}")
          {:ok, :skipped}
        end
      else
        Logger.error("Custom card radio buttons not found for field: #{id}")
        {:error, "Custom card radio buttons not found"}
      end
    rescue
      error ->
        Logger.error("Error filling custom card field: #{inspect(error)}")
        {:error, "Failed to fill custom card field: #{inspect(error)}"}
    end
  end

  defp fill_select_field(page, id, response) do
    try do
      selector = "select[id='#{id}'], select[name='#{id}']"
      select_element = Playwright.Page.locator(page, selector)

      if Playwright.Locator.count(select_element) > 0 do
        # Get all options
        options = Playwright.Locator.locator(select_element, "option")

        if Playwright.Locator.count(options) > 0 do
          option_elements = Playwright.Locator.all(options)

          # Find matching option
          matching_option = Enum.find(option_elements, fn option ->
            text = Playwright.Locator.inner_text(option)
            value = Playwright.Locator.get_attribute(option, "value")

            text_match = text && String.contains?(String.downcase(text), String.downcase(response))
            value_match = value && String.contains?(String.downcase(value), String.downcase(response))

            text_match || value_match
          end)

          if matching_option do
            value = Playwright.Locator.get_attribute(matching_option, "value")
            Playwright.Locator.select_option(select_element, value)
            Logger.info("Selected option: #{response}")
            {:ok, :filled}
          else
            Logger.warning("No matching option found for select field #{id} with response: #{response}")
            {:ok, :skipped}
          end
        else
          Logger.error("No options found in select field: #{id}")
          {:error, "No options found in select field"}
        end
      else
        Logger.error("Select field not found: #{id}")
        {:error, "Select field not found"}
      end
    rescue
      error ->
        Logger.error("Error filling select field: #{inspect(error)}")
        {:error, "Failed to fill select field: #{inspect(error)}"}
    end
  end

  defp fill_regular_input(page, id, response) do
    try do
      selector = "input[id='#{id}'], input[name='#{id}'], textarea[id='#{id}'], textarea[name='#{id}']"
      element = Playwright.Page.locator(page, selector)

      if Playwright.Locator.count(element) > 0 do
        Playwright.Locator.fill(element, response)
        Logger.info("Filled regular input: #{id}")
        {:ok, :filled}
      else
        Logger.error("Regular input not found: #{id}")
        {:error, "Regular input not found"}
      end
    rescue
      error ->
        Logger.error("Error filling regular input: #{inspect(error)}")
        {:error, "Failed to fill regular input: #{inspect(error)}"}
    end
  end

  defp fill_additional_information(page, short_id) do
    case Helpers.DocumentFetcher.get_cover_letter(short_id, :txt) do
      {:ok, cover_letter_text} when is_binary(cover_letter_text) and cover_letter_text != "" ->
        try do
          additional_info_selector = "textarea[name='comments'], textarea[id='additional-information']"
          textarea = Playwright.Page.locator(page, additional_info_selector)

          if Playwright.Locator.count(textarea) > 0 do
            Playwright.Locator.fill(textarea, cover_letter_text)
            Logger.info("Filled additional information with cover letter")
            {:ok, :additional_info_filled}
          else
            Logger.warning("Additional information textarea not found")
            {:ok, :additional_info_filled}
          end
        rescue
          error ->
            Logger.error("Error filling additional information: #{inspect(error)}")
            {:error, "Failed to fill additional information: #{inspect(error)}"}
        end
      
      {:error, reason} ->
        Logger.info("No cover letter text available: #{reason}")
        {:ok, :additional_info_filled}
      
      {:ok, _} ->
        Logger.info("Cover letter text is empty, skipping additional information")
        {:ok, :additional_info_filled}
    end
  end
end
