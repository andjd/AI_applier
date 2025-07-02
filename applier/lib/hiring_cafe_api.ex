defmodule Applier.HiringCafeAPI do
  @moduledoc """
  Module for integrating with the hiringCafe API to fetch jobs.
  """

  require Logger
  alias Applier.Repo
  alias Applier.ApplicationRecord

  @api_url "https://hiring.cafe/api/search-jobs"
  @payload_file "assets/hiring_cafe_payload.json"
  @cache_dir ".cache"

  def fetch_jobs do
    Logger.info("Fetching jobs from hiringCafe API...")

    {successes, failures} = make_api_request()
      |> Map.get("results")
      |> Enum.map(&process_job/1)
      |> Enum.split_with(fn {status, _} -> status == :ok end)

      Logger.info("Processed #{length(successes)} jobs successfully, #{length(failures)} failed")

      {:ok, %{
        total_jobs: length(successes) + length(failures),
        successful: length(successes),
        failed: length(failures),
      }}
  end

  defp make_api_request() do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    resp = Req.post!(@api_url, headers: headers, body: File.read!(@payload_file))
    resp.body
  end

  defp format_location(source) do
    cond do
      source["city"] && source["state"] ->
        "#{source["city"]}, #{source["state"]}"
      source["city"] ->
        source["city"]
      source["state"] ->
        source["state"]
      source["country"] ->
        source["country"]
      true ->
        nil
    end
  end

  defp process_job(job) do
    with {:ok, application} <- create_application(job),
         {:ok, _} <- cache_job_description(application, job) do
      {:ok, application}
    else
      error -> error
    end
  end

  defp cache_job_description(application, job) do
    if job["job_description"] do
      cache_filename = "job_description_#{application.id}.html"
      cache_path = Path.join(@cache_dir, cache_filename)

      case File.write(cache_path, job["job_information"]["description"]) do
        :ok ->
          {:ok, cache_path}
        {:error, reason} ->
          Logger.error("Failed to cache job description for #{application.id}: #{inspect(reason)}")
          {:error, "Failed to cache job description"}
      end
    else
      {:ok, nil}
    end
  end

  defp create_application(job) do
    # Generate a unique ID for the application
    job_info = job["job_information"]
    job_data = job["v5_processed_job_data"]
    id_base = job["apply_url"] || inspect(:calendar.local_time())
    application_id = Helpers.Hash.generate(id_base)

    attrs = %{
      "id" => application_id,
      "company_name" => job_data["company_name"],
      "job_title" => job_info["title"] || job_data["core_job_title"],
      "salary_range_min" => job_data["yearly_min_compensation"],
      "salary_range_max" => job_data["yearly_max_compensation"],
      "salary_period" => job_data["listed_compensation_frequency"],
      "office_location" => job_data["formatted_workplace_location"],
      "office_attendance" => job_data["workplace_type"],
      "source_url" => job["apply_url"],
      "approved" => false,  # Jobs from hiringCafe are not auto-approved
      "parsed" => false
    }

    with {:ok, application} <- (%ApplicationRecord{}
      |> ApplicationRecord.changeset(attrs)
      |> Repo.insert()) do

        Logger.info("Created application #{application.id} for #{attrs["company_name"]} - #{attrs["job_title"]}")
        {:ok, application}
      else
      {:error, changeset} ->
        errors = Enum.map(changeset.errors, fn {field, {message, _}} ->
          "#{field}: #{message}"
        end) |> Enum.join(", ")

        {:error, "Failed to create application: #{errors}"}
    end
  end
end
