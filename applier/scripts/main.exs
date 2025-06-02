
# Main script for automated cover letter generation from job posting URLs

# Get URL from command line arguments
url = case System.argv() do
  [url | _] -> url
  [] ->
    IO.puts("Usage: elixir scripts/main.exs <job_posting_url>")
    System.halt(1)
end

Dotenv.load()
Mix.Task.run("loadconfig")

# Generate short identifier from URL
url_hash = :crypto.hash(:sha256, url) |> Base.encode16() |> String.downcase()
# Take first 8 characters and convert to integers for sqids
hash_numbers = url_hash
  |> String.slice(0, 4)
  |> String.to_charlist()
  |> Enum.map(&(&1))

sqids = Sqids.new!()
short_id = Sqids.encode!(sqids, hash_numbers)

resume_data = File.read!("assets/resume.yaml")
filename = "assets/Andrew_DeFranco_#{short_id}"
pdf_filename = "#{filename}.pdf"
txt_filename = "#{filename}.txt"

IO.puts("Starting cover letter generation process for: #{url}")
IO.puts("Job ID: #{short_id}")

with {:ok, job_description} <-
      (IO.puts("Step 1: Extracting job description from URL...");
      JdInfoExtractor.extract_text_from_url(url)),
     _ <- IO.puts("✓ Successfully extracted job description"),
     {:safe, _} <-
        (IO.puts("Step 2: Validating extracted text for safety...");
        TextValidator.validate_text(job_description)),
     _ <- IO.puts("✓ Text validation passed - content is safe"),
     {:ok, cover_letter} <-
        (IO.puts("Step 3: Generating cover letter...");
        CoverLetter.generate(resume_data, job_description)),
     _ <- IO.puts("✓ Successfully generated cover letter"),
     {:ok, pdf} <-
        (IO.puts("Step 4: Rendering cover letter to PDF...");
        CoverLetter.render(cover_letter)),
     :ok <- File.write(pdf_filename, pdf),
     _ <- IO.puts("✓ Cover letter PDF saved as #{pdf_filename}"),
     {:ok, text} <- (IO.puts("Step 5: Saving text version..."); CoverLetter.to_text(cover_letter)),
     :ok <- File.write(txt_filename, text),
     _ <- IO.puts("✓ Cover letter text saved as #{txt_filename}") do
  IO.puts("Process completed successfully!")
else
  {:error, reason} ->
    IO.puts("✗ Failed to extract job description: #{reason}")
    System.halt(1)

  {:dangerous, _} ->
    IO.puts("✗ Text validation failed - content contains potentially dangerous content")
    System.halt(1)

  {:manual, _} ->
    IO.puts("⚠ Text validation requires manual review - please check the content manually")
    System.halt(1)

  error ->
    IO.puts("✗ Unexpected error: #{inspect(error)}")
    System.halt(1)
end
