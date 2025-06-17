defmodule EmailReader do
  @moduledoc """
  Email reader for detecting job applications with real-time processing using Yugo
  """

  use GenServer
  require Logger

  @state_file "email_reader_state.json"
  @client_name :email_reader_client

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
      client_name: @client_name,
      processed_messages: load_processed_messages(),
      last_run: load_last_run_time()
    }}
  end

  def handle_call(:start_processing, _from, state) do
    with {:ok, config} <- get_email_config(),
         {:ok, _client_pid} <- start_yugo_client(config) do
      IO.puts("Connected to IMAP server successfully")

      # Subscribe to receive email notifications
      case Yugo.subscribe(state.client_name) do
        :ok ->
          IO.puts("Subscribed to email notifications")
          {:reply, {:ok, :started}, state}
        other_response ->
          IO.puts("Failed to subscribe to email notifications: #{inspect(other_response)}")
          {:reply, {:error, other_response}, state}
      end
    else
      {:error, reason} ->
        IO.puts("Failed to start email reader: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info({:email, client, message}, state) do
    IO.puts("Received new email from #{client}")

    # Check if we've already processed this message
    message_id = message.message_id

    if message_id not in state.processed_messages do
      IO.puts("📧 Processing new email: #{message.subject}")

      # Process the email
      process_email(message)

      # Update state
      updated_state = %{state |
        processed_messages: [message_id | state.processed_messages],
        last_run: DateTime.utc_now()
      }

      save_state(updated_state)
      {:noreply, updated_state}
    else
      IO.puts("📧 Email already processed, skipping")
      {:noreply, state}
    end
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

  defp start_yugo_client(%{server: server, port: port, username: username, password: password}) do
    IO.puts("Starting Yugo client for IMAP server: #{server}:#{port}")

    client_spec = {
      Yugo.Client,
      name: @client_name,
      server: server,
      port: port,
      username: username,
      password: password,
      tls: true,
      mailbox: "INBOX"
    }

    case DynamicSupervisor.start_child(:yugo_supervisor, client_spec) do
      {:ok, pid} ->
        IO.puts("Yugo client started successfully")
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        IO.puts("Yugo client already running")
        {:ok, pid}
      {:error, reason} ->
        IO.puts("Failed to start Yugo client: #{inspect(reason)}")
        {:error, reason}
    end
  end


  defp get_sender_email(from) when is_list(from) do
    case List.first(from) do
      %{address: address} -> address
      %{email: email} -> email
      email when is_binary(email) -> email
      _ -> "unknown"
    end
  end
  defp get_sender_email(from) when is_map(from) do
    case from do
      %{address: address} -> address
      %{email: email} -> email
      _ -> "unknown"
    end
  end
  defp get_sender_email(from) when is_binary(from), do: from
  defp get_sender_email(_), do: "unknown"

  defp process_email(message) do
    sender_email = get_sender_email(message.from)

    email_data = %{
      from: sender_email,
      subject: message.subject,
      body: extract_message_body(message),
      date: message.date
    }

    route_email(email_data)
  end

  defp extract_message_body(message) do
    case message.body do
      # Multi-part message - Yugo provides list of tuples
      parts when is_list(parts) ->
        find_text_plain_part(parts)
      # Single part message
      %{content: content} -> content
      # Raw string content
      content when is_binary(content) -> content
      _ -> ""
    end
  end

  defp find_text_plain_part(parts) do
    case Enum.find(parts, fn {content_type, _headers, _content} ->
      content_type == "text/plain"
    end) do
      {"text/plain", _headers, content} -> content
      _ -> ""
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
        Logger.warning("Unable to process email from #{from} with subject: #{email_data.subject}")
        {:ok, :unhandled}
    end
  end


  # State management functions
  defp load_processed_messages do
    case File.read(@state_file) do
      {:ok, content} ->
        case JSON.decode(content) do
          {:ok, %{"processed_messages" => messages}} -> messages
          _ -> []
        end
      _ -> []
    end
  end

  defp load_last_run_time do
    case File.read(@state_file) do
      {:ok, content} ->
        case JSON.decode(content) do
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
      processed_messages: state.processed_messages,
      last_run: DateTime.to_iso8601(state.last_run)
    }

    json = JSON.encode!(state_data)
    File.write(@state_file, json)

  end
end
