
# Main script for automated cover letter generation from job posting URLs or direct text
defmodule Main do
  def put_help() do
    IO.puts("Usage: elixir scripts/main.exs <job_posting_url>")
    IO.puts("   OR: echo \"job description text\" | elixir scripts/main.exs")
    System.halt(1)
  end

  def read_stdin() do
    case IO.read(:stdio, :all) do
      :eof ->
        IO.puts("Error: No input provided")
        put_help()
      {:error, reason} ->
        IO.puts("Error reading from stdin: #{reason}")
        System.halt(1)
      input when is_binary(input) ->
        trimmed = String.trim(input)
        if String.length(trimmed) == 0 do
          IO.puts("Error: Empty input provided")
          put_help()
        else
          trimmed
        end
    end
  end

  def parse_input() do
    case System.argv() do
      [] -> {:text, read_stdin()}
      [url | _] -> {:url, url}
    end
  end
  def run do
    {input_source, input_value} = parse_input()
    Mix.Task.run("loadconfig")

    # Generate short identifier from input
    input_hash = :crypto.hash(:sha256, input_value) |> Base.encode16() |> String.downcase()

    hash_numbers = input_hash
      |> String.slice(0, 4)
      |> String.to_charlist()
      |> Enum.map(&(&1))

    sqids = Sqids.new!()
    short_id = Sqids.encode!(sqids, hash_numbers)

    resume_data = File.read!("assets/resume.yaml")
    filename = "artifacts/Andrew_DeFranco_#{short_id}"
    pdf_filename = "#{filename}.pdf"
    txt_filename = "#{filename}.txt"

    case input_source do
      :url -> IO.puts("Starting cover letter generation process for: #{input_value}")
      :text -> IO.puts("Starting cover letter generation process with text from stdin")
    end
    IO.puts("Job ID: #{short_id}")

    with {:ok, job_description} <- (
          case input_source do
            :url ->
              (IO.puts("Step 1: Extracting job description from URL...");
              JdInfoExtractor.extract_text_from_url(input_value))
            :text ->
              (IO.puts("Step 1: Using job description text from stdin...");
              {:ok, input_value})
          end),
        _ <- IO.puts("✓ Successfully obtained job description"),
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
  end
end

Main.run()
