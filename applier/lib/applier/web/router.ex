defmodule Applier.Web.Router do
  use Plug.Router
  import Phoenix.HTML

  plug Plug.Static, at: "/", from: :applier
  plug :match
  plug Plug.Parsers, parsers: [:urlencoded, :multipart]
  plug :dispatch

  get "/" do
    applications = Applier.Applications.list_applications()
    IO.inspect(applications)
    [a | _] = applications
    IO.inspect(a.source_url)

    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Job Applications</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f2f2f2; }
            .status-true { color: green; font-weight: bold; }
            .status-false { color: #999; }
            .nav { margin-bottom: 20px; }
            .nav a { margin-right: 15px; text-decoration: none; color: #007cba; }
            .nav a:hover { text-decoration: underline; }
        </style>
    </head>
    <body>
        <div class="nav">
            <a href="/">Applications</a>
            <a href="/add">Add Application</a>
        </div>

        <h1>Job Applications</h1>

        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Company</th>
                    <th>Job Title</th>
                    <th>Source</th>
                    <th>Parsed</th>
                    <th>Approved</th>
                    <th>Docs Generated</th>
                    <th>Form Filled</th>
                    <th>Submitted</th>
                    <th>Errors</th>
                    <th>Created</th>
                </tr>
            </thead>
            <tbody>
                #{Enum.map(applications, &application_row/1) |> Enum.join()}
            </tbody>
        </table>

        #{if Enum.empty?(applications) do
            "<p>No applications found. <a href='/add'>Add your first application</a></p>"
          else
            ""
          end}
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  get "/add" do
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Add Job Application</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .form-group { margin-bottom: 15px; }
            label { display: block; margin-bottom: 5px; font-weight: bold; }
            input[type="text"], input[type="url"], textarea {
                width: 100%;
                padding: 8px;
                border: 1px solid #ddd;
                border-radius: 4px;
                font-size: 14px;
            }
            textarea { height: 150px; resize: vertical; }
            button {
                background-color: #007cba;
                color: white;
                padding: 10px 20px;
                border: none;
                border-radius: 4px;
                cursor: pointer;
                font-size: 14px;
            }
            button:hover { background-color: #005a87; }
            .nav { margin-bottom: 20px; }
            .nav a { margin-right: 15px; text-decoration: none; color: #007cba; }
            .nav a:hover { text-decoration: underline; }
            .help { color: #666; font-size: 12px; margin-top: 5px; }
        </style>
    </head>
    <body>
        <div class="nav">
            <a href="/">Applications</a>
            <a href="/add">Add Application</a>
        </div>

        <h1>Add New Job Application</h1>

        <form action="/add" method="post">
            <div class="form-group">
                <label for="source_url">Job Posting URL</label>
                <input type="url" id="source_url" name="source_url" placeholder="https://..." />
                <div class="help">Provide a URL to a job posting</div>
            </div>

            <div class="form-group">
                <label for="source_text">OR Job Description Text</label>
                <textarea id="source_text" name="source_text" placeholder="Paste the job description here..."></textarea>
                <div class="help">If you don't have a URL, paste the job description directly</div>
            </div>

            <button type="submit">Add Application</button>
        </form>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
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

        html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Error - Add Job Application</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .error { color: red; margin-bottom: 20px; padding: 10px; border: 1px solid red; background-color: #ffe6e6; }
                .nav a { margin-right: 15px; text-decoration: none; color: #007cba; }
            </style>
        </head>
        <body>
            <div class="nav">
                <a href="/">Applications</a>
                <a href="/add">Add Application</a>
            </div>

            <h1>Error Creating Application</h1>
            <div class="error">#{errors}</div>
            <a href="/add">Try again</a>
        </body>
        </html>
        """

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(400, html)
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp application_row(app) do
    """
    <tr>
        <td>#{app.id}</td>
        <td>#{app.company_name || "-"}</td>
        <td>#{app.job_title || "-"}</td>
        <td>#{format_source(app)}</td>
        <td><span class="status-#{app.parsed}">#{if app.parsed, do: "✓", else: "○"}</span></td>
        <td><span class="status-#{app.approved}">#{if app.approved, do: "✓", else: "○"}</span></td>
        <td><span class="status-#{app.docs_generated}">#{if app.docs_generated, do: "✓", else: "○"}</span></td>
        <td><span class="status-#{app.form_filled}">#{if app.form_filled, do: "✓", else: "○"}</span></td>
        <td><span class="status-#{app.submitted}">#{if app.submitted, do: "✓", else: "○"}</span></td>
        <td>#{app.errors || "-"}</td>
        <td>#{format_datetime(app.inserted_at)}</td>
    </tr>
    """
  end

  defp format_source(app) do
    cond do
      app.source_url ->
        url_text = String.slice(app.source_url, 0, 50)
        IO.puts url_text
        "<a href=\"#{app.source_url}\" target=\"_blank\">#{url_text}</a>"
      app.source_text ->
        text_preview = String.slice(app.source_text, 0, 50) <> "..."
        text_preview
      true -> "-"
    end
  end

  defp format_datetime(datetime) do
    "#{datetime.month}/#{datetime.day}/#{datetime.year}"
  end
end
