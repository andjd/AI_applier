defmodule Applier.Web.Templates.Applications do
  use Temple.Component
  import Phoenix.HTML
  alias Applier.Web.Templates.Layout

  def index(assigns) do
    temple do
      c &Layout.app/1, title: "Job Applications" do
        h1 "Job Applications"
        
        table do
          thead do
            tr do
              th "ID"
              th "Company"
              th "Job Title"
              th "Source"
              th "Parsed"
              th "Approved"
              th "Docs Generated"
              th "Form Filled"
              th "Submitted"
              th "Errors"
              th "Created"
            end
          end
          tbody do
            for app <- assigns.applications do
              application_row(%{app: app})
            end
          end
        end
        
        if Enum.empty?(assigns.applications) do
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
        h1 "Add New Job Application"
        
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
      c &Layout.app/1, title: "Error - Add Job Application" do
        h1 "Error Creating Application"
        div class: "error", do: assigns.errors
        a href: "/add", do: "Try again"
      end
    end
  end

  defp application_row(assigns) do
    app = assigns.app
    temple do
      tr do
        td app.id
        td app.company_name || "-"
        td app.job_title || "-"
        td do
          raw format_source(app)
        end
        td do
          span class: "status-#{app.parsed}" do
            if app.parsed, do: "✓", else: "○"
          end
        end
        td do
          span class: "status-#{app.approved}" do
            if app.approved, do: "✓", else: "○"
          end
        end
        td do
          span class: "status-#{app.docs_generated}" do
            if app.docs_generated, do: "✓", else: "○"
          end
        end
        td do
          span class: "status-#{app.form_filled}" do
            if app.form_filled, do: "✓", else: "○"
          end
        end
        td do
          span class: "status-#{app.submitted}" do
            if app.submitted, do: "✓", else: "○"
          end
        end
        td app.errors || "-"
        td format_datetime(app.inserted_at)
      end
    end
  end

  defp format_source(app) do
    cond do
      app.source_url -> 
        url_text = String.slice(app.source_url, 0, 50) <> if String.length(app.source_url) > 50, do: "...", else: ""
        "<a href=\"#{html_escape(app.source_url)}\" target=\"_blank\">#{html_escape(url_text)}</a>"
      app.source_text -> 
        text_preview = String.slice(app.source_text, 0, 50) <> "..."
        html_escape(text_preview)
      true -> "-"
    end
  end

  defp format_datetime(datetime) do
    "#{datetime.month}/#{datetime.day}/#{datetime.year}"
  end
end