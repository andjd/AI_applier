defmodule Applier.Web.Router do
  use Plug.Router
  import Phoenix.HTML
  alias ElixirLS.LanguageServer.Plugins.Phoenix
  alias Applier.Web.Templates.Applications

  plug Plug.Static, at: "/", from: :applier
  plug Plug.Static, at: "/static", from: {:applier, "priv/static"}
  plug :match
  plug Plug.Parsers, parsers: [:urlencoded, :multipart]
  plug :dispatch

  get "/ws" do
    conn
    |> WebSockAdapter.upgrade(Applier.Web.WebSocketHandler, %{}, timeout: 60_000)
  end

  get "/" do
    filter = case conn.params["filter"] do
      "completed" -> :completed
      "awaiting_approval" -> :awaiting_approval
      "approved_pending" -> :approved_pending
      "rejected" -> :rejected
      _ -> :all
    end

    applications = Applier.Applications.list_applications(filter)

    html = Applications.index(%{applications: applications, current_filter: filter})
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

  get "/applications/:id" do
    case Applier.Applications.get_application(id) do
      {:ok, application} ->
        # Get short ID for artifact files
        short_id = case String.split(id, "_") do
          [_, short_id] -> short_id
          _ -> String.slice(id, 0, 8)
        end
        
        # Read cover letter if it exists
        cover_letter_path = "artifacts/Andrew_DeFranco_#{short_id}.txt"
        cover_letter = if File.exists?(cover_letter_path), do: File.read!(cover_letter_path), else: nil
        
        # Get questions/answers if they exist (would need to check how they're stored)
        questions_answers = get_questions_answers(application)
        
        html = Applications.show(%{
          application: application,
          cover_letter: cover_letter,
          questions_answers: questions_answers
        })
        
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, safe_to_string(html))
        
      {:error, :not_found} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(404, "Application not found")
    end
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
      {:ok, application} ->
        case get_req_header(conn, "x-requested-with") do
          ["XMLHttpRequest"] ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, JSON.encode!(%{
              success: true,
              message: "Application approved successfully",
              application: %{
                id: application.id,
                parsed: application.parsed,
                approved: application.approved,
                docs_generated: application.docs_generated,
                form_filled: application.form_filled,
                submitted: application.submitted,
                priority: application.priority
              }
            }))
          _ ->
            conn
            |> put_resp_header("location", "/")
            |> send_resp(302, "")
        end

      {:error, reason} ->
        case get_req_header(conn, "x-requested-with") do
          ["XMLHttpRequest"] ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, JSON.encode!(%{
              success: false,
              message: "Failed to approve application: #{inspect(reason)}"
            }))
          _ ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(400, "Failed to approve application: #{inspect(reason)}")
        end
    end
  end

  post "/applications/:id/priority" do
    case Applier.Applications.mark_priority_application(id) do
      {:ok, application} ->
        case get_req_header(conn, "x-requested-with") do
          ["XMLHttpRequest"] ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, JSON.encode!(%{
              success: true,
              message: "Application marked as priority successfully",
              application: %{
                id: application.id,
                parsed: application.parsed,
                approved: application.approved,
                docs_generated: application.docs_generated,
                form_filled: application.form_filled,
                submitted: application.submitted,
                priority: application.priority
              }
            }))
          _ ->
            conn
            |> put_resp_header("location", "/")
            |> send_resp(302, "")
        end

      {:error, reason} ->
        case get_req_header(conn, "x-requested-with") do
          ["XMLHttpRequest"] ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, JSON.encode!(%{
              success: false,
              message: "Failed to mark application as priority: #{inspect(reason)}"
            }))
          _ ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(400, "Failed to mark application as priority: #{inspect(reason)}")
        end
    end
  end

  post "/applications/:id/retry" do
    case Applier.Applications.retry_application(id) do
      {:ok, application} ->
        case get_req_header(conn, "x-requested-with") do
          ["XMLHttpRequest"] ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, JSON.encode!(%{
              success: true,
              message: "Application processing started",
              application: %{
                id: application.id,
                parsed: application.parsed,
                approved: application.approved,
                docs_generated: application.docs_generated,
                form_filled: application.form_filled,
                submitted: application.submitted,
                priority: application.priority
              }
            }))
          _ ->
            conn
            |> put_resp_header("location", "/")
            |> send_resp(302, "")
        end

      {:error, reason} ->
        case get_req_header(conn, "x-requested-with") do
          ["XMLHttpRequest"] ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, JSON.encode!(%{
              success: false,
              message: "Failed to retry application: #{inspect(reason)}"
            }))
          _ ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(400, "Failed to retry application: #{inspect(reason)}")
        end
    end
  end

  post "/applications/:id/complete" do
    case Applier.ProcessApplication.mark_complete(id) do
      {:ok, application} ->
        case get_req_header(conn, "x-requested-with") do
          ["XMLHttpRequest"] ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, JSON.encode!(%{
              success: true,
              message: "Application marked as complete",
              application: %{
                id: application.id,
                parsed: application.parsed,
                approved: application.approved,
                docs_generated: application.docs_generated,
                form_filled: application.form_filled,
                submitted: application.submitted,
                priority: application.priority
              }
            }))
          _ ->
            conn
            |> put_resp_header("location", "/")
            |> send_resp(302, "")
        end

      {:error, reason} ->
        case get_req_header(conn, "x-requested-with") do
          ["XMLHttpRequest"] ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, JSON.encode!(%{
              success: false,
              message: "Failed to mark application as complete: #{inspect(reason)}"
            }))
          _ ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(400, "Failed to mark application as complete: #{inspect(reason)}")
        end
    end
  end

  post "/applications/:id/reject" do
    case Applier.Applications.reject_application(id) do
      {:ok, application} ->
        case get_req_header(conn, "x-requested-with") do
          ["XMLHttpRequest"] ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, JSON.encode!(%{
              success: true,
              message: "Application rejected successfully",
              application: %{
                id: application.id,
                parsed: application.parsed,
                approved: application.approved,
                docs_generated: application.docs_generated,
                form_filled: application.form_filled,
                submitted: application.submitted,
                priority: application.priority
              }
            }))
          _ ->
            conn
            |> put_resp_header("location", "/")
            |> send_resp(302, "")
        end

      {:error, reason} ->
        case get_req_header(conn, "x-requested-with") do
          ["XMLHttpRequest"] ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, JSON.encode!(%{
              success: false,
              message: "Failed to reject application: #{inspect(reason)}"
            }))
          _ ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(400, "Failed to reject application: #{inspect(reason)}")
        end
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

  # Helper function to get questions/answers for an application
  defp get_questions_answers(application) do
    # This would need to be implemented based on how Q&A are stored
    # For now, return nil - you might store them in a separate table or file
    nil
  end
end
