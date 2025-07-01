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
              th do: "Salary Range"
              th do: "Location"
              th do: "Attendance"
              th do: "Source"
              th do: "Parsed"
              th do: "Approved"
              th do: "Docs Generated"
              th do: "Form Filled"
              th do: "Submitted"
              th do: "Live Status"
              th do: "Errors"
              th do: "Created"
              th do: "Actions"
            end
          end
          tbody do
            for app <- @applications do
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
        h1 do: raw "Error Creating Application"
        div class: "error", do: @errors
        a href: "/add", do: raw "Try again"
      end
    end
  end

  def application_row(app) do
    temple do
      tr "data-app-id": app.id do
        td do: app.id
        td do: app.company_name || raw "-"
        td do: app.job_title || raw "-"
        td do: format_salary_range(app)
        td do: app.office_location || raw "-"
        td do: app.office_attendance || raw "-"
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
        td class: "live-status-cell" do
          raw "-"
        end
        td do: app.errors || raw "-"
        td do: format_datetime(app.inserted_at)
        td do: action_button(app)
      end
    end
  end

  defp format_salary_range(app) do
    cond do
      app.salary_range_min && app.salary_range_max && app.salary_period ->
        min_formatted = format_number(app.salary_range_min)
        max_formatted = format_number(app.salary_range_max)
        range = "#{min_formatted} - #{max_formatted}"
        period = format_salary_period(app.salary_period)
        html_escape("#{range}#{period}")
      app.salary_range_min && app.salary_period ->
        min_formatted = format_number(app.salary_range_min)
        period = format_salary_period(app.salary_period)
        html_escape("#{min_formatted}#{period}")
      true -> raw "-"
    end
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
  defp format_number(value), do: to_string(value)

  defp format_salary_period(period) do
    case period do
      "yearly" -> "/year"
      "monthly" -> "/month"
      "hourly" -> "/hour"
      _ -> ""
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

  defp action_button(app) do
    temple do
      div style: "display: flex; gap: 5px;" do
        cond do
          !app.parsed ->
            form action: "/applications/#{app.id}/retry", method: "post", style: "display: inline;" do
              button type: "submit", class: "btn btn-secondary" do
                "Processing..."
              end
            end

          !app.approved ->
            form action: "/applications/#{app.id}/approve", method: "post", style: "display: inline;" do
              button type: "submit", class: "btn btn-primary" do
                "Approve"
              end
            end

          app.approved && !app.docs_generated ->
            form action: "/applications/#{app.id}/retry", method: "post", style: "display: inline;" do
              button type: "submit", class: "btn btn-secondary" do
                "Generate Docs"
              end
            end

          app.docs_generated && !app.form_filled ->
            form action: "/applications/#{app.id}/retry", method: "post", style: "display: inline;" do
              button type: "submit", class: "btn btn-secondary" do
                "Fill Form"
              end
            end

          app.form_filled && !app.submitted ->
            # Show both "Fill Form" and "Mark Complete" buttons
            form action: "/applications/#{app.id}/retry", method: "post", style: "display: inline;" do
              button type: "submit", class: "btn btn-secondary" do
                "Fill Form"
              end
            end
            form action: "/applications/#{app.id}/complete", method: "post", style: "display: inline;" do
              button type: "submit", class: "btn btn-success" do
                "Mark Complete"
              end
            end

          app.submitted ->
            # Show "Fill Form" button even when complete
            form action: "/applications/#{app.id}/retry", method: "post", style: "display: inline;" do
              button type: "submit", class: "btn btn-secondary" do
                "Fill Form"
              end
            end

          app.errors ->
            form action: "/applications/#{app.id}/retry", method: "post", style: "display: inline;" do
              button type: "submit", class: "btn btn-warning" do
                "Retry"
              end
            end

          true ->
            form action: "/applications/#{app.id}/retry", method: "post", style: "display: inline;" do
              button type: "submit", class: "btn btn-secondary" do
                "Continue"
              end
            end
        end

        # Delete button - always show
        form action: "/applications/#{app.id}/delete", method: "post", style: "display: inline;", onsubmit: "return confirmDelete('#{app.company_name || "this application"}', '#{app.job_title || ""}');" do
          button type: "submit", class: "btn btn-danger" do
            "Delete"
          end
        end
      end
    end
  end
end
