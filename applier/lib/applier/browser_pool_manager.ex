defmodule Applier.BrowserPoolManager do
  @moduledoc """
  GenServer for managing browser worker allocation.
  """
  use GenServer
  require Logger

  defstruct available: [], busy: [], waiting: []

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    pool_size = Keyword.get(opts, :pool_size, 3)
    
    state = %__MODULE__{
      available: [],
      busy: [],
      waiting: []
    }
    
    {:ok, state, {:continue, {:initialize_pool, pool_size}}}
  end

  def handle_continue({:initialize_pool, pool_size}, state) do
    Logger.info("Initializing browser pool with #{pool_size} workers")
    
    available_browsers = for i <- 1..pool_size do
      worker_id = "browser_worker_#{i}"
      case Registry.lookup(Applier.BrowserRegistry, worker_id) do
        [{pid, _}] -> pid
        [] -> 
          Logger.warning("Browser worker #{worker_id} not found in registry")
          nil
      end
    end |> Enum.reject(&is_nil/1)
    
    new_state = %{state | available: available_browsers}
    Logger.info("Browser pool initialized with #{length(available_browsers)} available browsers")
    
    {:noreply, new_state}
  end

  def handle_call(:checkout, from, %{available: []} = state) do
    Logger.info("No browsers available, adding to waiting queue")
    new_state = %{state | waiting: [from | state.waiting]}
    {:noreply, new_state}
  end

  def handle_call(:checkout, _from, %{available: [browser | rest]} = state) do
    Logger.info("Checking out browser: #{inspect(browser)}")
    new_state = %{state | 
      available: rest, 
      busy: [browser | state.busy]
    }
    {:reply, {:ok, browser}, new_state}
  end

  def handle_cast({:checkin, browser_pid}, state) do
    Logger.info("Checking in browser: #{inspect(browser_pid)}")
    
    new_busy = List.delete(state.busy, browser_pid)
    
    case state.waiting do
      [] ->
        new_available = [browser_pid | state.available]
        new_state = %{state | available: new_available, busy: new_busy}
        {:noreply, new_state}
      
      [waiting_client | rest_waiting] ->
        GenServer.reply(waiting_client, {:ok, browser_pid})
        new_state = %{state | 
          busy: [browser_pid | new_busy], 
          waiting: rest_waiting
        }
        {:noreply, new_state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.warning("Browser process #{inspect(pid)} died")
    
    new_available = List.delete(state.available, pid)
    new_busy = List.delete(state.busy, pid)
    
    new_state = %{state | available: new_available, busy: new_busy}
    {:noreply, new_state}
  end
end