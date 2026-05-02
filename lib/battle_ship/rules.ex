defmodule BattleShip.Rules do
  @moduledoc """
  This is the Rules module.
  """
  alias __MODULE__
  alias BattleShip.Player

  defstruct state: :initialized,
            player1: :ships_not_set,
            player2: :ships_not_set

  @typedoc """
  Represents the state of a BattleShip game
  """
  @type t() :: %__MODULE__{
          state: state(),
          player1: ships_set_state(),
          player2: ships_set_state()
        }

  @typedoc """
  Represents the state of a BattleShip game
  """
  @type state() ::
          :initialized
          | :players_set
          | :player1_turn
          | :player2_turn
          | :game_over

  @typedoc """
  Represents a BattleShip game action
  """
  @type action() ::
          :add_player
          | {:position_ships, Player.role()}
          | {:set_ships, Player.role()}
          | {:guess_coordinate, Player.role()}
          | {:win_check, :win | :no_win}

  @typedoc """
  Represents whether all ships for a player have been set or not
  """
  @type ships_set_state() ::
          :ships_not_set
          | :ships_set

  @spec new() :: struct()
  @doc """
  Gives game rules.

  Returns `%Rules{}`.

  ## Examples

      iex> BattleShip.Ship.new()
      %BattleShip.Rules{
      state: :initialized,
      player1: :ships_not_set,
      player2: :ships_not_set
      }

  """
  def new, do: %Rules{}

  @doc """
  Checks whether the action is valid for the current state. If so, the action is
  processed and the state updated in a success tuple. Otherwise, an error is returned.
  Gives game rules and transitions states and actions. Pattern matches for the current game state and actions possible in that state.
  For any state/event combination that ends up in catchall, we don’t want to transition the state and so :error is returned.

  Returns `{:ok, rules}`.

  ## Examples

      iex> BattleShip.Ship.check(%Rules{state: :initialized} = rules, :add_player)
      {:ok, %Rules{rules | state: :players_set}}

  """
  @spec check(__MODULE__.t(), action()) :: {:ok, __MODULE__.t()} | :error

  # process adding a player
  def check(%Rules{state: :initialized} = rules, :add_player) do
    {:ok, %Rules{rules | state: :players_set}}
  end

  # process positioning ships
  def check(%Rules{state: :players_set} = rules, {:position_ships, player}) do
    # state remains the same
    case Map.fetch!(rules, player) do
      # can no longer reposition ships
      :ships_set -> :error
      # can still reposition ships
      :ships_not_set -> {:ok, rules}
    end
  end

  # process setting ships
  def check(%Rules{state: :players_set} = rules, {:set_ships, player}) do
    # sets ships for player and moves state if both player's ships are set
    rules = Map.put(rules, player, :ships_set)

    if both_players_ships_set?(rules) do
      {:ok, %{rules | state: :player1_turn}}
    else
      {:ok, rules}
    end
  end

  # # Process player1's guess and transition to player2's turn
  def check(%Rules{state: :player1_turn} = rules, {:guess_coordinate, :player1}),
    do: {:ok, %Rules{rules | state: :player2_turn}}

  # Process if the game is over during player1's turn
  def check(%Rules{state: :player1_turn} = rules, {:win_check, win_or_not}) do
    check_if_game_over(rules, win_or_not)
  end

  # Process player2's guess and transition to player1's turn
  def check(%Rules{state: :player2_turn} = rules, {:guess_coordinate, :player2}),
    do: {:ok, %Rules{rules | state: :player1_turn}}

  # Process if the game is over during player2's turn
  def check(%Rules{state: :player2_turn} = rules, {:win_check, win_or_not}) do
    check_if_game_over(rules, win_or_not)
  end

  # catch all state, eg when player1 tries to guess a coordinate when the state is in player2's turn
  def check(_state, _action), do: :error

  defp both_players_ships_set?(rules), do: rules.player1 == :ships_set && rules.player2 == :ships_set

  # Checks if a game is over or not and returns the appropriate state,
  # transitioning to the game over state if the game is over and otherwise
  # staying in the same state
  defp check_if_game_over(rules, win_or_not) do
    case win_or_not do
      :win -> {:ok, %{rules | state: :game_over}}
      :no_win -> {:ok, rules}
    end
  end
end
