defmodule Filler do
  @doc """
  Fills a form with the provided responses, automatically detecting whether to use
  Greenhouse-specific or generic form filling based on the page content.

  ## Parameters
  - page: Playwright page object
  - responses: List of maps with "id", "label", and "response" keys
  - resume_text: Resume content as text (optional)
  - cover_letter_text: Cover letter content as text (optional)

  ## Returns
  {:ok, :form_filled} on success
  {:error, reason} on failure
  """
  def fill_form(page, responses, resume_text \\ nil, cover_letter_text \\ nil) do
    if Helpers.FormDetector.is_greenhouse_form?(page) do
      IO.puts("Detected Greenhouse form, using Greenhouse filler")
      Filler.Greenhouse.fill_form(page, responses, resume_text, cover_letter_text)
    else
      IO.puts("Using Generic filler")
      Filler.Generic.fill_form(page, responses, resume_text, cover_letter_text)
    end
  end
end