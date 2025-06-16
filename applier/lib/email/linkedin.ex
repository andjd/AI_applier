defmodule Email.Linkedin do
  @moduledoc """
  Handler for LinkedIn job alert emails
  """

  require Logger
  require Mail

  def handle(email_data) do
    IO.puts("🔗 Processing LinkedIn job alert email")
    IO.puts("  From: #{email_data.from}")
    IO.puts("  Subject: #{email_data.subject}")

    with {:ok, plain_text} <- extract_plain_text(email_data.body),
         {:ok, jobs} <- extract_jobs(plain_text) do
      IO.puts("  📋 Found #{length(jobs)} job listings")

      jobs
      |> Enum.each(fn job ->
        IO.puts("  • #{job.title} at #{job.company}")
        # TODO: Create task for each job
      end)

      IO.puts("  ✅ LinkedIn email processing completed")
      {:ok, jobs}
    else
      {:error, reason} ->
        IO.puts("  ❌ Error processing LinkedIn email: #{reason}")
        {:error, reason}
    end
  end

  defp extract_plain_text(email_body) do
    with {:ok, text_part} <- find_text_plain_part(email_body),
         {:ok, decoded_text} <- decode_quoted_printable(text_part) do
      {:ok, decoded_text}
    else
      error -> error
    end
  end

  defp find_text_plain_part(email_body) do
    with {:ok, boundary} <- extract_boundary(email_body),
         {:ok, text_part} <- extract_text_part_with_boundary(email_body, boundary) do
      {:ok, text_part}
    else
      error -> error
    end
  end

  defp extract_boundary(email_body) do
    case Regex.run(~r/Content-Type: multipart\/alternative;\s*boundary="([^"]+)"/i, email_body) do
      [_, boundary] -> {:ok, boundary}
      nil -> {:error, "Could not find multipart boundary"}
    end
  end

  defp extract_text_part_with_boundary(email_body, boundary) do
    boundary_marker = "--" <> boundary
    
    case String.split(email_body, boundary_marker) do
      [_header | parts] ->
        case find_text_plain_in_parts(parts) do
          {:ok, text_content} -> {:ok, text_content}
          error -> error
        end
      _ -> {:error, "Could not split email by boundary"}
    end
  end

  defp find_text_plain_in_parts(parts) do
    text_part = 
      parts
      |> Enum.find(fn part ->
        String.contains?(part, "Content-Type: text/plain")
      end)
    
    case text_part do
      nil -> {:error, "Could not find text/plain part"}
      part -> 
        case Regex.run(~r/Content-Type: text\/plain[^\r\n]*\r?\n(?:Content-Transfer-Encoding: quoted-printable\r?\n)?\r?\n(.*)/s, part) do
          [_, content] -> {:ok, String.trim(content)}
          nil -> {:error, "Could not extract content from text/plain part"}
        end
    end
  end

  defp decode_quoted_printable(text) do
    try do
      decoded = Mail.QuotedPrintable.decode(text)
      {:ok, to_string(decoded)}
    rescue
      _ -> {:error, "Failed to decode quoted-printable content"}
    end
  end

  defp extract_jobs(plain_text) do
    job_pattern = ~r/^([^\n\r]+)\n([^\n\r]+)\n[^\n\r]*\nView job: (https:\/\/www\.linkedin\.com[^\s]+)/m

    matches = Regex.scan(job_pattern, plain_text)

    jobs =
      matches
      |> Enum.map(fn [_, title, company, url] ->
        %{
          title: String.trim(title),
          company: String.trim(company),
          url: clean_url(url)
        }
      end)

    {:ok, jobs}
  end

  defp clean_url(url) do
    url
    |> String.split("?")
    |> List.first()
  end
end
