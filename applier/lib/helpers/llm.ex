defmodule Helpers.LLM do
  @moduledoc """
  Helper module for making requests to the Anthropic Claude API.
  """

  @api_url "https://api.anthropic.com/v1/messages"

  def ask(prompt, options \\ %{}) do
    default_options = %{
      model: "claude-sonnet-4-20250514",
      max_tokens: 3000,
      system: nil,
      receive_timeout: 600_000
    }

    merged_options = Map.merge(default_options, options)

    payload = build_payload(prompt, merged_options)

    case Req.post(@api_url,
           json: payload,
           headers: [
             {"x-api-key", get_api_key()},
             {"anthropic-version", "2023-06-01"}
           ],
           receive_timeout: merged_options.receive_timeout
         ) do
      {:ok, %Req.Response{status: 200, body: %{"content" => [%{"text" => text}]}}} ->
        {:ok, text}
      {:ok, %Req.Response{status: status_code, body: body}} ->
        {:error, "API request failed with status #{status_code}: #{inspect(body)}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp build_payload(prompt, options) do
    base_payload = %{
      model: options.model,
      max_tokens: options.max_tokens,
      messages: [
        %{
          role: "user",
          content: prompt
        }
      ]
    }

    case options.system do
      nil -> base_payload
      system_prompt -> Map.put(base_payload, :system, system_prompt)
    end
  end

  defp get_api_key do
    System.get_env("ANTHROPIC_API_KEY") ||
      raise "ANTHROPIC_API_KEY environment variable not set"
  end

  def decode_json(llm_response) do
    case Jason.decode(llm_response) do
      {:ok, json} ->
        {:ok, json}
      {:error, _} ->
        try_extract_from_code_block(llm_response)
    end
  end

  defp try_extract_from_code_block(text) do
    cond do
      # Try to match ```json ... ``` pattern
      json_match = Regex.run(~r/```json\s*\n(.*?)\n```/s, text) ->
        [_, json_content] = json_match
        case Jason.decode(json_content) do
          {:ok, json} -> {:ok, json}
          {:error, _} -> {:error, "Failed to decode JSON from code block. Full LLM response: #{text}"}
        end

      # Try to match ``` ... ``` pattern (generic code block)
      code_match = Regex.run(~r/```\s*\n(.*?)\n```/s, text) ->
        [_, code_content] = code_match
        case Jason.decode(code_content) do
          {:ok, json} -> {:ok, json}
          {:error, _} -> {:error, "Failed to decode JSON from code block. Full LLM response: #{text}"}
        end

      true ->
        {:error, "No valid JSON found in LLM response. Full LLM response: #{text}"}
    end
  end
end
