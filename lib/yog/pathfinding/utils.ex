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
  """
  @spec path([Yog.node_id()], any()) :: path(any())
  def path(nodes, total_weight) do
    {:path, nodes, total_weight}
  end

  @doc """
  Extracts nodes from a path.
  """
  @spec nodes(path(any())) :: [Yog.node_id()]
  def nodes({:path, nodes, _}), do: nodes

  @doc """
  Extracts total weight from a path.
  """
  @spec total_weight(path(any())) :: any()
  def total_weight({:path, _, weight}), do: weight
end
