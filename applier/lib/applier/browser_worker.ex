defmodule Applier.BrowserWorker do
  @moduledoc """
  GenServer for managing individual browser instances.
  """
  use GenServer
  require Logger

  defstruct [:worker_id, :browser, :status]

  def start_link(worker_id) do
    GenServer.start_link(__MODULE__, worker_id, name: via_tuple(worker_id))
  end

  def get_browser(worker_id) do
    GenServer.call(via_tuple(worker_id), :get_browser)
  end

  def init(worker_id) do
    Logger.info("Starting browser worker: #{worker_id}")
    
    state = %__MODULE__{
      worker_id: worker_id,
      browser: nil,
      status: :initializing
    }
    
    {:ok, state, {:continue, :launch_browser}}
  end

  def handle_continue(:launch_browser, state) do
    Logger.info("Launching browser for worker: #{state.worker_id}")
    
    case Helpers.Browser.launch() do
      {:ok, browser} ->
        Process.monitor(browser)
        new_state = %{state | browser: browser, status: :ready}
        Logger.info("Browser launched successfully for worker: #{state.worker_id}")
        {:noreply, new_state}
      
      {:error, reason} ->
        Logger.error("Failed to launch browser for worker #{state.worker_id}: #{reason}")
        {:stop, {:failed_to_launch, reason}, state}
    end
  end

  def handle_call(:get_browser, _from, %{status: :ready} = state) do
    {:reply, {:ok, state.browser}, state}
  end

  def handle_call(:get_browser, _from, state) do
    {:reply, {:error, :not_ready}, state}
  end

  def handle_info({:DOWN, _ref, :process, browser_pid, reason}, %{browser: browser_pid} = state) do
    Logger.warning("Browser process died for worker #{state.worker_id}: #{inspect(reason)}")
    
    new_state = %{state | browser: nil, status: :restarting}
    {:noreply, new_state, {:continue, :launch_browser}}
  end

  def handle_info({:DOWN, _ref, :process, _other_pid, _reason}, state) do
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info("Browser worker #{state.worker_id} terminating: #{inspect(reason)}")
    
    if state.browser do
      Helpers.Browser.close_browser(state.browser)
    end
    
    :ok
  end

  defp via_tuple(worker_id) do
    {:via, Registry, {Applier.BrowserRegistry, worker_id}}
  end
end