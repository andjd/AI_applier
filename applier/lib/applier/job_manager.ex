defmodule Applier.JobManager do
  @moduledoc """
  DynamicSupervisor for managing job application processes.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_job(job_params) do
    job_id = generate_job_id(job_params)
    
    child_spec = {Applier.JobWorker, Map.put(job_params, :job_id, job_id)}
    
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} -> 
        {:ok, job_id, pid}
      error -> 
        error
    end
  end

  def stop_job(job_id) do
    case Registry.lookup(Applier.JobRegistry, job_id) do
      [{pid, _}] -> 
        DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> 
        {:error, :job_not_found}
    end
  end

  def list_jobs do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} ->
      case Registry.keys(Applier.JobRegistry, pid) do
        [job_id] -> {job_id, pid}
        _ -> {nil, pid}
      end
    end)
  end

  defp generate_job_id(%{input_source: :url, input_value: url}) do
    :crypto.hash(:sha256, url) 
    |> Base.encode16(case: :lower) 
    |> String.slice(0, 8)
  end

  defp generate_job_id(%{input_source: :text, input_value: text}) do
    :crypto.hash(:sha256, text) 
    |> Base.encode16(case: :lower) 
    |> String.slice(0, 8)
  end

  defp generate_job_id(_) do
    :crypto.strong_rand_bytes(4) 
    |> Base.encode16(case: :lower)
  end
end