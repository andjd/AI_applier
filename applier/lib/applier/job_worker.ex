defmodule Applier.JobWorker do
  @moduledoc """
  GenServer for handling individual job application processing.
  """
  use GenServer
  require Logger

  defstruct [
    :job_id,
    :input_source,
    :input_value,
    :resume,
    :filename,
    :status,
    :browser_pid,
    :page,
    :error
  ]

  def start_link(job_params) do
    GenServer.start_link(__MODULE__, job_params, name: via_tuple(job_params.job_id))
  end

  def get_status(job_id) do
    GenServer.call(via_tuple(job_id), :get_status)
  end

  def get_progress(job_id) do
    GenServer.call(via_tuple(job_id), :get_progress)
  end

  def init(job_params) do
    Logger.info("Starting job worker for job #{job_params.job_id}")
    
    resume = File.read!("assets/resume.yaml")
    filename = "artifacts/Andrew_DeFranco_#{job_params.job_id}"
    
    state = %__MODULE__{
      job_id: job_params.job_id,
      input_source: job_params.input_source,
      input_value: job_params.input_value,
      resume: resume,
      filename: filename,
      status: :initializing
    }

    {:ok, state, {:continue, :start_processing}}
  end

  def handle_continue(:start_processing, state) do
    Logger.info("Job #{state.job_id}: Starting processing")
    
    case state.input_source do
      :url ->
        {:noreply, state, {:continue, :acquire_browser}}
      :text ->
        {:noreply, state, {:continue, :process_without_browser}}
    end
  end

  def handle_continue(:acquire_browser, state) do
    Logger.info("Job #{state.job_id}: Acquiring browser from pool")
    
    case Applier.BrowserPool.checkout() do
      {:ok, browser_pid} ->
        case Helpers.Browser.create_page(browser_pid) do
          {:ok, page} ->
            new_state = %{state | 
              browser_pid: browser_pid, 
              page: page, 
              status: :browser_acquired
            }
            {:noreply, new_state, {:continue, :navigate_to_url}}
          {:error, reason} ->
            Applier.BrowserPool.checkin(browser_pid)
            handle_error(state, "Failed to create page: #{reason}")
        end
      {:error, reason} ->
        handle_error(state, "Failed to acquire browser: #{reason}")
    end
  end

  def handle_continue(:navigate_to_url, state) do
    Logger.info("Job #{state.job_id}: Navigating to URL")
    
    case Helpers.Browser.navigate(state.page, state.input_value) do
      :ok ->
        new_state = %{state | status: :navigated}
        {:noreply, new_state, {:continue, :extract_job_info}}
      {:error, reason} ->
        handle_error(state, "Failed to navigate: #{reason}")
    end
  end

  def handle_continue(:extract_job_info, state) do
    Logger.info("Job #{state.job_id}: Extracting job information")
    
    case JDInfoExtractor.extract_text(state.page) do
      {:ok, job_description, questions} ->
        new_state = %{state | status: :job_info_extracted}
        {:noreply, new_state, {:continue, {:validate_text, job_description, questions}}}
      {:error, reason} ->
        handle_error(state, "Failed to extract job info: #{reason}")
    end
  end

  def handle_continue({:validate_text, job_description, questions}, state) do
    Logger.info("Job #{state.job_id}: Validating text")
    
    full_text = job_description <> 
      (questions |> Enum.map(fn q -> Map.get(q, :label, "") end) |> Enum.join("\n"))
    
    case TextValidator.validate_text(full_text) do
      {:safe, _} ->
        new_state = %{state | status: :text_validated}
        {:noreply, new_state, {:continue, {:generate_cover_letter, job_description, questions}}}
      {:dangerous, _} ->
        handle_error(state, "Text validation failed - dangerous content")
      {:manual, _} ->
        handle_error(state, "Text validation requires manual review")
      {:error, reason} ->
        handle_error(state, "Text validation error: #{reason}")
    end
  end

  def handle_continue({:generate_cover_letter, job_description, questions}, state) do
    Logger.info("Job #{state.job_id}: Generating cover letter")
    
    case CoverLetter.generate(state.resume, job_description) do
      {:ok, cover_letter} ->
        new_state = %{state | status: :cover_letter_generated}
        {:noreply, new_state, {:continue, {:render_and_save, cover_letter, questions}}}
      {:error, reason} ->
        handle_error(state, "Failed to generate cover letter: #{reason}")
    end
  end

  def handle_continue({:render_and_save, cover_letter, questions}, state) do
    Logger.info("Job #{state.job_id}: Rendering and saving documents")
    
    with {:ok, pdf} <- CoverLetter.render(cover_letter),
         :ok <- File.write(pdf_filename(state.filename), pdf),
         {:ok, text} <- CoverLetter.to_text(cover_letter),
         :ok <- File.write(txt_filename(state.filename), text) do
      
      new_state = %{state | status: :documents_saved}
      
      if questions do
        {:noreply, new_state, {:continue, {:answer_questions, questions, text}}}
      else
        {:noreply, %{state | status: :completed}}
      end
    else
      {:error, reason} ->
        handle_error(state, "Failed to render/save documents: #{reason}")
    end
  end

  def handle_continue({:answer_questions, questions, cover_letter_text}, state) do
    Logger.info("Job #{state.job_id}: Answering questions")
    
    case Questions.answer(state.resume, questions) do
      {:ok, responses} ->
        case Questions.validate_responses(questions, responses) do
          :ok ->
            new_state = %{state | status: :questions_answered}
            {:noreply, new_state, {:continue, {:fill_form, responses, cover_letter_text}}}
          {:error, reason} ->
            handle_error(state, "Question validation failed: #{reason}")
        end
      {:error, reason} ->
        handle_error(state, "Failed to answer questions: #{reason}")
    end
  end

  def handle_continue({:fill_form, responses, cover_letter_text}, state) do
    Logger.info("Job #{state.job_id}: Filling form")
    
    case Filler.Greenhouse.fill_form(state.page, responses, state.resume, cover_letter_text) do
      {:ok, :form_filled} ->
        new_state = %{state | status: :form_filled}
        {:noreply, new_state, {:continue, :wait_for_completion}}
      {:error, reason} ->
        handle_error(state, "Failed to fill form: #{reason}")
    end
  end

  def handle_continue(:wait_for_completion, state) do
    Logger.info("Job #{state.job_id}: Waiting for completion")
    Process.send_after(self(), :complete_job, 600_000)
    {:noreply, state}
  end

  def handle_continue(:process_without_browser, state) do
    Logger.info("Job #{state.job_id}: Processing without browser")
    
    case TextValidator.validate_text(state.input_value) do
      {:safe, _} ->
        new_state = %{state | status: :text_validated}
        {:noreply, new_state, {:continue, {:generate_cover_letter, state.input_value, nil}}}
      {:dangerous, _} ->
        handle_error(state, "Text validation failed - dangerous content")
      {:manual, _} ->
        handle_error(state, "Text validation requires manual review")
      {:error, reason} ->
        handle_error(state, "Text validation error: #{reason}")
    end
  end

  def handle_info(:complete_job, state) do
    Logger.info("Job #{state.job_id}: Completed successfully")
    cleanup_resources(state)
    {:noreply, %{state | status: :completed}}
  end

  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  def handle_call(:get_progress, _from, state) do
    progress = %{
      job_id: state.job_id,
      status: state.status,
      input_source: state.input_source,
      error: state.error
    }
    {:reply, progress, state}
  end

  def terminate(reason, state) do
    Logger.info("Job #{state.job_id}: Terminating with reason: #{inspect(reason)}")
    cleanup_resources(state)
    :ok
  end

  defp handle_error(state, error_message) do
    Logger.error("Job #{state.job_id}: #{error_message}")
    cleanup_resources(state)
    new_state = %{state | status: :error, error: error_message}
    {:noreply, new_state}
  end

  defp cleanup_resources(state) do
    if state.page do
      Helpers.Browser.close_page(state.page)
    end
    
    if state.browser_pid do
      Applier.BrowserPool.checkin(state.browser_pid)
    end
  end

  defp pdf_filename(root), do: "#{root}.pdf"
  defp txt_filename(root), do: "#{root}.txt"

  defp via_tuple(job_id) do
    {:via, Registry, {Applier.JobRegistry, job_id}}
  end
end