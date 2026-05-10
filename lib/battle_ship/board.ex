defmodule BattleShip.Board do
  @moduledoc """
  Represents a game board
  """

  alias BattleShip.Coordinate
  alias BattleShip.Ship

  @typedoc """
  Represents a game board, which is a map of ships. Each key is an `Ship.ship_type()`.
  """
  @type t() :: %{optional(Ship.ship_type()) => Ship.t()}

  @spec new() :: %{}
  @doc """
  Gives a game board.

  Returns `%{}`.

  ## Examples

      iex> BattleShip.Board.new()
      %{}

  """
  def new, do: %{}

  @spec position_ship(map(), atom(), struct()) :: {:error, :overlapping_ship} | map()
  @doc """
  This function takes a game board, a key, and a ship to be positioned on the board.
  It checks if the new ship overlaps with any existing ships on the board. If there
  is an overlap, it returns `{:error, :overlapping_ship}`. Otherwise, it updates the
  board by adding the new ship at the specified key and returns the updated board.

  ## Examples

  """
  def position_ship(board, key, %Ship{} = ship) do
    if overlaps_existing_ship?(board, key, ship) do
      {:error, :overlapping_ship}
    else
      Map.put(board, key, ship)
    end
  end

  defp overlaps_existing_ship?(board, new_key, new_ship) do
    Enum.any?(board, fn {key, ship} ->
      key != new_key and Ship.overlaps?(ship, new_ship)
    end)
  end

  @spec all_ships_set?(map()) :: boolean()
  def all_ships_set?(board), do: Enum.all?(Ship.types(), &Map.has_key?(board, &1))

  @spec guess(map(), struct()) ::
          {:hit | :miss, boolean(), :no_win | :win, map()} | {:miss, :none, :no_win, map()}
  @doc """
  whether the guess was a hit or a miss, either :none or the type of ship that was sunk, :win or :no_win, and finally the board map itself

  Returns ``.

  ## Examples

      iex> MyApp.Hello.world(:john)
      :ok

  """
  def guess(board, %Coordinate{} = coordinate) do
    board
    |> check_all_ships(coordinate)
    |> guess_response(board)
  end

  defp check_all_ships(board, coordinate) do
    Enum.find_value(board, :miss, fn {key, ship} ->
      case Ship.guess(ship, coordinate) do
        {:hit, ship} -> {key, ship}
        :miss -> false
      end
    end)
  end

  defp guess_response({key, ship}, board) do
    board = %{board | key => ship}
    {:hit, sink_check(board, key), win_check(board), board}
  end

  defp guess_response(:miss, board), do: {:miss, :none, :no_win, board}

  defp sink_check(board, key) do
    if sunk?(board, key) do
      key
    else
      :none
    end
  end

  defp sunk?(board, key) do
    board
    |> Map.fetch!(key)
    |> Ship.sunk?()
  end

  defp win_check(board) do
    if all_sunk(board) do
      :win
    else
      :no_win
    end
  end

  defp all_sunk(board), do: Enum.all?(board, fn {_key, ship} -> Ship.sunk?(ship) end)
end
