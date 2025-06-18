defmodule Scraper.Generic do
  def extract_questions(page) do
    input_selectors = [
      "input",
      "textarea",
      "select"
    ]

    questions = Enum.flat_map(input_selectors, fn selector ->
      locator = Playwright.Page.locator(page, selector)
      IO.inspect(locator)
      elements = if Playwright.Locator.count(locator) > 0 do
        Playwright.Locator.all(locator)
      else
        []
      end

      IO.puts("element length: #{length(elements)}")
      Enum.map(elements, fn element ->
        extract_field_info(page, element)
      end)
      |> Enum.filter(& &1 != nil)
    end)

    {:ok, questions}
  end

  defp extract_field_info(page, element) do
    id = Playwright.Locator.get_attribute(element, "id")
    name = Playwright.Locator.get_attribute(element, "name")
    type = get_field_type(element)
    IO.puts(type)

    # Skip fields with captcha in name or id, or hidden input fields
    if captcha_field?(id, name) or Playwright.Locator.get_attribute(element, "type") == "hidden" do
      nil
    else
      required = is_field_required(element)
      max_length = get_max_length(element)
      label = get_field_label(page, element)
      options = get_field_options(page,element, type)

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
    case Playwright.Locator.get_attribute(element, "nodeName") do
      tag_name when is_binary(tag_name) ->
        tag = String.downcase(tag_name)
        IO.inspect(tag_name)
        IO.inspect(tag)
        case tag do
          "select" -> "select"
          "textarea" -> "textarea"
          "input" -> Playwright.Locator.get_attribute(element, "type") || "text"
          _ -> nil
        end
      _ -> nil
    end
  end

  defp is_field_required(element) do
    case Playwright.Locator.get_attribute(element, "required") do
      "" -> true
      "required" -> true
      nil -> false
      _ -> false
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
    id = Playwright.Locator.get_attribute(element, "id")
    IO.inspect(id)
    if id && String.length(id) > 0 do
      label_locator = Playwright.Page.locator(page, "label[for='#{id}']")
      case Playwright.Locator.count(label_locator) do
        0 ->
          get_placeholder_or_name_as_label(element)
        _ ->
          label_text = Playwright.Locator.inner_text(label_locator)
          if label_text && String.length(label_text) > 0 do
            String.trim(label_text)
          else
            get_placeholder_or_name_as_label(element)
          end
      end
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
        option_locator = Playwright.Locator.locator(element, "option")
        options = if Playwright.Locator.count(option_locator) > 0 do
          Playwright.Locator.all(option_locator)
        else
          []
        end
        option_values = Enum.map(options, fn option ->
          text = Playwright.Locator.inner_text(option)
          if text, do: String.trim(text), else: ""
        end)
        option_values

      type == "radio" ->
        name = Playwright.Locator.get_attribute(element, "name")
        if name && String.length(name) > 0 do
          radio_locator = Playwright.Page.locator(page, "input[name='#{name}']")
          radio_elements = if Playwright.Locator.count(radio_locator) > 0 do
            Playwright.Locator.all(radio_locator)
          else
            []
          end
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

end
