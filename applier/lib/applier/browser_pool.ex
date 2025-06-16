defmodule Applier.BrowserPool do
  @moduledoc """
  Supervisor for managing a pool of browser workers.
  """
  use Supervisor
  require Logger

  @pool_size 3

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: Applier.BrowserRegistry},
      {Applier.BrowserPoolManager, pool_size: @pool_size}
    ] ++ browser_workers()

    Supervisor.init(children, strategy: :one_for_one)
  end

  def checkout do
    GenServer.call(Applier.BrowserPoolManager, :checkout)
  end

  def checkin(browser_pid) do
    GenServer.cast(Applier.BrowserPoolManager, {:checkin, browser_pid})
  end

  defp browser_workers do
    for i <- 1..@pool_size do
      worker_id = "browser_worker_#{i}"
      Supervisor.child_spec(
        {Applier.BrowserWorker, worker_id}, 
        id: worker_id
      )
    end
  end
end