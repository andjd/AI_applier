defmodule Applier.Application do
  @moduledoc """
  The main application supervisor for the AI job applier.
  """
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Applier.JobRegistry},
      Applier.BrowserPool,
      Applier.JobManager
    ]

    opts = [strategy: :one_for_one, name: Applier.Supervisor]
    Supervisor.start_link(children, opts)
  end
end