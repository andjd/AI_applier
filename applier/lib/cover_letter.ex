defmodule CoverLetter do
  @moduledoc """
  Module for generating cover letters using Claude LLM API.
  """


  def generate(resume, job_description, application_id \\ nil) do
    system_prompt = File.read!("prompts/cover_letter.txt")

    user_prompt = """
    Resume:
    #{resume}

    Job Description:
    #{job_description}
    """

    options = %{system: system_prompt}

    case Helpers.LLM.ask(user_prompt, application_id, options) do
      {:ok, text} ->
        extract_cover_letter(text)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def render(body) do
    Iona.template([body: body], path: "templates/cover_letter.tex.eex")
     |> Iona.to(:pdf)
  end

  def to_text(body) do
    today = Date.utc_today() |> Date.to_string()
    
    text = """
    #{today}

    Dear Hiring Manager,

    #{body}

    Best,

    Andrew DeFranco
    """
    
    {:ok, text}
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
