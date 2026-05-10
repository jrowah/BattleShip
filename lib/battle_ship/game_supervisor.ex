defmodule BattleShip.GameSupervisor do
  @moduledoc false
  use DynamicSupervisor

  alias BattleShip.Game

  @doc """
  Starts the `GameSupervisor`
  """
  @spec start_link(any()) :: Supervisor.on_start()
  def start_link(_options) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a ships game with the given `player_1_name` underneath the `GameSupervisor`
  """
  @spec start_game(String.t()) :: DynamicSupervisor.on_start_child()
  def start_game(player_1_name) when is_binary(player_1_name) do
    DynamicSupervisor.start_child(__MODULE__, {Game, player_1_name})
  end

  @doc """
  Stops the ships game that was started with the given `player_1_name`
  """
  @spec stop_game(String.t()) :: :ok | {:error, :not_found}
  def stop_game(player_1_name) when is_binary(player_1_name) do
    :ets.delete(:game_state, player_1_name)
    DynamicSupervisor.terminate_child(__MODULE__, pid_from_name(player_1_name))
  end

  # Find the PID of the process associated with the given `player_1_name`
  @spec pid_from_name(String.t()) :: pid() | nil
  defp pid_from_name(player_1_name) when is_binary(player_1_name) do
    player_1_name
    |> Game.start_via_tuple()
    |> GenServer.whereis()
  end
end
