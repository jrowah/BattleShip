defmodule BattleShip.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: BattleShip.Worker.start_link(arg)
      # {BattleShip.Worker, arg}
      {Registry, keys: :unique, name: Registry.Game},
      {BattleShip.GameSupervisor, []}
    ]

    # starts an ets table we will use to store game state and retrieve in case a game process crashes and is recovered.
    :ets.new(:game_state, [:public, :named_table])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BattleShip.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
