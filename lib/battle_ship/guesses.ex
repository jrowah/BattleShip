defmodule BattleShip.Guesses do
  @moduledoc """
  This is the Guesses module.
  """

  alias __MODULE__
  alias BattleShip.Coordinate

  @enforce_keys [:hits, :misses]
  defstruct @enforce_keys

  @typedoc """
  Represents guesses
  """
  @type t() :: %__MODULE__{
          hits: MapSet.t(Coordinate.t()),
          misses: MapSet.t(Coordinate.t())
        }

  @doc """
  Creates a new set of guesses with no hits or misses
  """
  @spec new() :: t()
  def new, do: %Guesses{hits: MapSet.new(), misses: MapSet.new()}

  @doc """
  Adds a coordinate to the guesses depending on whether it's a `:hit` or `:miss`
  """

  @spec add(t(), :hit | :miss, Coordinate.t()) :: t()
  def add(%Guesses{} = guesses, :hit, %Coordinate{} = coordinate) do
    update_in(guesses.hits, &MapSet.put(&1, coordinate))
  end

  def add(%Guesses{} = guesses, :miss, %Coordinate{} = coordinate) do
    update_in(guesses.misses, &MapSet.put(&1, coordinate))
  end
end
