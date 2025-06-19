defmodule Applier.Web.Templates.Applications do
  use Temple.Component
  import Phoenix.HTML
  alias Applier.Web.Templates.Layout

  def index(assigns) do
    temple do
      c &Layout.app/1, title: "Job Applications" do
        h1 do: "Job Applications"

        table do
          thead do
            tr do
              th do: "ID"
              th do: "Company"
              th do: "Job Title"
              th do: "Source"
              th do: "Parsed"
              th do: "Approved"
              th do: "Docs Generated"
              th do: "Form Filled"
              th do: "Submitted"
              th do: "Errors"
              th do: "Created"
            end
          end
          tbody do
            for app <- @applications do
              _=IO.inspect(app)
              application_row(app)
            end
          end
        end

        if Enum.empty?(@applications) do
          p do
            "No applications found. "
            a href: "/add", do: "Add your first application"
          end
        end
      end
    end
  end

  def add(assigns) do
    temple do
      c &Layout.app/1, title: "Add Job Application" do
        h1 do: "Add New Job Application"

        form action: "/add", method: "post" do
          div class: "form-group" do
            label for: "source_url", do: "Job Posting URL"
            input type: "url", id: "source_url", name: "source_url", placeholder: "https://..."
            div class: "help", do: "Provide a URL to a job posting"
          end

          div class: "form-group" do
            label for: "source_text", do: "OR Job Description Text"
            textarea id: "source_text", name: "source_text", placeholder: "Paste the job description here..."
            div class: "help", do: "If you don't have a URL, paste the job description directly"
          end

          button type: "submit", do: "Add Application"
        end
      end
    end
  end

  def error(assigns) do
    temple do
      c &Layout.app/1, title: {:safe, "Error - Add Job Application"} do
        h1 "Error Creating Application"
        div class: "error", do: @errors
        a href: "/add", do: "Try again"
      end
    end
  end

  def application_row(app) do
    IO.inspect(app)
    temple do
      tr do
        td do: app.id
        td do: app.company_name || raw "-"
        td do: app.job_title || raw "-"
        td do
          format_source(app)
        end
        td do
          span class: "status-#{app.parsed}" do
            raw if app.parsed, do: "✓", else: "○"
          end
        end
        td do
          span class: "status-#{app.approved}" do
            raw if app.approved, do: "✓", else: "○"
          end
        end
        td do
          span class: "status-#{app.docs_generated}" do
            raw if app.docs_generated, do: "✓", else: "○"
          end
        end
        td do
          span class: "status-#{app.form_filled}" do
            raw if app.form_filled, do: "✓", else: "○"
          end
        end
        td do
          span class: "status-#{app.submitted}" do
            raw if app.submitted, do: "✓", else: "○"
          end
        end
        td do: app.errors || raw "-"
        td do: format_datetime(app.inserted_at)
      end
    end
  end

  defp format_source(app) do
    cond do
      app.source_url ->
        {_, url} = html_escape(app.source_url)
        raw "<a href=\"#{url}\" target=\"_blank\">#{url}</a>"
      app.source_text -> html_escape(app.source_text)
      true -> raw "-"
    end
  end

  defp format_datetime(datetime) do
    html_escape "#{datetime.month}/#{datetime.day}/#{datetime.year}"
  end
end
