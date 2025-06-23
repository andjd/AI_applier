defmodule Filler do
  @doc """
  Fills a form with the provided responses, automatically detecting whether to use
  Greenhouse-specific, JazzHR-specific, or generic form filling based on the page content.

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
    cond do
      Helpers.FormDetector.is_greenhouse_form?(page) ->
        IO.puts("Detected Greenhouse form, using Greenhouse filler")
        Filler.Greenhouse.fill_form(page, responses, resume_text, cover_letter_text)
      
      Helpers.FormDetector.is_jazzhr_form?(page) ->
        IO.puts("Detected JazzHR form, using JazzHR filler")
        Filler.JazzHR.fill_form(page, responses, resume_text, cover_letter_text)
      
      true ->
        IO.puts("Using Generic filler")
        Filler.Generic.fill_form(page, responses, resume_text, cover_letter_text)
    end
  end
end