defmodule Applier.Applications do
  @moduledoc """
  Context module for managing job applications.
  """

  import Ecto.Query
  alias Applier.Repo
  alias Applier.ApplicationRecord

  @doc """
  Returns all applications.
  """
  def list_applications do
    Repo.all(ApplicationRecord)
  end

  @doc """
  Gets a single application by id.
  """
  def get_application!(id) do
    Repo.get!(ApplicationRecord, id)
  end

  @doc """
  Gets a single application by id, returns {:ok, application} or {:error, :not_found}.
  """
  def get_application(id) do
    case Repo.get(ApplicationRecord, id) do
      nil -> {:error, :not_found}
      application -> {:ok, application}
    end
  end

  @doc """
  Creates a new application.
  """
  def create_application(attrs \\ %{}) do

    id_base = Map.get(attrs, "source_url") || Map.get(attrs, "source_text") || inspect(:calendar.local_time())

    attrs = attrs
      |> Map.put("id", Helpers.Hash.generate(id_base))
      |> Map.put("approved", true)

    with {:ok, application} <- %ApplicationRecord{}
                              |> ApplicationRecord.changeset(attrs)
                              |> Repo.insert()
    do
      # Trigger background metadata extraction
      Applier.ProcessApplication.process_async(application.id)
      {:ok, application}
    end
  end

  @doc """
  Updates an application.
  """
  def update_application(%ApplicationRecord{} = application, attrs) do
    application
    |> ApplicationRecord.changeset(attrs)
    |> Repo.update()
  end

  def update_application(id, attrs) when is_binary(id) do
    case get_application(id) do
      {:ok, application} -> update_application(application, attrs)
      error -> error
    end
  end

  @doc """
  Deletes an application.
  """
  def delete_application(%ApplicationRecord{} = application) do
    Repo.delete(application)
  end

  @doc """
  Returns an changeset for tracking application changes.
  """
  def change_application(%ApplicationRecord{} = application, attrs \\ %{}) do
    ApplicationRecord.changeset(application, attrs)
  end

  @doc """
  Approves an application by setting approved to true and triggering processing.
  """
  def approve_application(id) when is_binary(id) do
    with {:ok, application} <- update_application(id, %{approved: true, errors: nil})
    do
      # Trigger background processing
      Applier.ProcessApplication.process_async(id)
      {:ok, application}
    end
  end

  @doc """
  Retries an application by resetting error state and continuing pipeline.
  """
  def retry_application(id) when is_binary(id) do
    with {:ok, application} <- update_application(id, %{errors: nil})
    do
      # Trigger background processing
      Applier.ProcessApplication.process_async(id)
      {:ok, application}
    end
  end
end
