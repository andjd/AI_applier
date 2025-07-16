defmodule Filler.AshbyHQ do
  alias ElixirSense.Log
  require Logger

  @doc """
  Fills an AshbyHQ form with the provided responses.

  ## Parameters
  - page: Playwright page object
  - responses: List of maps with "id", "label", and "response" keys
  - short_id: Short ID for the application to fetch resume/cover letter files

  ## Returns
  {:ok, :form_filled} on success
  {:error, reason} on failure
  """
  def fill_form(page, responses, short_id) when is_map(responses) do
    Logger.info(inspect(responses))
    with :ok <- (Logger.info("Starting AshbyHQ form fill process..."); :ok),
         {:ok, page} <- navigate_to_application_form(page),
         {:ok, :resume_uploaded} <- handle_resume_upload(page, short_id),
         {:ok, :form_filled} <- fill_all_fields(page, responses),
         :ok <- (Logger.info("AshbyHQ form fill completed successfully"); :ok)
    do
      {:ok, :form_filled}
    else
      {:error, reason} ->
        Logger.error("AshbyHQ form fill failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp navigate_to_application_form(page) do
    url = Playwright.Page.url(page)
    if String.contains?(url, "/application") do
      Logger.info("Already on application form page")
      {:ok, page}
    else
      apply_url = url <> "/application"
      Logger.info("Navigating to AshbyHQ application form: #{apply_url}")
      response = Playwright.Page.goto(page, apply_url)
      if response.status == 200 do
        # Wait for page to load
        :timer.sleep(2000)
        Logger.info("Successfully navigated to application form")
        {:ok, page}
      else
        {:error, "Failed to navigate to application form: #{response}"}
      end
    end
  end

  defp handle_resume_upload(page, short_id) do
    case Helpers.DocumentFetcher.get_resume(short_id, :pdf) do
      {:ok, file_path} ->
        upload_resume_file(page, file_path)
      {:error, reason} ->
        Logger.warning("Resume file not found: #{reason}")
        {:ok, :resume_uploaded}
    end
  end

  defp upload_resume_file(page, file_path) do
    try do
      # Wait for page to load
      :timer.sleep(1000)

      Logger.info("Starting file upload using file chooser event for: #{file_path}")

      # Find the upload button
      upload_button_selectors = [
        "button:has-text('Upload File')",
      ]

      upload_button = find_first_matching_element(page, upload_button_selectors)

      if upload_button do
        Logger.info("Found upload button, trying to find associated file input")

        # Try to find the associated file input near the button
        file_input_selectors = [
          "input[type='file'][id='_systemfield_resume']",
          "input[type='file'][name='_systemfield_resume']",
          "input[type='file'][id*='resume']",
          "input[type='file'][name*='resume']"
        ]

        file_input = find_first_matching_element(page, file_input_selectors)

        if file_input do
          Logger.info("Found file input, uploading directly")

          # Upload the file directly to the input
          Playwright.Locator.set_input_files(file_input, file_path)

          # Click the button to trigger any additional processing
          Playwright.Locator.click(upload_button)
          Logger.info("Clicked upload button after setting files")

          # Wait for upload to complete
          :timer.sleep(2000)

          Logger.info("Resume upload completed")
          {:ok, :resume_uploaded}
        else
          Logger.error("File input not found even though button was found")
          log_available_file_inputs(page)
          {:error, "File input not found"}
        end
      else
        Logger.error("Upload button not found")
        log_available_buttons(page)
        {:error, "Upload button not found"}
      end
    rescue
      error ->
        Logger.error("Error during resume upload: #{inspect(error)}")
        {:error, "Resume upload failed: #{inspect(error)}"}
    end
  end

  defp find_first_matching_element(page, selectors) do
    Enum.find_value(selectors, fn selector ->
      element = Playwright.Page.locator(page, selector)
      if Playwright.Locator.count(element) > 0 do
        Logger.info("Found element with selector: #{selector}")
        element
      else
        nil
      end
    end)
  end

  defp log_available_file_inputs(page) do
    try do
      # Log all file inputs on the page for debugging
      file_inputs = Playwright.Page.locator(page, "input[type='file']")
      count = Playwright.Locator.count(file_inputs)
      Logger.info("Found #{count} file input(s) on page")

      if count > 0 do
        Playwright.Locator.all(file_inputs)
        |> Enum.with_index()
        |> Enum.each(fn {input, index} ->
          id = Playwright.Locator.get_attribute(input, "id") || "no-id"
          name = Playwright.Locator.get_attribute(input, "name") || "no-name"
          Logger.info("File input #{index + 1}: id='#{id}', name='#{name}'")
        end)
      end
    rescue
      error ->
        Logger.error("Error logging file inputs: #{inspect(error)}")
    end
  end

  defp log_available_buttons(page) do
    try do
      # Log all buttons on the page for debugging
      buttons = Playwright.Page.locator(page, "button")
      count = Playwright.Locator.count(buttons)
      Logger.info("Found #{count} button(s) on page")

      if count > 0 do
        Playwright.Locator.all(buttons)
        |> Enum.with_index()
        |> Enum.take(10)  # Limit to first 10 buttons to avoid spam
        |> Enum.each(fn {button, index} ->
          text = Playwright.Locator.inner_text(button) || "no-text"
          class_attr = Playwright.Locator.get_attribute(button, "class") || "no-class"
          Logger.info("Button #{index + 1}: text='#{String.trim(text)}', class='#{class_attr}'")
        end)
      end
    rescue
      error ->
        Logger.error("Error logging buttons: #{inspect(error)}")
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
      is_yes_no_field?(page, id) ->
        fill_yes_no_field(page, id, response)

      is_file_upload_field?(page, id) ->
        Logger.info("Skipping file upload field: #{id}")
        {:ok, :skipped}

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

  defp is_yes_no_field?(page, id) do
    # Check if there's a yes/no container for this field
    container_selector = "div._container_y2cw4_29._yesno_hkyf8_143"
    containers = Playwright.Page.locator(page, container_selector)

    if Playwright.Locator.count(containers) > 0 do
      containers_list = Playwright.Locator.all(containers)

      Enum.any?(containers_list, fn container ->
        checkbox = Playwright.Locator.locator(container, "input[type='checkbox']")
        if Playwright.Locator.count(checkbox) > 0 do
          name = Playwright.Locator.get_attribute(checkbox, "name")
          name == id
        else
          false
        end
      end)
    else
      false
    end
  end

  defp is_file_upload_field?(page, id) do
    selector = "input[type='file'][id='#{id}'], input[type='file'][name='#{id}']"
    element = Playwright.Page.locator(page, selector)
    Playwright.Locator.count(element) > 0
  end

  defp is_regular_input?(page, id) do
    selector = "input[id='#{id}'], input[name='#{id}'], textarea[id='#{id}'], textarea[name='#{id}']"
    element = Playwright.Page.locator(page, selector)
    Playwright.Locator.count(element) > 0
  end

  defp fill_yes_no_field(page, id, response) do
    try do
      # Find the container for this field
      container_selector = "div._container_y2cw4_29._yesno_hkyf8_143"
      containers = Playwright.Page.locator(page, container_selector)

      if Playwright.Locator.count(containers) > 0 do
        containers_list = Playwright.Locator.all(containers)

        # Find the container that corresponds to this field
        target_container = Enum.find(containers_list, fn container ->
          checkbox = Playwright.Locator.locator(container, "input[type='checkbox']")
          if Playwright.Locator.count(checkbox) > 0 do
            name = Playwright.Locator.get_attribute(checkbox, "name")
            name == id
          else
            false
          end
        end)

        if target_container do
          # Determine which button to click based on response
          button_text = if String.downcase(response) in ["yes", "y", "true", "1"] do
            "Yes"
          else
            "No"
          end

          # Find and click the appropriate button
          button_selector = "button._container_pjyt6_1._option_y2cw4_33"
          buttons = Playwright.Locator.locator(target_container, button_selector)

          if Playwright.Locator.count(buttons) > 0 do
            button_elements = Playwright.Locator.all(buttons)

            target_button = Enum.find(button_elements, fn button ->
              text = Playwright.Locator.inner_text(button)
              text == button_text
            end)

            if target_button do
              Playwright.Locator.click(target_button)
              Logger.info("Clicked #{button_text} button for field #{id}")
              {:ok, :filled}
            else
              Logger.error("Could not find #{button_text} button for field #{id}")
              {:error, "Button not found"}
            end
          else
            Logger.error("No buttons found for yes/no field #{id}")
            {:error, "No buttons found"}
          end
        else
          Logger.error("Could not find container for yes/no field #{id}")
          {:error, "Container not found"}
        end
      else
        Logger.error("No yes/no containers found on page")
        {:error, "No yes/no containers found"}
      end
    rescue
      error ->
        Logger.error("Error filling yes/no field #{id}: #{inspect(error)}")
        {:error, "Failed to fill yes/no field: #{inspect(error)}"}
    end
  end

  defp fill_regular_input(page, id, response) do
    try do
      selector = "input[id='#{id}'], input[name='#{id}'], textarea[id='#{id}'], textarea[name='#{id}']"
      element = Playwright.Page.locator(page, selector)

      if Playwright.Locator.count(element) > 0 do
        # Clear the field first, then fill it
        Playwright.Locator.clear(element)
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
end
