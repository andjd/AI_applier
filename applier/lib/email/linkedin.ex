defmodule Email.Linkedin do
  @moduledoc """
  Handler for LinkedIn job alert emails
  """

  require Logger

  def handle(email_data) do
    IO.puts("🔗 Processing LinkedIn job alert email")
    IO.puts("  From: #{email_data.from}")
    IO.puts("  Subject: #{email_data.subject}")

    with {:ok, jobs} <- extract_jobs(email_data.body) do
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

  defp extract_jobs(plain_text) do
    # The plain text is already extracted by Yugo and decoded
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
