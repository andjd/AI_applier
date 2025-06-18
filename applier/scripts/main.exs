
# Main script for automated cover letter generation from job posting URLs or direct text
defmodule Main do
  def put_help() do
    IO.puts("Usage: elixir scripts/main.exs <job_posting_url>")
    IO.puts("   OR: echo \"job description text\" | elixir scripts/main.exs")
    System.halt(1)
  end

  def read_stdin() do
    case IO.read(:stdio, :eof) do
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
    case System.argv() d
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

    resume = File.read!("assets/resume.yaml")
    filename = "artifacts/Andrew_DeFranco_#{short_id}"

    case input_source do
      :url -> IO.puts("Starting cover letter generation process for: #{input_value}")
      :text -> IO.puts("Starting cover letter generation process with text from stdin")
    end
    IO.puts("Job ID: #{short_id}")

    case input_source do
      :url ->
        IO.puts("Step 1: Launching browser and extracting job description from URL...")
        case Helpers.Browser.launch_and_navigate(input_value) do
          {:ok, browser, page} ->
            try do
              process_with_browser(page, resume, filename)
            after
              Helpers.Browser.close_page(page)
              Helpers.Browser.close_browser(browser)
            end
          {:error, reason} ->
            IO.puts("✗ Failed to launch browser: #{reason}")
            System.halt(1)
        end
      :text ->
        IO.puts("Step 1: Using job description text from stdin...")
        process_without_browser(input_value, resume, filename)
    end
  end

  defp process_with_browser(page, resume, filename) do
    with {:ok, job_description, questions} <- JDInfoExtractor.extract_text(page),
        _ <- IO.puts("✓ Successfully obtained job description"),
        {:safe, _} <-
            (IO.puts("Step 2: Validating extracted text for safety...");
            TextValidator.validate_text(job_description <>
              (Enum.map(questions, fn q -> Map.get(q, :label, "") end)
              |> Enum.join("\n")))),
        _ <- IO.puts("✓ Text validation passed - content is safe"),
        {:ok, cover_letter} <-
            (IO.puts("Step 3: Generating cover letter...");
            CoverLetter.generate(resume, job_description)),
        _ <- IO.puts("✓ Successfully generated cover letter"),
        {:ok, pdf} <-
            (IO.puts("Step 4: Rendering cover letter to PDF...");
            CoverLetter.render(cover_letter)),
        :ok <- File.write(pdf_filename(filename), pdf),
        _ <- IO.puts("✓ Cover letter PDF saved as #{pdf_filename(filename)}"),
        {:ok, text} <- (IO.puts("Step 5: Saving text version..."); CoverLetter.to_text(cover_letter)),
        :ok <- File.write(txt_filename(filename), text),
        _ <- IO.puts("✓ Cover letter text saved as #{txt_filename(filename)}"),
        _ <- IO.inspect(questions),
        {:ok, responses} <- (if is_nil(questions) do
          IO.puts("No Questions")
          {:ok, nil}
        else
          IO.puts("Answering Form Questions")
          Questions.answer(resume, questions)
        end),
        :ok <- Questions.validate_responses(questions, responses) do
          IO.inspect(questions)
          IO.puts("Filling Form")
          Filler.fill_form(page, responses, resume, File.read!(txt_filename(filename)))
          Process.sleep(600_000)
          IO.puts("Process completed successfully!")
    else
      {:error, reason} ->
        IO.puts("✗ Failed to extract job description: #{inspect(reason)}")
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

  defp process_without_browser(job_description, resume, filename) do
    with {:safe, _} <-
            (IO.puts("Step 2: Validating extracted text for safety...");
            TextValidator.validate_text(job_description)),
        _ <- IO.puts("✓ Text validation passed - content is safe"),
        {:ok, cover_letter} <-
            (IO.puts("Step 3: Generating cover letter...");
            CoverLetter.generate(resume, job_description)),
        _ <- IO.puts("✓ Successfully generated cover letter"),
        {:ok, pdf} <-
            (IO.puts("Step 4: Rendering cover letter to PDF...");
            CoverLetter.render(cover_letter)),
        :ok <- File.write(pdf_filename(filename), pdf),
        _ <- IO.puts("✓ Cover letter PDF saved as #{pdf_filename(filename)}"),
        {:ok, text} <- (IO.puts("Step 5: Saving text version..."); CoverLetter.to_text(cover_letter)),
        :ok <- File.write(txt_filename(filename), text),
        _ <- IO.puts("✓ Cover letter text saved as #{txt_filename(filename)}") do
          IO.puts("Process completed successfully!")
    else
      {:error, reason} ->
        IO.puts("✗ Failed to process: #{reason}")
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

  defp pdf_filename(root) do
    "#{root}.pdf"
  end

  defp txt_filename(root) do
    "#{root}.txt"
  end
  end

Main.run()
