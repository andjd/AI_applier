defmodule Scraper.AshbyHQ do
  require Logger

  def extract_questions(page) do
    # First, ensure we're on the application form page
    with {:ok, page} <- navigate_to_application_form(page),
         {:ok, questions} <- extract_form_questions(page)
    do
      {:ok, questions}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp navigate_to_application_form(page) do
    url = Playwright.Page.url(page)
    if String.contains?(url, "/application") do
      {:ok, page}
    else
      apply_url = url <> "/application"
      Logger.info("Navigating to AshbyHQ application form: #{apply_url}")
      response = Playwright.Page.goto(page, apply_url)
      :timer.sleep(500)
      if response.status == 200 do
        {:ok, page}
      else
        {:error, "Failed to navigate to application form: #{response}"}
      end
    end
  end

  defp extract_form_questions(page) do
    # Extract all form fields from the AshbyHQ form
    Logger.info("[AshbyHQ] Starting form question extraction")
    questions = []

    # Extract standard text inputs
    Logger.info("[AshbyHQ] Extracting text inputs...")
    text_inputs = extract_text_inputs(page)
    Logger.info("[AshbyHQ] Found #{length(text_inputs)} text inputs: #{inspect(text_inputs)}")
    questions = questions ++ text_inputs

    # Extract file upload fields
    Logger.info("[AshbyHQ] Extracting file upload fields...")
    file_uploads = extract_file_uploads(page)
    Logger.info("[AshbyHQ] Found #{length(file_uploads)} file uploads: #{inspect(file_uploads)}")
    questions = questions ++ file_uploads

    # Extract yes/no questions
    Logger.info("[AshbyHQ] Extracting yes/no questions...")
    yes_no_questions = extract_yes_no_questions(page)
    Logger.info("[AshbyHQ] Found #{length(yes_no_questions)} yes/no questions: #{inspect(yes_no_questions)}")
    questions = questions ++ yes_no_questions

    Logger.info("[AshbyHQ] Total questions extracted: #{length(questions)}")
    {:ok, questions}
  end

  defp extract_text_inputs(page) do
    # Target text inputs, email, tel, and textarea fields
    selectors = [
      "input[type='text']",
      "input[type='email']",
      "input[type='tel']",
      "textarea"
    ]

    Enum.flat_map(selectors, fn selector ->
      elements = Playwright.Page.locator(page, selector)
      element_count = Playwright.Locator.count(elements)
      Logger.info("[AshbyHQ] Selector '#{selector}' found #{element_count} elements")

      if element_count > 0 do
        all_elements = Playwright.Locator.all(elements)
        Logger.info("[AshbyHQ] Processing #{length(all_elements)} elements for selector '#{selector}'")

        extracted_fields = all_elements
        |> Enum.with_index()
        |> Enum.map(fn {element, index} ->
          Logger.info("[AshbyHQ] Processing element #{index + 1} for selector '#{selector}'")
          result = extract_field_info(page, element)
          Logger.info("[AshbyHQ] Element #{index + 1} result: #{inspect(result)}")
          result
        end)
        |> Enum.filter(& &1 != nil)

        Logger.info("[AshbyHQ] After filtering, #{length(extracted_fields)} fields remain for selector '#{selector}'")
        extracted_fields
      else
        Logger.info("[AshbyHQ] No elements found for selector '#{selector}'")
        []
      end
    end)
  end

  defp extract_file_uploads(page) do
    # Extract file upload fields
    file_selectors = [
      "input[type='file']"
    ]

    Enum.flat_map(file_selectors, fn selector ->
      elements = Playwright.Page.locator(page, selector)
      if Playwright.Locator.count(elements) > 0 do
        Playwright.Locator.all(elements)
        |> Enum.map(fn element ->
          extract_file_field_info(page, element)
        end)
        |> Enum.filter(& &1 != nil)
      else
        []
      end
    end)
  end

  defp extract_yes_no_questions(page) do
    # Extract yes/no questions by finding containers with Yes/No buttons and a checkbox
    yes_no_containers = Playwright.Page.locator(page, "div:has(button:text('Yes')):has(button:text('No')):has(input[type='checkbox'])")

    if Playwright.Locator.count(yes_no_containers) > 0 do
      Playwright.Locator.all(yes_no_containers)
      |> Enum.map(fn container ->
        extract_yes_no_field_info(page, container)
      end)
      |> Enum.filter(& &1 != nil)
    else
      []
    end
  end

  defp extract_field_info(page, element) do
    id = Playwright.Locator.get_attribute(element, "id")
    name = Playwright.Locator.get_attribute(element, "name")
    type = get_field_type(element)

    Logger.info("[AshbyHQ] extract_field_info - id: #{inspect(id)}, name: #{inspect(name)}, type: #{inspect(type)}")

    # Skip autofill fields and hidden fields
    if should_skip_field?(id, name, type) do
      Logger.info("[AshbyHQ] Skipping field with id: #{inspect(id)}, name: #{inspect(name)}, type: #{inspect(type)}")
      nil
    else
      Logger.info("[AshbyHQ] Processing field with id: #{inspect(id)}, name: #{inspect(name)}, type: #{inspect(type)}")
      required = is_field_required(element)
      max_length = get_max_length(element)
      placeholder = get_placeholder(element)
      label = get_field_label(page, element)

      Logger.info("[AshbyHQ] Field details - required: #{inspect(required)}, max_length: #{inspect(max_length)}, placeholder: #{inspect(placeholder)}, label: #{inspect(label)}")

      field_result = %{
        id: id || name || "",
        label: label || placeholder || "",
        type: type,
        required: required || false,
        max_length: max_length,
        options: []
      }

      Logger.info("[AshbyHQ] Final field result: #{inspect(field_result)}")
      field_result
    end
  end

  defp extract_file_field_info(page, element) do
    id = Playwright.Locator.get_attribute(element, "id")
    name = Playwright.Locator.get_attribute(element, "name")

    # Skip autofill file inputs
    if should_skip_field?(id, name, "file") do
      nil
    else
      required = is_field_required(element)
      label = get_field_label(page, element)
      accept = Playwright.Locator.get_attribute(element, "accept")

      %{
        id: id || name || "",
        label: label || "",
        type: "file",
        required: required || false,
        max_length: nil,
        options: [],
        accept: accept
      }
    end
  end

  defp extract_yes_no_field_info(page, container) do
    # Find the associated hidden checkbox input
    checkbox = Playwright.Locator.locator(container, "input[type='checkbox']")

    if Playwright.Locator.count(checkbox) > 0 do
      case Playwright.Locator.get_attribute(checkbox, "name") do
        name when is_binary(name) ->
          # Find the label by looking for the associated label element
          label = get_yes_no_label(page, name)

          if name && label do
            %{
              id: name,
              label: label,
              type: "yes_no",
              required: true,  # Most yes/no questions in AshbyHQ are required
              max_length: nil,
              options: ["Yes", "No"]
            }
          else
            nil
          end

        _ ->
          nil
      end
    else
      nil
    end
  end

  defp get_yes_no_label(page, field_name) do
    # Find the label element associated with this field
    label_selector = "label[for='#{field_name}']"
    label_locator = Playwright.Page.locator(page, label_selector)

    if Playwright.Locator.count(label_locator) > 0 do
      case Playwright.Locator.inner_text(label_locator) do
        label_text when is_binary(label_text) ->
          clean_label(label_text)
        _ ->
          nil
      end
    else
      nil
    end
  end

  defp get_field_type(element) do
    element_type = Playwright.Locator.get_attribute(element, "type")
    tag_name = Playwright.Locator.evaluate(element, "el => el.tagName.toLowerCase()")

    case {tag_name, element_type} do
      {"textarea", _} -> "textarea"
      {"input", "email"} -> "email"
      {"input", "tel"} -> "tel"
      {"input", "text"} -> "text"
      {"input", "file"} -> "file"
      _ -> "text"
    end
  end

  defp should_skip_field?(id, name, type) do
    # Skip autofill inputs and hidden fields
    skip_patterns = [
      "autofill",
      "recaptcha"
    ]

    field_identifiers = [id, name, type]
    |> Enum.filter(& &1 != nil)
    |> Enum.map(&String.downcase/1)

    Logger.info("[AshbyHQ] should_skip_field? - id: #{inspect(id)}, name: #{inspect(name)}, type: #{inspect(type)}")
    Logger.info("[AshbyHQ] field_identifiers: #{inspect(field_identifiers)}")

    # Skip hidden fields
    if type == "hidden" do
      Logger.info("[AshbyHQ] Skipping hidden field")
      true
    else
      skip_result = Enum.any?(skip_patterns, fn pattern ->
        pattern_match = Enum.any?(field_identifiers, fn identifier ->
          contains_result = String.contains?(identifier, pattern)
          Logger.info("[AshbyHQ] Checking if '#{identifier}' contains '#{pattern}': #{contains_result}")
          contains_result
        end)
        Logger.info("[AshbyHQ] Pattern '#{pattern}' matched: #{pattern_match}")
        pattern_match
      end)
      Logger.info("[AshbyHQ] Final skip result: #{skip_result}")
      skip_result
    end
  end

  defp is_field_required(element) do
    required_attr = Playwright.Locator.get_attribute(element, "required")
    required_attr != nil && required_attr != "false"
  end

  defp get_max_length(element) do
    max_length = Playwright.Locator.get_attribute(element, "maxlength")
    case max_length do
      nil -> nil
      "" -> nil
      length -> String.to_integer(length)
    end
  end

  defp get_placeholder(element) do
    Playwright.Locator.get_attribute(element, "placeholder")
  end

  defp get_field_label(page, element) do
    # Try to find label by for attribute
    id = Playwright.Locator.get_attribute(element, "id")
    Logger.info("[AshbyHQ] get_field_label - looking for label for id: #{inspect(id)}")

    if id do
      label_selector = "label[for='#{id}']"
      label_locator = Playwright.Page.locator(page, label_selector)
      label_count = Playwright.Locator.count(label_locator)
      Logger.info("[AshbyHQ] Found #{label_count} labels with selector: #{label_selector}")

      if label_count > 0 do
        label_text = Playwright.Locator.inner_text(label_locator)
        Logger.info("[AshbyHQ] Label text found: #{inspect(label_text)}")
        cleaned_label = clean_label(label_text)
        Logger.info("[AshbyHQ] Cleaned label: #{inspect(cleaned_label)}")
        cleaned_label
      else
        Logger.info("[AshbyHQ] No label found by for attribute, trying ancestor approach")
        find_ancestor_label(page, element)
      end
    else
      Logger.info("[AshbyHQ] No id attribute, trying ancestor approach")
      find_ancestor_label(page, element)
    end
  end

  defp find_ancestor_label(page, element) do
    # Try to find label by looking at parent elements
    Logger.info("[AshbyHQ] find_ancestor_label - searching for ancestor label")

    try do
      parent_label = Playwright.Locator.evaluate(element, """
        (el) => {
          // Look for closest label element
          let current = el.closest('label');
          if (current) {
            return current.textContent.trim();
          }

          // Look for parent with ashby-application-form-field-entry class
          let parent = el.closest('.ashby-application-form-field-entry');
          if (parent) {
            let labelEl = parent.querySelector('label');
            if (labelEl) {
              return labelEl.textContent.trim();
            }
          }

          return '';
        }
      """)

      Logger.info("[AshbyHQ] find_ancestor_label - parent_label result: #{inspect(parent_label)}")
      cleaned_result = clean_label(parent_label)
      Logger.info("[AshbyHQ] find_ancestor_label - cleaned result: #{inspect(cleaned_result)}")
      cleaned_result
    rescue
      error ->
        Logger.info("[AshbyHQ] find_ancestor_label - error: #{inspect(error)}")
        ""
    end
  end

  defp clean_label(label) do
    label
    |> String.trim()
    |> String.replace(~r/\s*\*\s*$/, "")      # Remove required asterisk
    |> String.replace(~r/\s+/, " ")           # Normalize whitespace
  end
end
