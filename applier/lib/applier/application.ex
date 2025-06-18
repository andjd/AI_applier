defmodule Applier.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Applier.Repo,
      {DynamicSupervisor, name: :yugo_supervisor, strategy: :one_for_one}
    ]

    # Add Bandit web server in dev environment
    children = if Mix.env() == :dev do
      children ++ [
        {Bandit, scheme: :http, plug: Applier.Web.Router, port: 4000, ip: {127, 0, 0, 1}}
      ]
    else
      children
    end

    opts = [strategy: :one_for_one, name: Applier.Supervisor]
    Supervisor.start_link(children, opts)
  end
end