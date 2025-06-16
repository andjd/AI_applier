defmodule Applier do
  @moduledoc """
  Main API module for the AI job applier application.
  """

  def start_job(input_source, input_value) do
    job_params = %{
      input_source: input_source,
      input_value: input_value
    }
    
    Applier.JobManager.start_job(job_params)
  end

  def stop_job(job_id) do
    Applier.JobManager.stop_job(job_id)
  end

  def get_job_status(job_id) do
    Applier.JobWorker.get_status(job_id)
  end

  def get_job_progress(job_id) do
    Applier.JobWorker.get_progress(job_id)
  end

  def list_jobs do
    Applier.JobManager.list_jobs()
  end
end