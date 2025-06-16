#!/usr/bin/env elixir

# Load dependencies
Mix.install([
  {:dotenv, "~> 3.0.0"},
  {:eximap, "~> 0.1.2-dev"},
  {:jason, "~> 1.4"}
])

# Load environment variables
Dotenv.load()

# Add lib directory to the code path
Code.append_path("lib")

# Test the email reader
IO.puts("Starting email reader test...")

case EmailReader.start() do
  {:ok, :started} ->
    IO.puts("✅ Email reader started successfully")
    IO.puts("🔄 Now listening for new emails in IDLE mode...")
    IO.puts("💡 Press Ctrl+C to stop")
    
    # Keep the process alive to receive IDLE updates
    Process.sleep(:infinity)
  
  {:error, reason} ->
    IO.puts("❌ Email reader failed: #{reason}")
    System.halt(1)
end