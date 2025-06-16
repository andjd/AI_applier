#!/usr/bin/env elixir

# OTP-based main script for automated cover letter generation
defmodule OTPMain do
  def put_help() do
    IO.puts("Usage: elixir scripts/otp_main.exs <job_posting_url>")
    IO.puts("   OR: echo \"job description text\" | elixir scripts/otp_main.exs")
    System.halt(1)
  end

  def read_stdin() do
    case IO.read(:stdio, :eof) do
      :eof ->
        IO.puts("Error: No input provided")
        put_help()
      {:error, reason} ->
        IO.puts("Error reading from stdin: #{reason}")
        System.halt(1)
      input when is_binary(input) ->
        trimmed = String.trim(input)
        if String.length(trimmed) == 0 do
          IO.puts("Error: Empty input provided")
          put_help()
        else
          trimmed
        end
    end
  end

  def parse_input() do
    case System.argv() do
      [] -> {:text, read_stdin()}
      [url | _] -> {:url, url}
    end
  end

  def run do
    {input_source, input_value} = parse_input()
    Mix.Task.run("loadconfig")

    # Start the application
    Application.ensure_all_started(:applier)

    IO.puts("Starting job application process...")
    IO.puts("Input source: #{input_source}")
    
    case Applier.start_job(input_source, input_value) do
      {:ok, job_id, _pid} ->
        IO.puts("Job started with ID: #{job_id}")
        monitor_job(job_id)
      {:error, reason} ->
        IO.puts("Failed to start job: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp monitor_job(job_id) do
    case Applier.get_job_status(job_id) do
      :completed ->
        IO.puts("✓ Job completed successfully!")
        
      :error ->
        case Applier.get_job_progress(job_id) do
          %{error: error} ->
            IO.puts("✗ Job failed: #{error}")
            System.halt(1)
          _ ->
            IO.puts("✗ Job failed with unknown error")
            System.halt(1)
        end
        
      status ->
        IO.puts("Job status: #{status}")
        Process.sleep(2000)
        monitor_job(job_id)
    end
  end
end

OTPMain.run()