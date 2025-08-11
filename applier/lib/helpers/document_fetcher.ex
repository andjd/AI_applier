defmodule Helpers.DocumentFetcher do
  require Logger

  def get_resume(_short_id, format) when format in [:pdf, :yaml, :txt] do
    filepath = "assets/resume.#{Atom.to_string(format)}"
    get_document(filepath, format)
  end

  def get_cover_letter(short_id, format) when format in [:pdf, :txt] do
    filepath = "artifacts/Andrew_DeFranco_#{short_id}.#{Atom.to_string(format)}"
    get_document(filepath, format)
  end

  defp get_document(file_path, format) do
    case File.exists?(file_path) do
      true ->
        case format do
          :txt ->
            case File.read(file_path) do
              {:ok, content} -> {:ok, content}
              {:error, reason} -> {:error, "Failed to read #{file_path} text: #{inspect(reason)}"}
            end
          _ ->
            {:ok, Path.expand(file_path)}
        end
      false ->
        Logger.warning("File not found: #{file_path}")
        {:error, "File not found: #{file_path}"}
    end
  end

end
