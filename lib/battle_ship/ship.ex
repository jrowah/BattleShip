defmodule BattleShip.Ship do
  @moduledoc """
  Represents a game ship
  """
  alias __MODULE__
  alias BattleShip.Coordinate

  @enforce_keys [:coordinates, :hit_coordinates]
  defstruct @enforce_keys

  @type t() :: %__MODULE__{
          coordinates: coordinates(),
          hit_coordinates: coordinates()
        }

  @typedoc """
  Represents all of the possible types of ships in a BattleShip game
  """
  @type ship_type :: :square | :atoll | :dot | :l_shape | :s_shape

  @typedoc """
  Represents a coordinate offset that can be used to offset a specific
  coordinate from some origin
  """
  @type offset :: {pos_integer(), pos_integer()}

  @typedoc """
  Represents a collection of coordinates, which is a `MapSet` consisting
  of elements of type `t()` to help when processing coordinates as opposed
  to a `list` or `map`
  """
  @type coordinates :: MapSet.t(Coordinate.t()) | MapSet.t()

  @doc """
  Creates a new game ship.

  Returns `%{:ok, %BattleShip.Ship{}}`.

  ## Examples

      iex> BattleShip.Ship.new()
      %{}

  """
  @spec new(ship_type() | any(), Coordinate.t()) ::
          {:ok, __MODULE__.t()} | {:error, :invalid_ship_type | :invalid_coordinate}
  def new(type, %Coordinate{} = upper_left) do
    with [{_, _} | _] = offsets <- offsets(type),
         {:ok, coordinates} <- add_coordinates(offsets, upper_left) do
      {:ok, %Ship{coordinates: coordinates, hit_coordinates: MapSet.new()}}
    end
  end

  # Generates a list of offsets for the given ship type
  defp offsets(:square), do: [{0, 0}, {0, 1}, {1, 0}, {1, 1}]

  defp offsets(:atoll), do: [{0, 0}, {0, 1}, {1, 1}, {2, 0}, {2, 1}]

  defp offsets(:dot), do: [{0, 0}]

  defp offsets(:l_shape), do: [{0, 0}, {1, 0}, {2, 0}, {2, 1}]

  defp offsets(:s_shape), do: [{0, 1}, {0, 2}, {1, 0}, {1, 1}]

  defp offsets(_), do: {:error, :invalid_ship_type}

  # Converts a list of coordinate offsets into absolute coordinates for a ship.
  # Uses reduce_while to accumulate coordinates, halting early if any offset
  # produces an invalid coordinate (outside board boundaries).
  # Returns {:ok, coordinates} with all valid ship coordinates, or {:error, :invalid_coordinate}
  defp add_coordinates(offsets, upper_left) do
    reduce_while_results =
      Enum.reduce_while(offsets, MapSet.new(), fn ship_type, coordinates ->
        add_coordinate(coordinates, upper_left, ship_type)
      end)

    case reduce_while_results do
      {:error, :invalid_coordinate} = error -> error
      coordinates -> {:ok, coordinates}
    end
  end

  # Calculates an absolute coordinate by adding the offset to the upper_left corner.
  # Returns {:cont, updated_coordinates} to continue the reduction if the new coordinate is valid.
  # Returns {:halt, error} to immediately stop the reduction if the calculated coordinate is invalid
  # (e.g., row/col out of bounds). This short-circuits the process to avoid unnecessary calculations.
  defp add_coordinate(coordinates, %Coordinate{row: row, col: col}, {row_offset, col_offset}) do
    case Coordinate.new(row + row_offset, col + col_offset) do
      {:ok, coordinate} ->
        {:cont, MapSet.put(coordinates, coordinate)}

      {:error, :invalid_coordinate} = error ->
        {:halt, error}
    end
  end

  @doc """
  Tests whether two ships have overlapping coordinates or not
  """
  @spec overlaps?(__MODULE__.t(), __MODULE__.t()) :: boolean()
  def overlaps?(existing_ship, new_ship), do: not MapSet.disjoint?(existing_ship.coordinates, new_ship.coordinates)

  @doc """
  Determines whether a coordinate is a hit for a given ship. If so, the ship's
  hit coordinates are updated.
  """

  @spec guess(__MODULE__.t(), Coordinate.t()) :: {:hit, __MODULE__.t()} | :miss
  def guess(ship, coordinate) do
    if MapSet.member?(ship.coordinates, coordinate) do
      hit_coordinates = MapSet.put(ship.hit_coordinates, coordinate)
      {:hit, %{ship | hit_coordinates: hit_coordinates}}
    else
      :miss
    end
  end

  @spec sunk?(__MODULE__.t()) :: boolean()
  def sunk?(ship), do: MapSet.equal?(ship.coordinates, ship.hit_coordinates)

  @doc """
  Returns a list of all the possible ship types
  """

  @spec types() :: [ship_type()]
  def types, do: [:atoll, :dot, :l_shape, :s_shape, :square]

  @doc """
  Compares two ships
  """
  @spec equal?(__MODULE__.t(), __MODULE__.t()) :: boolean()
  def equal?(%__MODULE__{coordinates: coordinates_1, hit_coordinates: hit_coordinates_1}, %__MODULE__{
        coordinates: coordinates_2,
        hit_coordinates: hit_coordinates_2
      }) do
    MapSet.equal?(coordinates_1, coordinates_2) and
      MapSet.equal?(hit_coordinates_1, hit_coordinates_2)
  end
end
