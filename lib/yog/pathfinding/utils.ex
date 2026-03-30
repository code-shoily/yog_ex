defmodule Yog.Pathfinding.Utils do
  @moduledoc """
  Shared types and utilities for pathfinding algorithms.

  This module provides compatibility functions that delegate to `Yog.Pathfinding.Path`.
  All new code should use `Yog.Pathfinding.Path` directly.
  """

  alias Yog.Pathfinding.Path

  @typedoc """
  Represents a path through the graph with its total weight.
  Deprecated: Use `Yog.Pathfinding.Path.t()` instead.
  """
  @type path() :: Path.t()

  @doc """
  Creates a new Path struct from nodes and total weight.

  ## Examples

      iex> Yog.Pathfinding.Utils.path([:a, :b, :c], 10)
      %Yog.Pathfinding.Path{nodes: [:a, :b, :c], weight: 10, algorithm: :unknown, metadata: %{}}
  """
  @spec path([Yog.node_id()], any()) :: path()
  def path(nodes, total_weight) do
    Path.new(nodes, total_weight)
  end

  @doc """
  Extracts nodes from a path.

  ## Examples

      iex> path = Yog.Pathfinding.Utils.path([:a, :b, :c], 10)
      iex> Yog.Pathfinding.Utils.nodes(path)
      [:a, :b, :c]
  """
  @spec nodes(path()) :: [Yog.node_id()]
  def nodes(%Path{nodes: nodes}), do: nodes

  @doc """
  Extracts total weight from a path.

  ## Examples

      iex> path = Yog.Pathfinding.Utils.path([:a, :b, :c], 10)
      iex> Yog.Pathfinding.Utils.total_weight(path)
      10
  """
  @spec total_weight(path()) :: any()
  def total_weight(%Path{weight: weight}), do: weight
end
