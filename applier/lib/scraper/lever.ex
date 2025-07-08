defmodule Scraper.Lever do
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
    if String.contains?(url, "/apply") do
      {:ok, page}
    else
      apply_url = url <> "/apply"
      IO.puts("Navigating to application form: #{apply_url}")
      response = Playwright.Page.goto(page, apply_url)
      if response.status == 200 do
        {:ok, page}
      else
        {:error, "Failed to navigate to application form: #{response}"}
      end
    end
  end

  defp extract_form_questions(page) do
    # Extract standard form fields (excluding EEO section)
    standard_questions = extract_standard_fields(page)

    # Extract custom question cards
    custom_questions = extract_custom_questions(page)

    # Extract multi-select fields (like pronouns)
    multi_select_questions = extract_multi_select_fields(page)

    all_questions = standard_questions ++ custom_questions ++ multi_select_questions
    {:ok, all_questions}
  end

  defp extract_standard_fields(page) do
    # Target standard form fields, excluding EEO section
    standard_selectors = [
      "input[type='text']:not([id*='eeo']):not([name*='eeo'])",
      "input[type='email']:not([id*='eeo']):not([name*='eeo'])",
      "input[type='tel']:not([id*='eeo']):not([name*='eeo'])",
      "input[type='phone']:not([id*='eeo']):not([name*='eeo'])",
      "textarea:not([id*='eeo']):not([name*='eeo'])",
      "select:not([id*='eeo']):not([name*='eeo'])"
    ]

    Enum.flat_map(standard_selectors, fn selector ->
      elements = Playwright.Page.locator(page, selector)
      if Playwright.Locator.count(elements) > 0 do
        Playwright.Locator.all(elements)
        |> Enum.map(fn element ->
          extract_field_info(page, element)
        end)
        |> Enum.filter(& &1 != nil)
      else
        []
      end
    end)
  end

  defp extract_custom_questions(page) do
    # Extract custom question cards from hidden JSON data
    cards_selector = "input[type='hidden'][name*='cards']"
    cards_elements = Playwright.Page.locator(page, cards_selector)

    if Playwright.Locator.count(cards_elements) > 0 do
      Playwright.Locator.all(cards_elements)
      |> Enum.flat_map(fn element ->
        parse_card_data(page, element)
      end)
    else
      []
    end
  end

  defp parse_card_data(page, element) do
    try do
      name = Playwright.Locator.get_attribute(element, "name")
      value = Playwright.Locator.get_attribute(element, "value")

      case JSON.decode(value) do
        {:ok, card_data} ->
          fields = Map.get(card_data, "fields", [])
          card_id = extract_card_id(name)

          Enum.map(fields, fn field ->
            convert_card_field_to_question(field, card_id)
          end)
        {:error, _} ->
          []
      end
    rescue
      _ -> []
    end
  end

  defp extract_card_id(name) do
    # Extract card ID from name like "cards[527ef845-6719-41a2-ade6-ebe19c7a3e91][baseTemplate]"
    case Regex.run(~r/cards\[([^\]]+)\]/, name) do
      [_, id] -> id
      _ -> ""
    end
  end

  defp convert_card_field_to_question(field, card_id) do
    field_type = Map.get(field, "type", "text")
    field_id = Map.get(field, "id", "")
    question_text = Map.get(field, "text", "")
    required = Map.get(field, "required", false)
    options = extract_field_options(field)

    %{
      id: "cards[#{card_id}][field0]",
      label: question_text,
      type: convert_field_type(field_type),
      required: required,
      max_length: nil,
      options: options
    }
  end

  defp extract_field_options(field) do
    case Map.get(field, "options") do
      nil -> []
      options when is_list(options) ->
        Enum.map(options, fn option ->
          Map.get(option, "text", "")
        end)
      _ -> []
    end
  end

  defp convert_field_type("multiple-choice"), do: "radio"
  defp convert_field_type("text"), do: "text"
  defp convert_field_type("textarea"), do: "textarea"
  defp convert_field_type(_), do: "text"

  defp extract_multi_select_fields(page) do
    # Handle multi-select checkbox groups like pronouns
    multi_select_groups = []

    # Check for pronouns field
    pronouns_selector = "input[type='checkbox'][name='pronouns']"
    pronouns_elements = Playwright.Page.locator(page, pronouns_selector)

    if Playwright.Locator.count(pronouns_elements) > 0 do
      options = Playwright.Locator.all(pronouns_elements)
      |> Enum.map(fn element ->
        Playwright.Locator.get_attribute(element, "value")
      end)
      |> Enum.filter(& &1 != nil)

      pronouns_question = %{
        id: "pronouns",
        label: "Pronouns",
        type: "checkbox",
        required: false,
        max_length: nil,
        options: options
      }

      multi_select_groups ++ [pronouns_question]
    else
      multi_select_groups
    end
  end

  defp extract_field_info(page, element) do
    id = Playwright.Locator.get_attribute(element, "id")
    name = Playwright.Locator.get_attribute(element, "name")
    type = get_field_type(element)

    # Skip captcha, hidden, and EEO fields
    if captcha_field?(id, name) || eeo_field?(id, name) || hidden_field?(element) do
      nil
    else
      required = is_field_required(element)
      max_length = get_max_length(element)
      label = get_field_label(page, element)
      options = get_field_options(element)

      %{
        id: id || name || "",
        label: label || "",
        type: type,
        required: required || false,
        max_length: max_length,
        options: options
      }
    end
  end

  defp get_field_type(element) do
    element_type = Playwright.Locator.get_attribute(element, "type")
    tag_name = Playwright.Locator.evaluate(element, "el => el.tagName.toLowerCase()")

    case {tag_name, element_type} do
      {"textarea", _} -> "textarea"
      {"select", _} -> "select"
      {"input", "email"} -> "email"
      {"input", "tel"} -> "tel"
      {"input", "phone"} -> "tel"
      {"input", "text"} -> "text"
      {"input", "hidden"} -> "hidden"
      {"input", "radio"} -> "radio"
      {"input", "checkbox"} -> "checkbox"
      _ -> "text"
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

  defp get_field_label(page, element) do
    # Try to find label by for attribute
    id = Playwright.Locator.get_attribute(element, "id")
    if id do
      label_selector = "label[for='#{id}']"
      label_locator = Playwright.Page.locator(page, label_selector)
      if Playwright.Locator.count(label_locator) > 0 do
        label_text = Playwright.Locator.inner_text(label_locator)
        clean_label(label_text)
      else
        find_ancestor_label(page, element)
      end
    else
      find_ancestor_label(page, element)
    end
  end

  defp find_ancestor_label(page, element) do
    # Try to find label by looking at parent elements
    try do
      parent_label = Playwright.Locator.evaluate(element, """
        (el) => {
          let current = el.closest('label');
          if (current) {
            return current.textContent.trim();
          }

          // Look for .application-label in parent
          let parent = el.closest('.application-question');
          if (parent) {
            let labelEl = parent.querySelector('.application-label');
            if (labelEl) {
              return labelEl.textContent.trim();
            }
          }

          return '';
        }
      """)

      clean_label(parent_label)
    rescue
      _ -> ""
    end
  end

  defp clean_label(label) do
    label
    |> String.trim()
    |> String.replace(~r/\s*✱\s*$/, "")  # Remove required asterisk
    |> String.replace(~r/\s+/, " ")       # Normalize whitespace
  end

  defp get_field_options(element) do
    tag_name = Playwright.Locator.evaluate(element, "el => el.tagName.toLowerCase()")

    case tag_name do
      "select" ->
        try do
          options = Playwright.Locator.locator(element, "option")
          if Playwright.Locator.count(options) > 0 do
            Playwright.Locator.all(options)
            |> Enum.map(fn option ->
              text = Playwright.Locator.inner_text(option)
              if text && text != "" && text != "Select ..." do
                text
              else
                nil
              end
            end)
            |> Enum.filter(& &1 != nil)
          else
            []
          end
        rescue
          _ -> []
        end
      _ -> []
    end
  end

  defp captcha_field?(id, name) do
    [id, name]
    |> Enum.any?(fn field ->
      field && String.contains?(String.downcase(field), "captcha")
    end)
  end

  defp eeo_field?(id, name) do
    [id, name]
    |> Enum.any?(fn field ->
      field && String.contains?(String.downcase(field), "eeo")
    end)
  end

  defp hidden_field?(element) do
    type = Playwright.Locator.get_attribute(element, "type")
    type == "hidden"
  end
end
