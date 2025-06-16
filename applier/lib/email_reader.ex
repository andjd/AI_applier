defmodule EmailReader do
  @moduledoc """
  IMAP email reader for detecting job applications with real-time processing
  """

  use GenServer
  require Logger

  @state_file "email_reader_state.json"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start do
    case start_link() do
      {:ok, pid} ->
        GenServer.call(pid, :start_processing)
      error -> error
    end
  end

  def init(_opts) do
    {:ok, %{
      imap_pid: nil,
      processed_uids: load_processed_uids(),
      last_run: load_last_run_time()
    }}
  end

  def handle_call(:start_processing, _from, state) do
    with {:ok, config} <- get_email_config(),
         {:ok, imap_pid} <- connect_to_imap(config) do
      IO.puts("Connected to IMAP server successfully")

      new_state = %{state | imap_pid: imap_pid}

      # Process emails since last run
      case process_emails_since_last_run(new_state) do
        {:ok, updated_state} ->
          # Start IDLE mode for real-time processing
          start_idle_mode(updated_state)
          {:reply, {:ok, :started}, updated_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:error, reason} ->
        IO.puts("Failed to start email reader: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info({:eximap, _pid, :idle_update, updates}, state) do
    IO.puts("Received IDLE update: #{inspect(updates)}")

    # Process new messages in real-time
    updated_state = process_new_messages(state, updates)

    {:noreply, updated_state}
  end

  defp get_email_config do
    with {:ok, server} <- System.fetch_env("EMAIL_IMAP_SERVER"),
         {:ok, port_str} <- System.fetch_env("EMAIL_IMAP_PORT"),
         {:ok, username} <- System.fetch_env("EMAIL_USERNAME"),
         {:ok, password} <- System.fetch_env("EMAIL_PASSWORD") do
      {port, _} = Integer.parse(port_str)

      config = %{
        server: server,
        port: port,
        username: username,
        password: password
      }

      {:ok, config}
    else
      :error ->
        {:error, "Missing required EMAIL_ environment variables"}
    end
  end

  defp connect_to_imap(%{server: server, port: port, username: username, password: password}) do
    IO.puts("Connecting to IMAP server: #{server}:#{port}")

    with {:ok, pid} <- Eximap.start_link(server, port, username, password, [:ssl]),
         :ok <- Eximap.select(pid, "INBOX") do
      {:ok, pid}
    else
      {:error, reason} ->
        IO.puts("IMAP connection failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_emails_since_last_run(state) do
    IO.puts("Processing emails since last run...")

    search_criteria = case state.last_run do
      nil ->
        IO.puts("First run - checking last 5 days")
        "SINCE #{format_date_for_search(days_ago(5))}"
      last_run ->
        IO.puts("Last run: #{last_run}")
        "SINCE #{format_date_for_search(last_run)}"
    end

    with {:ok, message_uids} <- Eximap.uid_search(state.imap_pid, search_criteria) do
      new_uids = message_uids -- state.processed_uids
      IO.puts("Found #{length(new_uids)} new messages to process")

      # Process new messages
      Enum.each(new_uids, fn uid ->
        process_email_stub(state.imap_pid, uid)
      end)

      # Update state
      updated_state = %{state |
        processed_uids: state.processed_uids ++ new_uids,
        last_run: DateTime.utc_now()
      }

      save_state(updated_state)
      {:ok, updated_state}
    else
      {:error, reason} ->
        IO.puts("Failed to search emails: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp start_idle_mode(state) do
    IO.puts("Starting IDLE mode for real-time email processing...")

    case Eximap.idle(state.imap_pid) do
      :ok ->
        IO.puts("IDLE mode started successfully")
      {:error, reason} ->
        IO.puts("Failed to start IDLE mode: #{inspect(reason)}")
    end
  end

  defp process_new_messages(state, updates) do
    # Extract new message UIDs from IDLE updates
    new_uids = extract_new_uids(updates)
    unprocessed_uids = new_uids -- state.processed_uids

    if length(unprocessed_uids) > 0 do
      IO.puts("Processing #{length(unprocessed_uids)} new messages from IDLE")

      Enum.each(unprocessed_uids, fn uid ->
        process_email_stub(state.imap_pid, uid)
      end)

      updated_state = %{state |
        processed_uids: state.processed_uids ++ unprocessed_uids,
        last_run: DateTime.utc_now()
      }

      save_state(updated_state)
      updated_state
    else
      state
    end
  end

  defp extract_new_uids(updates) do
    # Parse IDLE updates to extract new message UIDs
    # This is a simplified implementation - actual parsing depends on Eximap's update format
    case updates do
      messages when is_list(messages) ->
        Enum.flat_map(messages, fn
          {:exists, uid} -> [uid]
          _ -> []
        end)
      _ -> []
    end
  end

  defp process_email_stub(imap_pid, uid) do
    IO.puts("📧 Processing email UID: #{uid}")

    with {:ok, envelope_data} <- Eximap.uid_fetch(imap_pid, uid, "ENVELOPE"),
         {:ok, header_data} <- Eximap.uid_fetch(imap_pid, uid, "BODY[HEADER]"),
         {:ok, body_data} <- Eximap.uid_fetch(imap_pid, uid, "BODY[TEXT]") do
      
      email_data = %{
        uid: uid,
        from: extract_sender_from_envelope(envelope_data),
        subject: extract_subject_from_envelope(envelope_data),
        headers: header_data,
        body: body_data,
        envelope: envelope_data
      }
      
      route_email(email_data)
    else
      {:error, reason} ->
        IO.puts("  ❌ Failed to fetch email data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp route_email(%{from: from} = email_data) do
    IO.puts("  📬 Routing email from: #{from}")
    
    case from do
      "jobalerts-noreply@linkedin.com" ->
        IO.puts("  🔗 Forwarding to LinkedIn handler")
        Email.Linkedin.handle(email_data)
      
      _ ->
        IO.puts("  ⚠️  Unable to process email")
        IO.puts("    Sender: #{from}")
        IO.puts("    Subject: #{email_data.subject}")
        Logger.warn("Unable to process email from #{from} with subject: #{email_data.subject}")
        {:ok, :unhandled}
    end
  end

  defp extract_sender_from_envelope(envelope_data) do
    # Parse envelope data to extract sender
    # Envelope format varies, but typically contains from field
    case Regex.run(~r/from.*?([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/i, envelope_data) do
      [_, email] -> String.downcase(String.trim(email))
      _ -> 
        # Fallback: try to extract any email pattern
        case Regex.run(~r/([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/, envelope_data) do
          [_, email] -> String.downcase(String.trim(email))
          _ -> "unknown@unknown.com"
        end
    end
  end

  defp extract_subject_from_envelope(envelope_data) do
    # Parse envelope data to extract subject
    case Regex.run(~r/subject[:\s]+(.+?)(?:\r?\n|$)/i, envelope_data) do
      [_, subject] -> String.trim(subject)
      _ -> "No Subject"
    end
  end

  # State management functions
  defp load_processed_uids do
    case File.read(@state_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"processed_uids" => uids}} -> uids
          _ -> []
        end
      _ -> []
    end
  end

  defp load_last_run_time do
    case File.read(@state_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"last_run" => timestamp}} ->
            case DateTime.from_iso8601(timestamp) do
              {:ok, datetime, _} -> datetime
              _ -> nil
            end
          _ -> nil
        end
      _ -> nil
    end
  end

  defp save_state(state) do
    state_data = %{
      processed_uids: state.processed_uids,
      last_run: DateTime.to_iso8601(state.last_run)
    }

    case Jason.encode(state_data) do
      {:ok, json} ->
        File.write(@state_file, json)
      {:error, reason} ->
        IO.puts("Failed to save state: #{inspect(reason)}")
    end
  end

  # Utility functions
  defp days_ago(days) do
    DateTime.utc_now()
    |> DateTime.add(-days * 24 * 60 * 60, :second)
  end

  defp format_date_for_search(datetime) do
    datetime
    |> DateTime.to_date()
    |> Date.to_string()
  end
end
