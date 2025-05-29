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
end
