defmodule Applier.ProcessApplication do
  @moduledoc """
  Orchestrates the complete job application processing pipeline.

  Pipeline stages:
  1. Parse metadata (if not already done)
  2. Wait for approval
  3. Generate documents (cover letter, etc.)
  4. Fill application form
  5. Submit application
  """

  require Logger
  alias Applier.{Applications, ApplicationRecord}

  @doc """
  Processes an application through the complete pipeline.
  This function is called when an application is approved or retried.
  """
  def process_async(application_id) do
    Task.start(fn ->
      process_application(application_id)
    end)
  end

  @doc """
  Synchronously processes an application through the pipeline.
  """
  def process_application(application_id) do
    with {:ok, application} <- Applications.get_application(application_id),
         {:ok, application} <- ensure_parsed(application),
         {:ok, application} <- ensure_approved(application),
         {:ok, application} <- generate_documents(application),
         {:ok, application} <- fill_form(application),
         {:ok, application} <- submit_application(application)
    do
      Logger.info("Successfully processed application #{application_id}")
      {:ok, application}
    else
      {:error, :not_approved} ->
        Logger.info("Application #{application_id} is waiting for approval")
        {:ok, :waiting_for_approval}

      {:error, reason} ->
        Logger.error("Failed to process application #{application_id}: #{inspect(reason)}")
        Applications.update_application(application_id, %{errors: "Processing failed: #{inspect(reason)}"})
        {:error, reason}

      error ->
        Logger.error("Unexpected error processing application #{application_id}: #{inspect(error)}")
        Applications.update_application(application_id, %{errors: "Unexpected processing error"})
        {:error, error}
    end
  end

  # Step 1: Ensure metadata is parsed
  defp ensure_parsed(%ApplicationRecord{parsed: true} = application) do
    {:ok, application}
  end

  defp ensure_parsed(%ApplicationRecord{id: id} = application) do
    Logger.info("Parsing metadata for application #{id}")

    with job_text <- get_job_text(application),
      {:ok, metadata} <- Applier.MetadataExtractor.perform_metadata_extraction(job_text, application.id),
        {:ok, updated_app} <- update_with_metadata(application, metadata)
    do
      {:ok, updated_app}
    else
      error ->
        Logger.error("Failed to parse metadata for application #{id}: #{inspect(error)}")
        {:error, "Metadata parsing failed"}
    end
  end

  # Step 2: Check if application is approved
  defp ensure_approved(%ApplicationRecord{approved: true} = application) do
    {:ok, application}
  end

  defp ensure_approved(%ApplicationRecord{}) do
    {:error, :not_approved}
  end

  # Step 3: Generate documents (cover letter, etc.)
  defp generate_documents(%ApplicationRecord{docs_generated: true} = application) do
    Logger.info("Documents already generated for application #{application.id}")
    {:ok, application}
  end

  defp generate_documents(%ApplicationRecord{id: id} = application) do
    Logger.info("Generating documents for application #{id}")

    with job_text <- get_job_text(application),
         {:ok, short_id} <- get_short_id(application),
         {:ok, _cover_letter} <- generate_cover_letter_if_needed(job_text, short_id),
         {:ok, updated_app} <- Applications.update_application(id, %{docs_generated: true})
    do
      Logger.info("Successfully generated documents for application #{id}")
      {:ok, updated_app}
    else
      error ->
        Logger.error("Failed to generate documents for application #{id}: #{inspect(error)}")
        {:error, "Document generation failed"}
    end
  end

  # Step 4: Fill application form
  defp fill_form(%ApplicationRecord{form_filled: true} = application) do
    Logger.info("Form already filled for application #{application.id}")
    {:ok, application}
  end

  defp fill_form(%ApplicationRecord{id: id, source_url: nil}) do
    Logger.info("No form URL available for application #{id}, marking as filled")
    Applications.update_application(id, %{form_filled: true})
  end

  defp fill_form(%ApplicationRecord{id: id, source_url: form_url} = application) do
    Logger.info("Filling form for application #{id}")

    with job_text <- get_job_text(application),
         {:ok, short_id} <- get_short_id(application),
         {:ok, _result} <- fill_application_form(form_url, job_text, short_id),
         {:ok, updated_app} <- Applications.update_application(id, %{form_filled: true})
    do
      Logger.info("Successfully filled form for application #{id}")
      {:ok, updated_app}
    else
      error ->
        Logger.error("Failed to fill form for application #{id}: #{inspect(error)}")
        {:error, "Form filling failed"}
    end
  end

  # Step 5: Submit application
  defp submit_application(%ApplicationRecord{submitted: true} = application) do
    Logger.info("Application #{application.id} already submitted")
    {:ok, application}
  end

  defp submit_application(%ApplicationRecord{id: id} = _application) do
    Logger.info("Submitting application #{id}")

    # For now, just mark as submitted - actual submission logic can be added later
    with {:ok, updated_app} <- Applications.update_application(id, %{submitted: true})
    do
      Logger.info("Successfully submitted application #{id}")
      {:ok, updated_app}
    else
      error ->
        Logger.error("Failed to submit application #{id}: #{inspect(error)}")
        {:error, "Submission failed"}
    end
  end

  # Helper functions
  defp get_job_text(%ApplicationRecord{source_text: text}) when not is_nil(text), do: text
  defp get_job_text(%ApplicationRecord{source_url: url}) when not is_nil(url) do
    case JDInfoExtractor.extract_text(url) do
      {:ok, text, _questions} -> text
      {:error, _reason} -> ""
    end
  end
  defp get_job_text(_), do: ""

  defp get_short_id(%ApplicationRecord{id: id}) do
    # Extract short ID from the full hash ID (assuming it follows the existing pattern)
    case String.split(id, "_") do
      [_, short_id] -> {:ok, short_id}
      _ -> {:ok, String.slice(id, 0, 8)}  # Fallback to first 8 chars
    end
  end

  defp update_with_metadata(application, metadata) do
    attrs = %{
      company_name: metadata["company_name"],
      job_title: metadata["job_title"],
      salary_range_min: cast_salary_value(metadata["salary_range_min"]),
      salary_range_max: cast_salary_value(metadata["salary_range_max"]),
      salary_period: metadata["salary_period"],
      office_location: metadata["office_location"],
      office_attendance: metadata["office_attendance"],
      parsed: true
    }

    Applications.update_application(application.id, attrs)
  end

  defp cast_salary_value(nil), do: nil
  defp cast_salary_value(value) when is_integer(value), do: value
  defp cast_salary_value(value) when is_binary(value) do
    cleaned = value
    |> String.replace(~r/[$,£€¥]/, "")
    |> String.replace(~r/[k|K]$/, "000")
    |> String.trim()

    case Integer.parse(cleaned) do
      {integer, ""} -> integer
      _ -> nil
    end
  end
  defp cast_salary_value(_), do: nil

  defp generate_cover_letter_if_needed(job_text, short_id) do
    pdf_path = "artifacts/Andrew_DeFranco_#{short_id}.pdf"
    txt_path = "artifacts/Andrew_DeFranco_#{short_id}.txt"

    cond do
      File.exists?(pdf_path) && File.exists?(txt_path) ->
        Logger.info("Cover letter artifacts already exist for #{short_id}")
        {:ok, "existing"}

      true ->
        Logger.info("Generating new cover letter for #{short_id}")
        resume = File.read!("assets/resume.yaml")

        with {:safe, _} <- validate_job_text(job_text),
             {:ok, cover_letter} <- CoverLetter.generate(resume, job_text),
             {:ok, pdf} <- CoverLetter.render(cover_letter),
             {:ok, text} <- CoverLetter.to_text(cover_letter),
             :ok <- ensure_artifacts_dir(),
             :ok <- File.write(pdf_path, pdf),
             :ok <- File.write(txt_path, text)
        do
          Logger.info("Successfully generated cover letter for #{short_id}")
          {:ok, cover_letter}
        end
    end
  end

  defp fill_application_form(form_url, _job_text, short_id) do
    Logger.info("Starting form filling process for #{short_id}")
    resume = File.read!("assets/resume.yaml")

    with {:ok, browser, page} <- Helpers.Browser.launch_and_navigate(form_url),
         {:ok, _text, questions} <- JDInfoExtractor.extract_text(page),
         {:ok, responses} <- (if is_nil(questions) do
           Logger.info("No questions found for form")
           {:ok, nil}
         else
           Logger.info("Answering form questions")
           Questions.answer(resume, questions)
         end),
         :ok <- Questions.validate_responses(questions, responses),
         :ok <- Filler.fill_form(page, responses, resume, get_cover_letter_text(short_id)),
         _ <- Helpers.Browser.close_page(page),
         _ <- Helpers.Browser.close_browser(browser)
    do
      Logger.info("Successfully filled form for #{short_id}")
      {:ok, "form_filled"}
    else
      error ->
        Logger.error("Form filling failed: #{inspect(error)}")
        error
    end
  end

  defp get_cover_letter_text(short_id) do
    txt_path = "artifacts/Andrew_DeFranco_#{short_id}.txt"
    case File.read(txt_path) do
      {:ok, content} -> content
      _ -> ""
    end
  end

  defp ensure_artifacts_dir do
    case File.mkdir_p("artifacts") do
      :ok -> :ok
      {:error, :eexist} -> :ok
      error -> error
    end
  end

  defp validate_job_text(job_text) do
    case TextValidator.validate_text(job_text) do
      {:safe, _} = result -> result
      {:dangerous, _} -> {:error, "Text validation failed - content contains potentially dangerous content"}
      {:manual, _} -> {:error, "Text validation requires manual review"}
      error -> {:error, "Text validation error: #{inspect(error)}"}
    end
  end
end
