defmodule CoverLetterGenerator do
  @moduledoc """
  Module for generating cover letters using Claude LLM API.
  """

  @api_url "https://api.anthropic.com/v1/messages"

  def generate(resume, job_description) do
    system_prompt = File.read!("prompts/cover_letter.txt")
    
    user_prompt = """
    Resume:
    #{resume}

    Job Description:
    #{job_description}
    """

    payload = %{
      model: "claude-sonnet-4-20250514",
      max_tokens: 3000,
      system: system_prompt,
      messages: [
        %{
          role: "user",
          content: user_prompt
        }
      ]
    }

    case Req.post(@api_url,
           json: payload,
           headers: [
             {"x-api-key", get_api_key()},
             {"anthropic-version", "2023-06-01"}
           ],
           receive_timeout: 600_000
         ) do
      {:ok, %Req.Response{status: 200, body: %{"content" => [%{"text" => text}]}}} ->
        extract_cover_letter(text)
      {:ok, %Req.Response{status: status_code, body: body}} ->
        {:error, "API request failed with status #{status_code}: #{inspect(body)}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
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

  defp get_api_key do
    System.get_env("ANTHROPIC_API_KEY") || 
      raise "ANTHROPIC_API_KEY environment variable not set"
  end
end