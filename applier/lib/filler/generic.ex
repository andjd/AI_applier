defmodule Filler.Generic do
  require Logger

  @doc """
  Fills a generic web form with the provided responses.

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
    with :ok <- (Logger.info("Starting generic form fill process..."); :ok),
         {:ok, :form_filled} <- fill_all_fields(page, responses),
         {:ok, :documents_handled} <- handle_document_uploads(page, short_id),
         :ok <- (Logger.info("Generic form fill completed successfully"); :ok)
    do
      {:ok, :form_filled}
    else
      {:error, reason} ->
        Logger.error("Generic form fill failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fill_all_fields(page, responses) do
    results = Enum.map(Map.values(responses), fn response ->
      fill_single_field(page, response)
    end)

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil -> {:ok, :form_filled}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fill_single_field(page, %{"id" => id, "label" => label, "response" => response})
       when is_binary(id) and response != "" do
    Logger.info("Filling field '#{label}' (#{id}) with: #{response}")

    cond do
      is_select_field?(page, id) ->
        fill_select_field(page, id, response)

      is_radio_group?(page, id) ->
        fill_radio_group(page, id, response)

      is_checkbox_field?(page, id) ->
        fill_checkbox_field(page, id, response)

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

  defp is_select_field?(page, id) do
    selector = "select[id='#{id}'], select[name='#{id}']"
    element = Playwright.Page.locator(page, selector)
    Playwright.Locator.count(element) > 0
  end

  defp is_radio_group?(page, id) do
    selector = "input[type='radio'][name='#{id}']"
    element = Playwright.Page.locator(page, selector)
    Playwright.Locator.count(element) > 0
  end

  defp is_checkbox_field?(page, id) do
    selector = "input[type='checkbox'][id='#{id}'], input[type='checkbox'][name='#{id}']"
    element = Playwright.Page.locator(page, selector)
    Playwright.Locator.count(element) > 0
  end

  defp is_regular_input?(page, id) do
    selector = "input[id='#{id}'], textarea[id='#{id}'], input[name='#{id}'], textarea[name='#{id}']"
    element = Playwright.Page.locator(page, selector)
    Playwright.Locator.count(element) > 0
  end

  defp fill_select_field(page, id, value) do
    selector = "select[id='#{id}'], select[name='#{id}']"
    element = Playwright.Page.locator(page, selector)

    case Playwright.Locator.count(element) do
      0 ->
        Logger.warning("Select field not found for id: #{id}")
        {:ok, :skipped}

      _ ->
        with {:ok, matching_option} <- find_select_option(element, value),
             :ok <- select_option_by_value(element, matching_option)
        do
          Logger.info("Successfully filled select field #{id}")
          {:ok, :filled}
        else
          {:error, reason} ->
            Logger.error("Failed to fill select field #{id}: #{reason}")
            {:error, reason}
        end
    end
  end

  defp find_select_option(select_element, value) do
    options = Playwright.Locator.locator(select_element, "option")
    all_options = if Playwright.Locator.count(options) > 0 do
      Playwright.Locator.all(options)
    else
      []
    end

    matching_option = Enum.find(all_options, fn option ->
      text = Playwright.Locator.inner_text(option) |> String.trim()
      option_value = Playwright.Locator.get_attribute(option, "value")
      
      String.contains?(String.downcase(text), String.downcase(value)) or
      String.contains?(String.downcase(value), String.downcase(text)) or
      (option_value && String.contains?(String.downcase(option_value), String.downcase(value)))
    end)

    case matching_option do
      nil -> {:error, "No matching option found for value: #{value}"}
      option -> 
        option_value = Playwright.Locator.get_attribute(option, "value")
        {:ok, option_value || Playwright.Locator.inner_text(option)}
    end
  end

  defp select_option_by_value(select_element, value) do
    try do
      Playwright.Locator.select_option(select_element, %{value: value})
      :ok
    rescue
      error ->
        {:error, "Failed to select option: #{inspect(error)}"}
    end
  end

  defp fill_radio_group(page, name, value) do
    selector = "input[type='radio'][name='#{name}']"
    radios = Playwright.Page.locator(page, selector)
    all_radios = if Playwright.Locator.count(radios) > 0 do
      Playwright.Locator.all(radios)
    else
      []
    end

    matching_radio = Enum.find(all_radios, fn radio ->
      radio_value = Playwright.Locator.get_attribute(radio, "value")
      label_text = get_radio_label_text(page, radio)
      
      (radio_value && String.contains?(String.downcase(radio_value), String.downcase(value))) or
      (label_text && String.contains?(String.downcase(label_text), String.downcase(value))) or
      (radio_value && String.contains?(String.downcase(value), String.downcase(radio_value))) or
      (label_text && String.contains?(String.downcase(value), String.downcase(label_text)))
    end)

    case matching_radio do
      nil ->
        Logger.warning("No matching radio option found for value: #{value}")
        {:ok, :skipped}

      radio ->
        try do
          Playwright.Locator.check(radio)
          Logger.info("Successfully selected radio option for #{name}")
          {:ok, :filled}
        rescue
          error ->
            Logger.error("Failed to select radio option: #{inspect(error)}")
            {:error, "Failed to select radio option: #{inspect(error)}"}
        end
    end
  end

  defp get_radio_label_text(page, radio) do
    radio_id = Playwright.Locator.get_attribute(radio, "id")
    if radio_id do
      label = Playwright.Page.locator(page, "label[for='#{radio_id}']")
      case Playwright.Locator.count(label) do
        0 -> nil
        _ -> Playwright.Locator.inner_text(label) |> String.trim()
      end
    else
      nil
    end
  end

  defp fill_checkbox_field(page, id, value) do
    selector = "input[type='checkbox'][id='#{id}'], input[type='checkbox'][name='#{id}']"
    element = Playwright.Page.locator(page, selector)

    case Playwright.Locator.count(element) do
      0 ->
        Logger.warning("Checkbox field not found for id: #{id}")
        {:ok, :skipped}

      _ ->
        should_check = should_check_checkbox?(value)
        
        try do
          if should_check do
            Playwright.Locator.check(element)
          else
            Playwright.Locator.uncheck(element)
          end
          Logger.info("Successfully #{if should_check, do: "checked", else: "unchecked"} checkbox #{id}")
          {:ok, :filled}
        rescue
          error ->
            Logger.error("Failed to fill checkbox #{id}: #{inspect(error)}")
            {:error, "Failed to fill checkbox: #{inspect(error)}"}
        end
    end
  end

  defp should_check_checkbox?(value) when is_binary(value) do
    downcase_value = String.downcase(String.trim(value))
    downcase_value in ["yes", "true", "1", "on", "checked", "agree", "accept"]
  end
  defp should_check_checkbox?(_), do: false

  defp fill_regular_input(page, id, value) do
    selector = "input[id='#{id}'], textarea[id='#{id}'], input[name='#{id}'], textarea[name='#{id}']"
    element = Playwright.Page.locator(page, selector)

    case Playwright.Locator.count(element) do
      0 ->
        Logger.warning("Regular input not found for id: #{id}")
        {:ok, :skipped}

      _ ->
        try do
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

  defp handle_document_uploads(page, short_id) do
    with {:ok, :resume_handled} <- handle_resume_upload(page, short_id),
         {:ok, :cover_letter_handled} <- handle_cover_letter_upload(page, short_id)
    do
      {:ok, :documents_handled}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_resume_upload(page, short_id) when is_binary(short_id) do
    case Helpers.DocumentFetcher.get_resume(short_id, :txt) do
      {:ok, resume_text} when is_binary(resume_text) and resume_text != "" ->
        Logger.info("Attempting to handle resume upload")

        resume_fields = [
          "textarea[id*='resume'], textarea[name*='resume']",
          "input[id*='resume'], input[name*='resume']",
          "textarea[placeholder*='resume'], textarea[placeholder*='Resume']"
        ]

        found_field = Enum.find_value(resume_fields, fn selector ->
          element = Playwright.Page.locator(page, selector)
          case Playwright.Locator.count(element) do
            0 -> nil
            _ -> element
          end
        end)

        case found_field do
          nil ->
            Logger.info("No resume text field found, skipping resume upload")
            {:ok, :resume_handled}

          element ->
            try do
              Playwright.Locator.clear(element)
              Playwright.Locator.fill(element, resume_text)
              Logger.info("Successfully filled resume text field")
              {:ok, :resume_handled}
            rescue
              error ->
                Logger.error("Failed to fill resume field: #{inspect(error)}")
                {:error, "Failed to fill resume field: #{inspect(error)}"}
            end
        end
      
      {:error, reason} ->
        Logger.info("No resume text available: #{reason}")
        {:ok, :resume_handled}
      
      {:ok, _} ->
        Logger.info("Resume text is empty, skipping resume upload")
        {:ok, :resume_handled}
    end
  end

  defp handle_cover_letter_upload(page, short_id) when is_binary(short_id) do
    case Helpers.DocumentFetcher.get_cover_letter(short_id, :txt) do
      {:ok, cover_letter_text} when is_binary(cover_letter_text) and cover_letter_text != "" ->
        Logger.info("Attempting to handle cover letter upload")

        cover_letter_fields = [
          "textarea[id*='cover'], textarea[name*='cover']",
          "input[id*='cover'], input[name*='cover']",
          "textarea[placeholder*='cover'], textarea[placeholder*='Cover']",
          "textarea[id*='letter'], textarea[name*='letter']"
        ]

        found_field = Enum.find_value(cover_letter_fields, fn selector ->
          element = Playwright.Page.locator(page, selector)
          case Playwright.Locator.count(element) do
            0 -> nil
            _ -> element
          end
        end)

        case found_field do
          nil ->
            Logger.info("No cover letter text field found, skipping cover letter upload")
            {:ok, :cover_letter_handled}

          element ->
            try do
              Playwright.Locator.clear(element)
              Playwright.Locator.fill(element, cover_letter_text)
              Logger.info("Successfully filled cover letter text field")
              {:ok, :cover_letter_handled}
            rescue
              error ->
                Logger.error("Failed to fill cover letter field: #{inspect(error)}")
                {:error, "Failed to fill cover letter field: #{inspect(error)}"}
            end
        end
      
      {:error, reason} ->
        Logger.info("No cover letter text available: #{reason}")
        {:ok, :cover_letter_handled}
      
      {:ok, _} ->
        Logger.info("Cover letter text is empty, skipping cover letter upload")
        {:ok, :cover_letter_handled}
    end
  end
end