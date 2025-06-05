defmodule Scraper.Greenhouse do
  def extract_questions(page) do
    # Target Greenhouse-specific form field wrappers (avoiding duplicates, custom selects, and demographic fields)
    greenhouse_selector = ".text-input-wrapper input:not([role='combobox']), .input-wrapper input:not([role='combobox'])"

    # Handle regular form elements
    selector = Playwright.Page.locator(page, greenhouse_selector)
    IO.inspect(selector)
    elements = Playwright.Locator.all(selector)

    IO.puts("element length: #{length(elements)}")
    regular_questions = Enum.map(elements, fn element ->
      # Skip fields inside demographic section
      if is_demographic_field?(page, element) do
        nil
      else
        extract_field_info(page, element)
      end
    end)
    |> Enum.filter(& &1 != nil)

    # Handle Greenhouse custom select elements (also filtering demographics)
    greenhouse_select_questions = extract_greenhouse_selects(page)

    all_questions = regular_questions ++ greenhouse_select_questions
    {:ok, all_questions}
  end

  defp extract_field_info(page, element) do
    id = Playwright.Locator.get_attribute(element, "id")
    name = Playwright.Locator.get_attribute(element, "name")
    type = get_field_type(element)
    IO.puts(type)

    # Skip fields with captcha in name or id
    if captcha_field?(id, name) do
      nil
    else
      required = is_field_required(element)
      max_length = get_max_length(element)
      label = get_field_label(page, element)

      %{
        id: id || name || "",
        label: label || "",
        type: type,
        required: required || false,
        max_length: max_length,
      }
    end
  end

  defp get_field_type(element) do
    tag_name = Playwright.Locator.evaluate(element, "el => el.nodeName")
    if tag_name do
        tag = String.downcase(tag_name)
        case tag do
          "select" -> "select"
          "textarea" -> "textarea"
          "input" -> Playwright.Locator.get_attribute(element, "type") || "text"
          _ -> nil
        end
      end
  end

  defp is_field_required(element) do
    # Check for Greenhouse-specific aria-required attribute first
    case Playwright.Locator.get_attribute(element, "aria-required") do
      "true" -> true
      _ ->
        # Fallback to standard required attribute
        case Playwright.Locator.get_attribute(element, "required") do
          "" -> true
          "required" -> true
          nil -> false
          _ -> false
        end
    end
  end

  defp get_max_length(element) do
    case Playwright.Locator.get_attribute(element, "maxlength") do
      max_length when max_length != nil ->
        case Integer.parse(max_length) do
          {int_val, _} -> int_val
          _ -> nil
        end
      _ -> nil
    end
  end

  defp get_field_label(page, element) do
    IO.inspect(element)
    id = Playwright.Locator.get_attribute(element, "id")
    IO.inspect(id)

    # Try Greenhouse-specific label pattern first
    label_text = if id && String.length(id) > 0 do
      # Look for label with ID pattern like "first_name-label"
      greenhouse_label = Playwright.Page.locator(page, "label[id='#{id}-label']") |> Playwright.Locator.inner_text()
      if greenhouse_label && String.length(greenhouse_label) > 0 do
        # Remove asterisk and trim
        greenhouse_label |> String.replace("*", "") |> String.trim()
      else
        nil
      end
    else
      nil
    end

    if label_text do
      label_text
    else
      get_placeholder_or_name_as_label(element)
    end
  end

  defp get_placeholder_or_name_as_label(element) do
    case Playwright.Locator.get_attribute(element, "placeholder") do
      placeholder when placeholder != nil -> placeholder
      _ ->
        case Playwright.Locator.get_attribute(element, "name") do
          name when name != nil -> name
          _ -> ""
        end
    end
  end

  defp get_field_options(page, element, type) do
    cond do
      type == "select" ->
        options = Playwright.Locator.locator(element, "option") |> Playwright.Locator.all()
        option_values = Enum.map(options, fn option ->
          text = Playwright.Locator.inner_text(option)
          if text, do: String.trim(text), else: ""
        end)
        option_values

      type == "radio" ->
        name = Playwright.Locator.get_attribute(element, "name")
        if name && String.length(name) > 0 do
          radio_elements = Playwright.Page.locator(page, "input[name='#{name}']") |> Playwright.Locator.all()
          radio_values = Enum.map(radio_elements, fn radio ->
            value = Playwright.Locator.get_attribute(radio, "value")
            if value, do: value, else: ""
          end)
          radio_values
        else
          []
        end

      true -> []
    end
  end

  defp captcha_field?(id, name) do
    captcha_in_string?(id) or captcha_in_string?(name)
  end

  defp captcha_in_string?(nil), do: false
  defp captcha_in_string?(str) when is_binary(str) do
    IO.puts("checking for captcha: " <> str)
    String.downcase(str) |> String.contains?("captcha")
  end

  defp extract_greenhouse_selects(page) do
    # Find Greenhouse custom select elements
    select_containers = Playwright.Page.locator(page, ".select__container") |> Playwright.Locator.all()

    IO.puts("Found #{length(select_containers)} Greenhouse select elements")

    Enum.map(select_containers, fn container ->
      # Skip containers inside demographic section
      if is_demographic_container?(page, container) do
        nil
      else
        extract_greenhouse_select_info(page, container)
      end
    end)
    |> Enum.filter(& &1 != nil)
  end

  defp extract_greenhouse_select_info(page, container) do
    with {:ok, input_element} <- find_select_input(container),
         id <- Playwright.Locator.get_attribute(input_element, "id"),
         label <- get_greenhouse_select_label(page, id),
         required <- is_greenhouse_select_required(input_element),
         options <- get_greenhouse_select_options(page, input_element, id)
    do
      %{
        id: id || "",
        label: label || "",
        type: "select",
        required: required || false,
        options: options
      }
    else
      _ -> nil
    end
  end

  defp find_select_input(container) do
    # Look for the input element within the select container
    input = Playwright.Locator.locator(container, "input[role='combobox']")
    case Playwright.Locator.count(input) do
      0 -> {:error, "No input found"}
      _ -> {:ok, input}
    end
  end

  defp get_greenhouse_select_label(page, id) when is_binary(id) do
    # Look for label with ID pattern like "question_31992283002-label"
    label_selector = "label[id='#{id}-label']"
    label = Playwright.Page.locator(page, label_selector)

    case Playwright.Locator.count(label) do
      0 -> nil
      _ ->
        text = Playwright.Locator.inner_text(label)
        if text && String.length(text) > 0 do
          # Remove asterisk and trim
          text |> String.replace("*", "") |> String.trim()
        else
          nil
        end
    end
  end
  defp get_greenhouse_select_label(_, _), do: nil

  defp is_greenhouse_select_required(input_element) do
    case Playwright.Locator.get_attribute(input_element, "aria-required") do
      "true" -> true
      _ -> false
    end
  end

  defp get_greenhouse_select_options(page, input_element, id) do
    # Skip option extraction for location fields
    if is_location_field?(id) do
      IO.puts("Skipping options extraction for location field: #{id}")
      []
    else
      # Click on the select to reveal options
      IO.puts("Clicking select to reveal options...")

      Playwright.Locator.click(input_element)
      Playwright.Page.wait_for_selector(page, ".select__option")
      extract_visible_options(page)
    end
  end

  defp extract_visible_options(page) do
    # Look for the options menu that appears after clicking
    options_selector = ".select__option"
    options = Playwright.Page.locator(page, options_selector) |> Playwright.Locator.all()

    IO.puts("Found #{length(options)} options")

    Enum.map(options, fn option ->
      text = Playwright.Locator.inner_text(option)
      if text && String.length(text) > 0 do
        String.trim(text)
      else
        ""
      end
    end)
    |> Enum.filter(&(&1 != ""))
  end

  defp is_location_field?(id) when is_binary(id) do
    # Check if the field ID indicates it's a location field
    location_patterns = [
      "candidate-location",
      "location"
    ]

    id_lower = String.downcase(id)
    Enum.any?(location_patterns, fn pattern ->
      String.contains?(id_lower, pattern)
    end)
  end
  defp is_location_field?(_), do: false

  defp is_demographic_field?(page, element) do
    # Check if the element is inside the demographic section
    demographic_section = Playwright.Page.locator(page, "#demographic-section")
    case Playwright.Locator.count(demographic_section) do
      0 -> false
      _ ->
        # Check if the element is contained within the demographic section
        element_inside_demo = Playwright.Locator.locator(demographic_section, "*")
        |> Playwright.Locator.all()
        |> Enum.any?(fn demo_element ->
          element_id = Playwright.Locator.get_attribute(element, "id")
          demo_id = Playwright.Locator.get_attribute(demo_element, "id")
          element_id && demo_id && element_id == demo_id
        end)
        element_inside_demo
    end
  end

  defp is_demographic_container?(page, container) do
    # Check if the container is inside the demographic section
    demographic_section = Playwright.Page.locator(page, "#demographic-section")
    case Playwright.Locator.count(demographic_section) do
      0 -> false
      _ ->
        # Check if the container is contained within the demographic section
        containers_inside_demo = Playwright.Locator.locator(demographic_section, ".select__container")
        |> Playwright.Locator.all()
        |> Enum.any?(fn demo_container ->
          # Compare by checking if they're the same element (simplified check)
          container_html = Playwright.Locator.inner_html(container)
          demo_html = Playwright.Locator.inner_html(demo_container)
          container_html == demo_html
        end)
        containers_inside_demo
    end
  end

end
