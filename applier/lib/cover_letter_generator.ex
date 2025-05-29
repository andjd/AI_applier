defmodule CoverLetterGenerator do
  @moduledoc """
  Module for generating cover letters using Claude LLM API.
  """

  def generate(resume, job_description) do
    system_prompt = File.read!("prompts/cover_letter.txt")

    user_prompt = """
    Resume:
    #{resume}

    Job Description:
    #{job_description}
    """

    options = %{system: system_prompt}

    case Helpers.LLM.ask(user_prompt, options) do
      {:ok, text} ->
        extract_cover_letter(text)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_cover_letter(text) do
    case Regex.run(~r/<\s*cover\s+letter\s*>\s*\n?(.*)/ims, text) do
      [_, cover_letter] ->
        trimmed = cover_letter |> String.trim() |> Kernel.<>("\n")
        {:ok, trimmed}
      nil ->
        require Logger
        Logger.error("API response missing <Cover Letter> tag: #{text}")
        {:error, text}
    end
  end

end
