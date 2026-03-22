defmodule Yog.Health do
  @moduledoc """
  Network health and structural quality metrics.
  """

  @doc """
  The diameter is the maximum eccentricity (longest shortest path).
  Returns `nil` if the graph is disconnected or empty.
  """
  @spec diameter(Yog.graph(), keyword()) :: term() | nil
  def diameter(graph, opts) do
    zero = Keyword.fetch!(opts, :with_zero)
    add = Keyword.fetch!(opts, :with_add)
    compare = Keyword.fetch!(opts, :with_compare)
    weight_fn = Keyword.fetch!(opts, :with)

    case :yog@health.diameter(graph, zero, add, compare, weight_fn) do
      {:some, d} -> d
      :none -> nil
    end
  end

  @doc """
  The radius is the minimum eccentricity.
  Returns `nil` if the graph is disconnected or empty.
  """
  @spec radius(Yog.graph(), keyword()) :: term() | nil
  def radius(graph, opts) do
    zero = Keyword.fetch!(opts, :with_zero)
    add = Keyword.fetch!(opts, :with_add)
    compare = Keyword.fetch!(opts, :with_compare)
    weight_fn = Keyword.fetch!(opts, :with)

    case :yog@health.radius(graph, zero, add, compare, weight_fn) do
      {:some, r} -> r
      :none -> nil
    end
  end

  @doc """
  Eccentricity is the maximum distance from a node to all other nodes.
  Returns `nil` if the node cannot reach all other nodes.
  """
  @spec eccentricity(Yog.graph(), Yog.node_id(), keyword()) :: term() | nil
  def eccentricity(graph, node, opts) do
    zero = Keyword.fetch!(opts, :with_zero)
    add = Keyword.fetch!(opts, :with_add)
    compare = Keyword.fetch!(opts, :with_compare)
    weight_fn = Keyword.fetch!(opts, :with)

    case :yog@health.eccentricity(graph, node, zero, add, compare, weight_fn) do
      {:some, e} -> e
      :none -> nil
    end
  end

  @doc """
  Assortativity coefficient measures degree correlation.
  """
  @spec assortativity(Yog.graph()) :: float()
  def assortativity(graph), do: :yog@health.assortativity(graph)

  @doc """
  Average shortest path length across all node pairs.
  """
  @spec average_path_length(Yog.graph(), keyword()) :: float() | nil
  def average_path_length(graph, opts) do
    zero = Keyword.fetch!(opts, :with_zero)
    add = Keyword.fetch!(opts, :with_add)
    compare = Keyword.fetch!(opts, :with_compare)
    weight_fn = Keyword.fetch!(opts, :with)
    to_float = Keyword.fetch!(opts, :with_to_float)

    case :yog@health.average_path_length(graph, zero, add, compare, weight_fn, to_float) do
      {:some, avg} -> avg
      :none -> nil
    end
  end
end
