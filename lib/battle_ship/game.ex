defmodule BattleShip.Game do
  @moduledoc """
  Client interface functions for an ships game GenServer
  """

  @behaviour Access

  use GenServer,
    restart: :transient,
    shutdown: 5000,
    type: :worker

  import BattleShip.Player, only: [is_player_role: 1]

  alias BattleShip.Board
  alias BattleShip.Coordinate
  alias BattleShip.Guesses
  alias BattleShip.Player
  alias BattleShip.Rules
  alias BattleShip.Ship

  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]},
      restart: :transient,
      shutdown: 5000,
      type: :worker
    }
  end

  @enforce_keys [:player1, :player2, :rules]
  defstruct @enforce_keys

  @type t() :: %__MODULE__{
          player1: Player.t(),
          player2: Player.t(),
          rules: Rules.t()
        }

  # 30 minutes
  @timeout_ms 60 * 60 * 24 * 1000

  @typedoc """
  Represents an integer timeout value in milliseconds
  """
  @type timeout_ms() :: non_neg_integer()

  @typedoc """
  Represents a `:via` tuple for referencing GenServer processes registered
  in `Registry.Game`
  """
  @type via_tuple() :: {:via, Registry, {Registry.Game, String.t()}}

  @typedoc """
  Represents a game reference as either a PID or a `:via` tuple
  """
  @type game_reference() :: pid() | via_tuple()

  # Represents the call messages that can be sent to the game GenServer
  @typep call_messages() ::
           {:add_player, name :: String.t()}
           | {:position_ship, Player.role(), Ship.ship_type(), row :: pos_integer(), column :: pos_integer()}
           | {:set_ships, Player.role()}
           | {:guess_coordinate, Player.role(), row :: pos_integer(), column :: pos_integer()}

  # Tests whether the given `term` is a game reference or not, which means testing whether
  # `term` is a PID or `:via` tuple
  defguard is_game_reference(term)
           when is_pid(term) or
                  (is_tuple(term) and elem(term, 0) == :via and elem(term, 1) == Registry and
                     is_tuple(elem(term, 2)) and
                     elem(elem(term, 2), 0) == :"Elixir.Registry.Game" and
                     is_binary(elem(elem(term, 2), 1)))

  ########################################################################
  #### Client interface ##################################################
  ########################################################################

  @doc """
  Given the player `name`, returns a `Registry` via tuple to be used for registering
  a ships game `GenServer` under `name`. Registers a game process under the given `name` in the `Registry.Game` registry.
  """

  @spec start_via_tuple(String.t()) :: {:via, Registry, {Registry.Game, String.t()}}
  def start_via_tuple(name), do: {:via, Registry, {Registry.Game, name}}

  @doc """
  Starts an ships game GenServer. Is the client function (public interface) that wraps `GenServer.start_link/3` for starting an ships game GenServer process. The GenServer process is registered under the given `name` in the `Registry.Game` registry.
  """
  @spec start_link(String.t()) ::
          {:ok, pid()}
          | {:error, {:already_started, pid()}}
          | {:error, any()}
          | {:stop, any()}
          | :ignore
  def start_link(name) when is_binary(name) do
    GenServer.start_link(__MODULE__, name, name: start_via_tuple(name))
  end

  @doc """
  Adds a second player to the game
  """
  @spec add_player(game_reference(), String.t()) :: :ok | :error
  def add_player(game_reference, name) when is_game_reference(game_reference) and is_binary(name) do
    GenServer.call(game_reference, {:add_player, name})
  end

  @doc """
  Positions a player's ship
  """
  @spec position_ship(
          game_reference(),
          Player.role(),
          Ship.ship_type(),
          pos_integer(),
          pos_integer()
        ) ::
          :ok
          | :error
          | {:error, :invalid_coordinate}
          | {:error, :invalid_ship_type}
          | {:error, :overlapping_ship}
  def position_ship(game_reference, player_role, ship_type, row, column)
      when is_game_reference(game_reference) and is_player_role(player_role) do
    GenServer.call(game_reference, {:position_ship, player_role, ship_type, row, column})
  end

  @doc """
  Sets a player's ship positions and marks them as set.
  """
  @spec set_ships(game_reference(), Player.role()) ::
          :ok | {:ok, Board.t()} | :error | {:error, :not_all_ships_positioned}
  def set_ships(game_reference, player_role) when is_game_reference(game_reference) and is_player_role(player_role),
    do: GenServer.call(game_reference, {:set_ships, player_role})

  @doc """
  Guesses a coordinate for the given player
  """
  @spec guess_coordinate(game_reference(), Player.role(), pos_integer(), pos_integer()) ::
          {:hit | :miss, Ship.ship_type(), :win | :no_win}
          | :error
          | {:error, :invalid_coordinate}
  def guess_coordinate(game_reference, player_role, row, col)
      when is_game_reference(game_reference) and is_player_role(player_role) do
    GenServer.call(game_reference, {:guess_coordinate, player_role, row, col})
  end

  ########################################################################
  #### GenServer callbacks ###############################################
  ########################################################################

  @impl GenServer
  def init(name) do
    send(self(), {:set_state, name})
    {:ok, fresh_state(name)}
  end

  @impl GenServer
  def terminate({:shutdown, :timeout}, state_data) do
    :ets.delete(:game_state, state_data.player1.name)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  @impl GenServer
  @spec handle_call(call_messages(), {pid(), any()}, __MODULE__.t()) ::
          {:reply, __MODULE__.t(), __MODULE__.t(), timeout_ms()}
          | {:reply, :error, __MODULE__.t(), timeout_ms()}
          | {:reply, {:error, :not_all_ships_positioned}, __MODULE__.t(), timeout_ms()}
  def handle_call({:guess_coordinate, player, row, col}, _from, state_data) do
    opponent = opponent(player)
    opponent_board = player_board(state_data, opponent)

    with {:ok, rules} <- Rules.check(state_data.rules, {:guess_coordinate, player}),
         {:ok, coordinate} <- Coordinate.new(row, col),
         {hit_or_miss, sunk_ship, win_status, opponent_board} <-
           Board.guess(opponent_board, coordinate),
         {:ok, rules} <- Rules.check(rules, {:win_check, win_status}) do
      state_data
      |> update_board(opponent, opponent_board)
      |> update_guesses(player, coordinate, hit_or_miss)
      |> update_rules(rules)
      |> reply_success({hit_or_miss, sunk_ship, win_status})
    else
      :error ->
        {:reply, :error, state_data}

      {:error, :invalid_coordinate} ->
        {:reply, {:error, :invalid_coordinate}, state_data}
    end
  end

  def handle_call({:set_ships, player_role}, _from, state_data) do
    board = player_board(state_data, player_role)

    with {:ok, rules} <- Rules.check(state_data.rules, {:set_ships, player_role}),
         true <- Board.all_ships_set?(board) do
      state_data
      |> update_rules(rules)
      |> reply_success({:ok, board})
    else
      :error -> {:reply, :error, state_data, @timeout_ms}
      false -> {:reply, {:error, :not_all_ships_set}, state_data, @timeout_ms}
    end
  end

  def handle_call({:add_player, name}, _from, state_data) do
    case Rules.check(state_data.rules, :add_player) do
      {:ok, rules} ->
        state_data
        |> update_player2_name(name)
        |> update_rules(rules)
        |> reply_success(:ok)

      :error ->
        {:noreply, :error, state_data, @timeout_ms}
    end
  end

  def handle_call({:position_ship, player_role, ship_type, row, col}, _from, state_data) do
    board = player_board(state_data, player_role)

    with {:ok, rules} <- Rules.check(state_data.rules, {:position_ships, player_role}),
         {:ok, coordinate} <- Coordinate.new(row, col),
         {:ok, ship} <- Ship.new(ship_type, coordinate),
         %{} = board <- Board.position_ship(board, ship_type, ship) do
      state_data
      |> update_board(player_role, board)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error = check_error ->
        {:reply, check_error, state_data, @timeout_ms}

      {:error, :invalid_coordinate} = coordinate_new_error ->
        {:reply, coordinate_new_error, state_data, @timeout_ms}

      {:error, :invalid_ship_type} = coordinate_or_ship_new_error ->
        {:reply, coordinate_or_ship_new_error, state_data, @timeout_ms}

      {:error, :overlapping_ship} = position_ship_error ->
        {:reply, position_ship_error, state_data, @timeout_ms}
    end
  end

  @impl GenServer
  def handle_info(:timeout, state_data) do
    {:stop, {:shutdown, :timeout}, state_data}
  end

  def handle_info({:set_state, name}, _state_data) do
    state_data =
      case :ets.lookup(:game_state, name) do
        [] -> fresh_state(name)
        [{_key, state}] -> state
      end

    :ets.insert(:game_state, {name, state_data})
    {:noreply, state_data, @timeout_ms}
  end

  ########################################################################
  #### Access callbacks ##################################################
  ########################################################################

  # The Access behaviour is implemented to support accessing struct key values via the
  # `state.[key]` syntax and to use `update_in` using such syntax as the path.
  # Popping a key from the struct is not supported.

  @impl Access
  def fetch(state, key), do: Map.fetch(state, key)

  @impl Access
  def get_and_update(state, key, update_fun), do: Map.get_and_update(state, key, update_fun)

  @impl Access
  def pop(_state, _key), do: raise(RuntimeError, "#{__MODULE__} does not support popping a key.")

  ########################################################################
  #### Private Functions #################################################
  ########################################################################

  defp update_player2_name(state_data, name), do: put_in(state_data.player2.name, name)

  defp update_rules(state_data, rules), do: %{state_data | rules: rules}

  defp reply_success(state_data, reply) do
    # Update the game state ETS table with the new game state; some state will change whenever there is a successful reply
    :ets.insert(:game_state, {state_data.player1.name, state_data})
    {:reply, reply, state_data, @timeout_ms}
  end

  defp update_board(state_data, player_role, board) do
    # Map.update!(state_data, player_role, fn player -> %{player | board: board} end)
    Map.put(state_data, player_role, %{state_data[player_role] | board: board})
  end

  defp player_board(state_data, player), do: Map.get(state_data, player).board

  defp opponent(:player1), do: :player2
  defp opponent(:player2), do: :player1

  defp update_guesses(state_data, player_role, coordinate, hit_or_miss) do
    update_in(state_data[player_role].guesses, fn guesses ->
      Guesses.add(guesses, hit_or_miss, coordinate)
    end)
  end

  defp fresh_state(name) do
    player1 = %{name: name, board: Board.new(), guesses: Guesses.new()}
    player2 = %{name: nil, board: Board.new(), guesses: Guesses.new()}
    %{player1: player1, player2: player2, rules: %Rules{}}
  end
end
