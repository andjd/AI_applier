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
      :timer.sleep(:infinity)
    end)
  end

  @doc """
  Manually marks an application as complete (submitted).
  This is called when the user manually submits the form.
  """
  def mark_complete(application_id) do
    Logger.info("Manually marking application #{application_id} as complete")
    broadcast_update(application_id, "completing", "Marking application as complete")

    with {:ok, application} <- Applications.get_application(application_id),
         {:ok, updated_app} <- Applications.update_application(application_id, %{submitted: true})
    do
      Logger.info("Successfully marked application #{application_id} as complete")
      broadcast_update(application_id, "completed", "Application marked as complete")
      {:ok, updated_app}
    else
      error ->
        Logger.error("Failed to mark application #{application_id} as complete: #{inspect(error)}")
        broadcast_update(application_id, "error", "Failed to mark as complete")
        {:error, error}
    end
  end

  @doc """
  Synchronously processes an application through the pipeline.
  """
  def process_application(application_id) do
    broadcast_update(application_id, "processing", "Starting application processing")

    with {:ok, application} <- Applications.get_application(application_id),
         {:ok, application} <- ensure_parsed(application),
         {:ok, application} <- ensure_approved(application),
         {:ok, application} <- generate_documents(application),
         {:ok, application} <- fill_form(application)
    do
      Logger.info("Successfully processed application #{application_id} through form filling")
      broadcast_update(application_id, "form_filled", "Form filled successfully - ready for manual review and submission")
      {:ok, application}
    else
      {:error, :not_approved} ->
        Logger.info("Application #{application_id} is waiting for approval")
        broadcast_update(application_id, "waiting_approval", "Waiting for approval")
        {:ok, :waiting_for_approval}

      {:error, reason} ->
        Logger.error("Failed to process application #{application_id}: #{inspect(reason)}")
        broadcast_update(application_id, "error", "Processing failed: #{inspect(reason)}")
        Applications.update_application(application_id, %{errors: "Processing failed: #{inspect(reason)}"})
        {:error, reason}

      error ->
        Logger.error("Unexpected error processing application #{application_id}: #{inspect(error)}")
        broadcast_update(application_id, "error", "Unexpected processing error")
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
    broadcast_update(id, "parsing", "Parsing job description metadata")

    with {:ok, job_text} <- get_job_text(application),
      {:ok, updated_app} <- Applier.MetadataExtractor.process(job_text, application.id)
    do
      broadcast_update(id, "parsed", "Metadata parsing completed")
      {:ok, updated_app}
    else
      error ->
        Logger.error("Failed to parse metadata for application #{id}: #{inspect(error)}")
        broadcast_update(id, "error", "Metadata parsing failed")
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
    broadcast_update(id, "generating_docs", "Generating cover letter and documents")

    with {:ok, job_text}  <- get_job_text(application),
         {:ok, short_id} <- get_short_id(application),
         {:ok, _cover_letter} <- generate_cover_letter_if_needed(job_text, short_id, id),
         {:ok, updated_app} <- Applications.update_application(id, %{docs_generated: true})
    do
      Logger.info("Successfully generated documents for application #{id}")
      broadcast_update(id, "docs_generated", "Documents generated successfully")
      {:ok, updated_app}
    else
      error ->
        Logger.error("Failed to generate documents for application #{id}: #{inspect(error)}")
        broadcast_update(id, "error", "Document generation failed")
        {:error, "Document generation failed"}
    end
  end

  # Step 4: Fill application form (allow re-filling even if previously filled)
  defp fill_form(%ApplicationRecord{form_filled: true} = application) do
    Logger.info("Form previously filled for application #{application.id}, re-filling...")
    fill_form_process(application)
  end

  defp fill_form(%ApplicationRecord{id: id, source_url: nil}) do
    Logger.info("No form URL available for application #{id}, marking as filled")
    Applications.update_application(id, %{form_filled: true})
  end

  defp fill_form(%ApplicationRecord{} = application) do
    fill_form_process(application)
  end

  defp fill_form_process(%ApplicationRecord{id: id, source_url: form_url} = application) do
    Logger.info("Filling form for application #{id}")
    broadcast_update(id, "filling_form", "Filling out application form")

    with {:ok, job_text}  <- get_job_text(application),
         {:ok, short_id} <- get_short_id(application),
         {:ok, _result} <- fill_application_form(form_url, job_text, short_id, id),
         {:ok, updated_app} <- Applications.update_application(id, %{form_filled: true})
    do
      Logger.info("Successfully filled form for application #{id}")
      broadcast_update(id, "form_filled", "Application form filled successfully")
      {:ok, updated_app}
    else
      error ->
        Logger.error("Failed to fill form for application #{id}: #{inspect(error)}")
        broadcast_update(id, "error", "Form filling failed")
        {:error, "Form filling failed"}
    end
  end


  # Helper functions
  defp get_job_text(%ApplicationRecord{source_text: text}) when not is_nil(text), do: {:ok, text}
  defp get_job_text(%ApplicationRecord{source_url: url, id: id}) when not is_nil(url) do
    case JDInfoExtractor.extract_text(url, id) do
      {:ok, text, _} -> {:ok, text}
      error -> error
    end
  end
  defp get_job_text(_), do: {:error, "No Job Text"}

  defp get_short_id(%ApplicationRecord{id: id}) do
    # Extract short ID from the full hash ID (assuming it follows the existing pattern)
    case String.split(id, "_") do
      [_, short_id] -> {:ok, short_id}
      _ -> {:ok, String.slice(id, 0, 8)}  # Fallback to first 8 chars
    end
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

  defp generate_cover_letter_if_needed(job_text, short_id, application_id) do
    pdf_path = "artifacts/Andrew_DeFranco_#{short_id}.pdf"
    txt_path = "artifacts/Andrew_DeFranco_#{short_id}.txt"

    cond do
      File.exists?(pdf_path) && File.exists?(txt_path) ->
        Logger.info("Cover letter artifacts already exist for #{short_id}")
        {:ok, "existing"}

      true ->
        Logger.info("Generating new cover letter for #{short_id}")
        resume = File.read!("assets/resume.yaml")

        with {:safe, _} <- validate_job_text(job_text, application_id),
             {:ok, cover_letter} <- CoverLetter.generate(resume, job_text, application_id),
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

  defp fill_application_form(form_url, _job_text, short_id, application_id) do
    Logger.info("Starting form filling process for #{short_id}")
    resume = File.read!("assets/resume.yaml")

    case Helpers.Browser.get_page_and_navigate(form_url) do
      {:ok, page} ->
        try do
          with {:ok, _text, questions} <- JDInfoExtractor.extract_text(form_url, application_id),
               {:ok, responses} <- (if is_nil(questions) do
                 Logger.info("No questions found for form")
                 {:ok, nil}
               else
                 Logger.info("Answering form questions")
                 Questions.answer(resume, questions, application_id)
               end),
               :ok <- Questions.validate_responses(questions, responses),
               {:ok, :form_filled} <- Filler.fill_form(page, responses, short_id)
          do
            Logger.info("Successfully filled form for #{short_id}")
            Logger.info("Leaving page open for manual review and submission. Page will remain open indefinitely.")
            Logger.info("Please review the form values and submit manually when ready.")
            {:ok, :form_filled}
          else
            {:error, message} ->
              Logger.error("Form filling failed: #{inspect(message)}")
              # Helpers.Browser.close_managed_page(page)
              {:error, message}
          end
        rescue
          exception ->
            Logger.error("Exception during form filling: #{inspect(exception)}")
            # Helpers.Browser.close_managed_page(page)
            reraise exception, __STACKTRACE__
        end
      {:error, reason} ->
        Logger.error("Failed to get page and navigate: #{inspect(reason)}")
        {:error, reason}
    end
  end


  defp ensure_artifacts_dir do
    case File.mkdir_p("artifacts") do
      :ok -> :ok
      {:error, :eexist} -> :ok
      error -> error
    end
  end

  defp validate_job_text(job_text, application_id) do
    case TextValidator.validate_text(job_text, application_id) do
      {:safe, _} = result -> result
      {:dangerous, _} -> {:error, "Text validation failed - content contains potentially dangerous content"}
      {:manual, _} -> {:error, "Text validation requires manual review"}
      error -> {:error, "Text validation error: #{inspect(error)}"}
    end
  end

  defp broadcast_update(application_id, status, message) do
    Phoenix.PubSub.broadcast(Applier.PubSub, "application_updates",
      {:application_update, application_id, status, message})
  end
end
