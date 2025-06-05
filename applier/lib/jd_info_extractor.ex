defmodule JDInfoExtractor do
  @moduledoc """
  Module for extracting job description information from web pages using Playwright.
  """

  def extract_text_from_url(url) do
    case Playwright.launch(:chromium, %{headless: true}) do
      {:ok, browser} ->
        try do
          extract_with_playwright(browser, url)
        after
          Playwright.Browser.close(browser)
        end

      {:error, reason} ->
        {:error, "Failed to start Playwright: #{inspect(reason)}"}
    end
  end

  defp extract_with_playwright(browser, url) do
    page = Playwright.Browser.new_page(browser)
    try do
      Playwright.Page.goto(page, url)
      # Playwright.Page.wait_for_load_state(page, "networkidle")
      Process.sleep(2000)

      with {:ok, text} <- extract_visible_text(page),
           {:ok, questions} <- extract_questions(page)
      do
        {:ok, text, questions}
      else
        {:error, reason} -> {:error, reason}
      end
    after
      Playwright.Page.close(page)
    end
  end

  defp extract_visible_text(page) do
    # Extract visible text from body
    cleaned_text = Playwright.Page.locator(page, "body")
      |> Playwright.Locator.inner_text()
      |> String.trim()
    {:ok, cleaned_text}
  end

  defp extract_questions(page) do
    input_selectors = [
      "input"
    ]

    questions = Enum.flat_map(input_selectors, fn selector ->
      selector = Playwright.Page.locator(page, selector)
      IO.inspect(selector)
      elements = Playwright.Locator.all(selector)

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

    # Skip textarea fields with captcha in name or id
    if captcha_field?(id, name) do
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
    IO.inspect(element)
    id = Playwright.Locator.get_attribute(element, "id")
    IO.inspect(id)
    if id && String.length(id) > 0 do
      label_text = Playwright.Page.locator(page, "label[for='#{id}']") |> Playwright.Locator.inner_text()
      if label_text && String.length(label_text) > 0 do
        String.trim(label_text)
      else
        get_placeholder_or_name_as_label(element)
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

end
