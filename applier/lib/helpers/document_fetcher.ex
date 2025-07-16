defmodule Helpers.DocumentFetcher do
  require Logger

  @doc """
  Fetches resume content in the specified format.

  ## Parameters
  - short_id: The short ID for the application (e.g., "0HTQtja2")
  - format: The format to fetch (:pdf or :txt)

  ## Returns
  - {:ok, content} - File content as binary for :pdf or string for :txt
  - {:ok, file_path} - File path for :pdf format when used for file uploads
  - {:error, reason} - Error if file not found or invalid format

  ## Examples
      iex> Helpers.DocumentFetcher.get_resume("0HTQtja2", :txt)
      {:ok, "John Doe\\nSoftware Engineer\\n..."}

      iex> Helpers.DocumentFetcher.get_resume("0HTQtja2", :pdf)
      {:ok, "/path/to/artifacts/Andrew_DeFranco_0HTQtja2.pdf"}
  """
  def get_resume(short_id, format) when format in [:pdf, :txt] do
    get_document("resume", short_id, format)
  end

  @doc """
  Fetches cover letter content in the specified format.

  ## Parameters
  - short_id: The short ID for the application (e.g., "0HTQtja2")
  - format: The format to fetch (:pdf or :txt)

  ## Returns
  - {:ok, content} - File content as binary for :pdf or string for :txt
  - {:ok, file_path} - File path for :pdf format when used for file uploads
  - {:error, reason} - Error if file not found or invalid format

  ## Examples
      iex> Helpers.DocumentFetcher.get_cover_letter("0HTQtja2", :txt)
      {:ok, "Dear Hiring Manager,\\n\\nI am writing to express..."}

      iex> Helpers.DocumentFetcher.get_cover_letter("0HTQtja2", :pdf)
      {:ok, "/path/to/artifacts/Andrew_DeFranco_0HTQtja2.pdf"}
  """
  def get_cover_letter(short_id, format) when format in [:pdf, :txt] do
    get_document("cover_letter", short_id, format)
  end

  @doc """
  Gets the file path for a document without reading its content.
  Useful for file upload operations.

  ## Parameters
  - document_type: "resume" or "cover_letter"
  - short_id: The short ID for the application
  - format: The format (:pdf or :txt)

  ## Returns
  - {:ok, file_path} - Absolute path to the file
  - {:error, reason} - Error if file not found
  """
  def get_document_path(document_type, short_id, format) when format in [:pdf, :txt] do
    file_path = build_file_path(short_id, format)
    
    if File.exists?(file_path) do
      {:ok, Path.expand(file_path)}
    else
      {:error, "#{document_type} file not found: #{file_path}"}
    end
  end

  # Private helper functions

  defp get_document(document_type, short_id, format) do
    file_path = build_file_path(short_id, format)
    
    case File.exists?(file_path) do
      true ->
        case format do
          :txt ->
            case File.read(file_path) do
              {:ok, content} -> {:ok, content}
              {:error, reason} -> {:error, "Failed to read #{document_type} text: #{reason}"}
            end
          :pdf ->
            # For PDF files, return the absolute path for file uploads
            {:ok, Path.expand(file_path)}
        end
      false ->
        Logger.warning("#{document_type} file not found: #{file_path}")
        {:error, "#{document_type} file not found: #{file_path}"}
    end
  end

  defp build_file_path(short_id, format) do
    extension = case format do
      :txt -> "txt"
      :pdf -> "pdf"
    end
    
    "artifacts/Andrew_DeFranco_#{short_id}.#{extension}"
  end
end