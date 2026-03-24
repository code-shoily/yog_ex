defmodule Yog.Pathfinding.Utils do
  @moduledoc """
  Shared types and utilities for pathfinding algorithms.
  """

  @typedoc """
  Represents a path through the graph with its total weight.
  """
  @type path(e) :: {:path, [Yog.node_id()], e}

  @doc """
  Creates a path tuple from nodes and total weight.

  ## Examples

      iex> Yog.Pathfinding.Utils.path([:a, :b, :c], 10)
      {:path, [:a, :b, :c], 10}
  """
  @spec path([Yog.node_id()], any()) :: path(any())
  def path(nodes, total_weight) do
    {:path, nodes, total_weight}
  end

  @doc """
  Extracts nodes from a path.

  ## Examples

      iex> path = Yog.Pathfinding.Utils.path([:a, :b, :c], 10)
      iex> Yog.Pathfinding.Utils.nodes(path)
      [:a, :b, :c]
  """
  @spec nodes(path(any())) :: [Yog.node_id()]
  def nodes({:path, nodes, _}), do: nodes

  @doc """
  Extracts total weight from a path.

  ## Examples

      iex> path = Yog.Pathfinding.Utils.path([:a, :b, :c], 10)
      iex> Yog.Pathfinding.Utils.total_weight(path)
      10
  """
  @spec total_weight(path(any())) :: any()
  def total_weight({:path, _, weight}), do: weight
end
