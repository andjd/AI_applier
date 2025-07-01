defmodule Applier.Web.Router do
  use Plug.Router
  import Phoenix.HTML
  alias ElixirLS.LanguageServer.Plugins.Phoenix
  alias Applier.Web.Templates.Applications

  plug Plug.Static, at: "/", from: :applier
  plug :match
  plug Plug.Parsers, parsers: [:urlencoded, :multipart]
  plug :dispatch

  get "/ws" do
    conn
    |> WebSockAdapter.upgrade(Applier.Web.WebSocketHandler, %{}, timeout: 60_000)
  end

  get "/" do
    applications = Applier.Applications.list_applications()

    html = Applications.index(%{applications: applications})
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, safe_to_string(html))
  end

  get "/add" do
    html = Applications.add(%{})

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, safe_to_string(html))
  end

  post "/add" do
    case Applier.Applications.create_application(conn.params) do
      {:ok, _application} ->
        conn
        |> put_resp_header("location", "/")
        |> send_resp(302, "")

      {:error, changeset} ->
        errors = Enum.map(changeset.errors, fn {field, {message, _}} ->
          "#{field}: #{message}"
        end) |> Enum.join(", ")

        html = Applications.error(%{errors: errors})

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(400, safe_to_string(html))
    end
  end

  post "/applications/:id/approve" do
    case Applier.Applications.approve_application(id) do
      {:ok, _application} ->
        conn
        |> put_resp_header("location", "/")
        |> send_resp(302, "")

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "Failed to approve application: #{inspect(reason)}")
    end
  end

  post "/applications/:id/retry" do
    case Applier.Applications.retry_application(id) do
      {:ok, _application} ->
        conn
        |> put_resp_header("location", "/")
        |> send_resp(302, "")

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "Failed to retry application: #{inspect(reason)}")
    end
  end

  post "/applications/:id/complete" do
    case Applier.ProcessApplication.mark_complete(id) do
      {:ok, _application} ->
        conn
        |> put_resp_header("location", "/")
        |> send_resp(302, "")

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "Failed to mark application as complete: #{inspect(reason)}")
    end
  end

  post "/applications/:id/delete" do
    case Applier.Applications.get_application(id) do
      {:ok, application} ->
        case Applier.Applications.delete_application(application) do
          {:ok, _deleted_application} ->
            conn
            |> put_resp_header("location", "/")
            |> send_resp(302, "")

          {:error, reason} ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(400, "Failed to delete application: #{inspect(reason)}")
        end

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Application not found")
    end
  end

  post "/fetch-jobs" do
    case Applier.HiringCafeAPI.fetch_jobs() do
      {:ok, result} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, JSON.encode!(%{
          success: true,
          message: "Successfully fetched #{result.total_jobs} jobs. #{result.successful} processed successfully, #{result.failed} failed.",
          data: result
        }))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, JSON.encode!(%{
          success: false,
          message: "Failed to fetch jobs: #{inspect(reason)}"
        }))
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
