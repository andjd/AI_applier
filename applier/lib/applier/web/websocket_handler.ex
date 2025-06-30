defmodule Applier.Web.WebSocketHandler do
  @moduledoc """
  WebSocket handler for broadcasting live application status updates.
  """

  @behaviour WebSock

  require Logger

  @impl WebSock
  def init(state) do
    Logger.info("WebSocket connection established")

    # Subscribe to application updates
    :ok = Phoenix.PubSub.subscribe(Applier.PubSub, "application_updates")

    {:ok, state}
  end

  @impl WebSock
  def handle_in({json, _opts}, state) do
    case JSON.decode(json) do
      {:ok, %{"type" => "ping"}} ->
        response = JSON.encode!(%{type: "pong"})
        {:push, {:text, response}, state}

      {:ok, message} ->
        Logger.debug("Received WebSocket message: #{inspect(message)}")
        {:ok, state}

      {:error, _} ->
        Logger.warn("Invalid JSON received: #{json}")
        {:ok, state}
    end
  end

  @impl WebSock
  def handle_info({:application_update, application_id, status, message}, state) do
    response = JSON.encode!(%{
      type: "application_update",
      application_id: application_id,
      status: status,
      message: message,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    {:push, {:text, response}, state}
  end

  def handle_info(info, state) do
    Logger.debug("Unhandled WebSocket info: #{inspect(info)}")
    {:ok, state}
  end

  @impl WebSock
  def terminate(reason, _state) do
    Logger.info("WebSocket connection terminated: #{inspect(reason)}")
    :ok
  end
end
