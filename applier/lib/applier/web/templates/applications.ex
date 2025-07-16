defmodule Applier.Web.Templates.Applications do
  use Temple.Component
  import Phoenix.HTML
  alias Applier.Web.Templates.Layout

  def index(assigns) do
    temple do
      c &Layout.app/1, title: "Job Applications" do
        h1 do: "Job Applications"

        div class: "controls", style: "margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center;" do
          div class: "filter-buttons" do
            filter_button("All", :all, @current_filter)
            filter_button("Awaiting Approval", :awaiting_approval, @current_filter)
            filter_button("Approved & Pending", :approved_pending, @current_filter)
            filter_button("Completed", :completed, @current_filter)
            filter_button("Rejected", :rejected, @current_filter)
          end

          div class: "action-buttons" do
            button type: "button", class: "btn btn-primary", onclick: "fetchJobs(this)" do
              "Fetch New Jobs"
            end
          end
        end

        table do
          thead do
            tr do
              th do: "ID / Date"
              th do: "Job Details"
              th do: "Attendance"
              th do: "Status"
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

  def show(assigns) do
    temple do
      c &Layout.app/1, title: "Application Details" do
        div class: "application-detail" do
          div class: "detail-header" do
            h1 do: "Application Details"
            a href: "/", class: "btn btn-secondary", do: "← Back to Applications"
          end

          div class: "detail-content" do
            # Basic Information
            div class: "section" do
              h2 do: "Basic Information"
              div class: "info-grid" do
                div class: "info-item" do
                  span class: "label", do: "Application ID:"
                  span class: "value", do: @application.id
                end
                div class: "info-item" do
                  span class: "label", do: "Created:"
                  span class: "value", do: format_datetime(@application.inserted_at)
                end
                div class: "info-item" do
                  span class: "label", do: "Company:"
                  span class: "value", do: @application.company_name || "-"
                end
                div class: "info-item" do
                  span class: "label", do: "Job Title:"
                  span class: "value", do: @application.job_title || "-"
                end
                div class: "info-item" do
                  span class: "label", do: "Salary Range:"
                  span class: "value", do: format_salary_range(@application)
                end
                div class: "info-item" do
                  span class: "label", do: "Office Location:"
                  span class: "value", do: @application.office_location || "-"
                end
                div class: "info-item" do
                  span class: "label", do: "Office Attendance:"
                  span class: "value", do: @application.office_attendance || "-"
                end
                if @application.source_url do
                  div class: "info-item" do
                    span class: "label", do: "Job Posting URL:"
                    span class: "value" do
                      a href: @application.source_url, target: "_blank", do: @application.source_url
                    end
                  end
                end
              end
            end

            # Status Information
            div class: "section" do
              h2 do: "Status"
              div class: "status-grid" do
                div class: "status-item" do
                  span class: "label", do: "Parsed:"
                  span class: status_badge(@application.parsed)
                end
                div class: "status-item" do
                  span class: "label", do: "Approved:"
                  span class: status_badge(@application.approved)
                end
                div class: "status-item" do
                  span class: "label", do: "Documents Generated:"
                  span class: status_badge(@application.docs_generated)
                end
                div class: "status-item" do
                  span class: "label", do: "Form Filled:"
                  span class: status_badge(@application.form_filled)
                end
                div class: "status-item" do
                  span class: "label", do: "Submitted:"
                  span class: status_badge(@application.submitted)
                end
                div class: "status-item" do
                  span class: "label", do: "Priority:"
                  span class: status_badge(@application.priority)
                end
                div class: "status-item" do
                  span class: "label", do: "Rejected:"
                  span class: status_badge(@application.rejected)
                end
              end
              if @application.errors do
                div class: "error-section" do
                  h3 do: "Errors"
                  div class: "error-text", do: @application.errors
                end
              end
            end

            # Job Description
            if @application.source_text do
              div class: "section" do
                h2 do: "Job Description"
                div class: "source-text", do: @application.source_text
              end
            end

            # Cover Letter
            if @cover_letter do
              div class: "section" do
                h2 do: "Generated Cover Letter"
                div class: "copy-section" do
                  div class: "copy-header" do
                    button type: "button", class: "btn btn-copy", onclick: "copyToClipboard('cover-letter-content', this)" do
                      "📋 Copy Cover Letter"
                    end
                  end
                  div class: "copy-content", id: "cover-letter-content", do: @cover_letter
                end
              end
            end

            # Questions & Answers
            if @questions_answers do
              div class: "section" do
                h2 do: "Questions & Answers"
                div class: "copy-section" do
                  div class: "copy-header" do
                    button type: "button", class: "btn btn-copy", onclick: "copyToClipboard('questions-answers-content', this)" do
                      "📋 Copy Q&A"
                    end
                  end
                  div class: "copy-content", id: "questions-answers-content", do: @questions_answers
                end
              end
            end
          end
        end
      end
    end
  end

  def application_row(app) do
    temple do
      tr "data-app-id": app.id do
        td do
          div style: "display: flex; flex-direction: column; gap: 2px;" do
            div style: "font-weight: bold;" do
              a href: "/applications/#{app.id}", do: app.id
            end
            div style: "font-size: 0.9em; color: #666;", do: format_datetime(app.inserted_at)
          end
        end
        td do
          div style: "display: flex; flex-direction: column; gap: 2px;" do
            div style: "font-weight: bold;", do: app.company_name || raw "-"
            div do
              format_job_title_with_link(app)
            end
            div style: "font-size: 0.9em; color: #666;", do: format_salary_range(app)
          end
        end
        td do: app.office_attendance || raw "-"
        td do
          format_combined_status(app)
        end
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

  defp format_job_title_with_link(app) do
    cond do
      app.source_url && app.job_title ->
        {_, url} = html_escape(app.source_url)
        {_, title} = html_escape(app.job_title)
        raw "<a href=\"#{url}\" target=\"_blank\">#{title}</a>"
      app.job_title -> html_escape(app.job_title)
      true -> raw "-"
    end
  end

  defp format_datetime(datetime) do
    html_escape "#{datetime.month}/#{datetime.day}/#{datetime.year}"
  end

  defp format_combined_status(app) do
    temple do
      div style: "display: flex; flex-direction: column; gap: 2px;" do
        div class: "live-status-cell" do
          raw "-"
        end
        if app.errors do
          div style: "font-size: 0.9em; color: #d32f2f;" do
            html_escape(app.errors)
          end
        end
      end
    end
  end

  defp action_button(app) do
    temple do
      div style: "display: flex; gap: 5px;" do
        cond do
          !app.parsed ->
            button type: "button", class: "btn btn-secondary", onclick: "makeAjaxCall('/applications/#{app.id}/retry', this)" do
              "Processing..."
            end

          !app.approved ->
            button type: "button", class: "btn btn-primary", onclick: "makeAjaxCall('/applications/#{app.id}/approve', this)" do
              "Approve"
            end
            button type: "button", class: "btn btn-warning", onclick: "makeAjaxCall('/applications/#{app.id}/priority', this)" do
              "Priority"
            end

          app.approved && !app.docs_generated ->
            button type: "button", class: "btn btn-secondary", onclick: "makeAjaxCall('/applications/#{app.id}/retry', this)" do
              "Generate Docs"
            end

          app.docs_generated && !app.form_filled ->
            button type: "button", class: "btn btn-secondary", onclick: "makeAjaxCall('/applications/#{app.id}/retry', this)" do
              "Fill Form"
            end

          app.form_filled && !app.submitted ->
            # Show both "Fill Form" and "Mark Complete" buttons
            button type: "button", class: "btn btn-secondary", onclick: "makeAjaxCall('/applications/#{app.id}/retry', this)" do
              "Fill Form"
            end
            button type: "button", class: "btn btn-success", onclick: "makeAjaxCall('/applications/#{app.id}/complete', this)" do
              "Mark Complete"
            end

          app.submitted ->
            # Show "Fill Form" button even when complete
            button type: "button", class: "btn btn-secondary", onclick: "makeAjaxCall('/applications/#{app.id}/retry', this)" do
              "Fill Form"
            end

          app.errors ->
            button type: "button", class: "btn btn-warning", onclick: "makeAjaxCall('/applications/#{app.id}/retry', this)" do
              "Retry"
            end

          true ->
            button type: "button", class: "btn btn-secondary", onclick: "makeAjaxCall('/applications/#{app.id}/retry', this)" do
              "Continue"
            end
        end

        # Reject button - always show
        button type: "button", class: "btn btn-danger", onclick: "handleReject(\"#{app.id}\", this)" do
          "Reject"
        end
      end
    end
  end

  defp filter_button(label, filter_value, current_filter) do
    temple do
      if filter_value == current_filter do
        span class: "btn btn-filter btn-filter-active" do
          "#{label}"
        end
      else
        href = if filter_value == :all, do: "/", else: "/?filter=#{filter_value}"
        a href: href, class: "btn btn-filter" do
          "#{label}"
        end
      end
    end
  end

  defp status_badge(status) do
    temple do
      if status do
        span class: "status-badge status-success", do: "✓"
      else
        span class: "status-badge status-pending", do: "○"
      end
    end
  end
end
