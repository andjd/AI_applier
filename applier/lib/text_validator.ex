defmodule TextValidator do
  @moduledoc """
  Module for validating text using LLM-based prompt injection screening.
  """

  def validate_text(text, application_id \\ nil) do
    system_prompt = File.read!("prompts/prompt_injection_screen.txt")
    user_prompt = "%%%Commencer%%%\n#{text}"

    case Helpers.LLM.ask(user_prompt, application_id, %{system: system_prompt}) do
      {:ok, response} ->
        case classify_response(response) do
          {:error, message} -> {:error, message}
          classification when is_atom(classification) -> {classification, text}
        end
      {:error, reason} ->
        {:error, "LLM request failed: #{reason}"}
    end
  end

  defp classify_response(response) do
    last_word =
      response
      |> String.split()
      |> List.last()
      |> normalize_word()

    case last_word do
      "sure" -> :safe
      "dangereuse" -> :dangerous
      "manuelle" -> :manual
      _ -> {:error, "Unexpected response format: #{response}"}
    end
  end

  defp normalize_word(word) when is_binary(word) do
    word
    |> String.downcase()
    |> String.normalize(:nfkd)
    |> String.replace(~r/[^a-z]/, "")
  end

  defp normalize_word(_), do: ""
end
