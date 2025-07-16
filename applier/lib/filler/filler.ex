defmodule Filler do
  @doc """
  Fills a form with the provided responses, automatically detecting whether to use
  Greenhouse-specific, JazzHR-specific, or generic form filling based on the page content.

  ## Parameters
  - page: Playwright page object
  - responses: List of maps with "id", "label", and "response" keys
  - short_id: Short ID for the application to fetch resume/cover letter files

  ## Returns
  {:ok, :form_filled} on success
  {:error, reason} on failure
  """
  def fill_form(page, responses, short_id) do
    cond do
      Helpers.FormDetector.is_greenhouse_form?(page) ->
        IO.puts("Detected Greenhouse form, using Greenhouse filler")
        Filler.Greenhouse.fill_form(page, responses, short_id)
      
      Helpers.FormDetector.is_jazzhr_form?(page) ->
        IO.puts("Detected JazzHR form, using JazzHR filler")
        Filler.JazzHR.fill_form(page, responses, short_id)
      
      Helpers.FormDetector.is_lever_form?(page) ->
        IO.puts("Detected Lever form, using Lever filler")
        Filler.Lever.fill_form(page, responses, short_id)
      
      Helpers.FormDetector.is_ashbyhq_form?(page) ->
        IO.puts("Detected AshbyHQ form, using AshbyHQ filler")
        Filler.AshbyHQ.fill_form(page, responses, short_id)
      
      true ->
        IO.puts("Using Generic filler")
        Filler.Generic.fill_form(page, responses, short_id)
    end
  end
end