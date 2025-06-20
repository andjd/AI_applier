defmodule Helpers.LLM do
  @moduledoc """
  Helper module for making requests to the Anthropic Claude API.
  """

  @api_url "https://api.anthropic.com/v1/messages"
  @cache_dir ".cache"

  def ask(prompt, application_id \\ nil, options \\ %{}) do
    default_options = %{
      model: "claude-sonnet-4-20250514",
      max_tokens: 3000,
      system: nil,
      receive_timeout: 600_000
    }

    merged_options = Map.merge(default_options, options)
    
    case application_id do
      nil ->
        make_api_request_without_cache(prompt, merged_options)
      app_id ->
        case read_cache(app_id) do
          {:ok, cached_result} ->
            {:ok, cached_result}
          :miss ->
            make_api_request_and_cache(prompt, merged_options, app_id)
        end
    end
  end

  defp make_api_request_and_cache(prompt, options, application_id) do
    payload = build_payload(prompt, options)

    case Req.post(@api_url,
             json: payload,
             headers: [
               {"x-api-key", get_api_key()},
               {"anthropic-version", "2023-06-01"}
             ],
             receive_timeout: options.receive_timeout
           ) do
      {:ok, %Req.Response{status: 200, body: %{"content" => [%{"text" => text}]}}} ->
        write_cache(application_id, text)
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
    case JSON.decode(llm_response) do
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
        case JSON.decode(json_content) do
          {:ok, json} -> {:ok, json}
          {:error, _} -> {:error, "Failed to decode JSON from code block. Full LLM response: #{text}"}
        end

      # Try to match ``` ... ``` pattern (generic code block)
      code_match = Regex.run(~r/```\s*\n(.*?)\n```/s, text) ->
        [_, code_content] = code_match
        case JSON.decode(code_content) do
          {:ok, json} -> {:ok, json}
          {:error, _} -> {:error, "Failed to decode JSON from code block. Full LLM response: #{text}"}
        end

      true ->
        {:error, "No valid JSON found in LLM response. Full LLM response: #{text}"}
    end
  end

  defp make_api_request_without_cache(prompt, options) do
    payload = build_payload(prompt, options)

    case Req.post(@api_url,
             json: payload,
             headers: [
               {"x-api-key", get_api_key()},
               {"anthropic-version", "2023-06-01"}
             ],
             receive_timeout: options.receive_timeout
           ) do
      {:ok, %Req.Response{status: 200, body: %{"content" => [%{"text" => text}]}}} ->
        {:ok, text}
      {:ok, %Req.Response{status: status_code, body: body}} ->
        {:error, "API request failed with status #{status_code}: #{inspect(body)}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp ensure_cache_dir do
    case File.mkdir_p(@cache_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to create cache directory: #{inspect(reason)}"}
    end
  end

  defp get_cache_file_path(application_id) do
    Path.join(@cache_dir, "llm_cache_#{application_id}.json")
  end

  defp read_cache(application_id) do
    cache_file = get_cache_file_path(application_id)

    case File.read(cache_file) do
      {:ok, content} ->
        case JSON.decode(content) do
          {:ok, %{"result" => result}} -> {:ok, result}
          {:error, _} -> :miss
        end
      {:error, _} -> :miss
    end
  end

  defp write_cache(application_id, result) do
    with :ok <- ensure_cache_dir(),
         cache_data = %{
           timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
           application_id: application_id,
           result: result
         },
         json <- JSON.encode!(cache_data),
         cache_file = get_cache_file_path(application_id),
         :ok <- File.write(cache_file, json) do
      :ok
    else
      {:error, reason} ->
        IO.puts("Failed to write cache: #{inspect(reason)}")
        :error
    end
  end
end
