defmodule Yog.Health do
  @moduledoc """
  Network health and structural quality metrics.

  These metrics measure the overall "health" and structural properties
  of your graph, including size, compactness, and connectivity patterns.

  ## Overview

  | Metric | Function | Measures |
  |--------|----------|----------|
  | Diameter | `diameter/2` | Maximum distance (worst-case reachability) |
  | Radius | `radius/2` | Minimum eccentricity (best central point) |
  | Eccentricity | `eccentricity/3` | Maximum distance from a node |
  | Assortativity | `assortativity/1` | Degree correlation (homophily) |
  | Average Path Length | `average_path_length/2` | Typical separation |

  ## Example

      # Check graph compactness
      diam = Yog.Health.diameter(graph, opts)
      rad = Yog.Health.radius(graph, opts)

      # Small diameter = well-connected
      # High assortativity = nodes cluster with similar nodes
      assort = Yog.Health.assortativity(graph)
  """

  @doc """
  The diameter is the maximum eccentricity (longest shortest path).
  Returns `nil` if the graph is disconnected or empty.

  **Time Complexity:** O(V × (V+E) log V)

  ## Options

  - `:with_zero` - The zero value for the weight type (e.g., `0` for integers)
  - `:with_add` - Function to add two weights (e.g., `&Kernel.+/2`)
  - `:with_compare` - Function comparing two weights returning `:lt`, `:eq`, or `:gt`
  - `:with` - Function to extract/transform edge weight

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_node(4, "D")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
      iex> opts = [
      ...>   with_zero: 0,
      ...>   with_add: &Kernel.+/2,
      ...>   with_compare: fn a, b ->
      ...>     cond do a < b -> :lt; a > b -> :gt; true -> :eq end
      ...>   end,
      ...>   with: &Function.identity/1
      ...> ]
      iex> Yog.Health.diameter(graph, opts)
      3
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

  **Time Complexity:** O(V × (V+E) log V)

  ## Options

  - `:with_zero` - The zero value for the weight type
  - `:with_add` - Function to add two weights
  - `:with_compare` - Function comparing two weights returning `:lt`, `:eq`, or `:gt`
  - `:with` - Function to extract/transform edge weight

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "center")
      ...>   |> Yog.add_node(2, "A")
      ...>   |> Yog.add_node(3, "B")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {1, 3, 1}])
      iex> opts = [
      ...>   with_zero: 0,
      ...>   with_add: &Kernel.+/2,
      ...>   with_compare: fn a, b ->
      ...>     cond do a < b -> :lt; a > b -> :gt; true -> :eq end
      ...>   end,
      ...>   with: &Function.identity/1
      ...> ]
      iex> Yog.Health.radius(graph, opts)
      1
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

  **Time Complexity:** O((V+E) log V)

  ## Options

  - `:with_zero` - The zero value for the weight type
  - `:with_add` - Function to add two weights
  - `:with_compare` - Function comparing two weights returning `:lt`, `:eq`, or `:gt`
  - `:with` - Function to extract/transform edge weight

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_node(4, "D")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
      iex> opts = [
      ...>   with_zero: 0,
      ...>   with_add: &Kernel.+/2,
      ...>   with_compare: fn a, b ->
      ...>     cond do a < b -> :lt; a > b -> :gt; true -> :eq end
      ...>   end,
      ...>   with: &Function.identity/1
      ...> ]
      iex> # End nodes have eccentricity 3
      iex> Yog.Health.eccentricity(graph, 1, opts)
      3
      iex> # Middle nodes have eccentricity 2
      iex> Yog.Health.eccentricity(graph, 2, opts)
      2
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

  - **Positive**: high-degree nodes connect to high-degree nodes (assortative)
  - **Negative**: high-degree nodes connect to low-degree nodes (disassortative)
  - **Zero**: random mixing

  **Time Complexity:** O(V+E)

  ## Example

      iex> # Star graph is disassortative (center with high degree connects to leaves with low degree)
      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "center")
      ...>   |> Yog.add_node(2, "A")
      ...>   |> Yog.add_node(3, "B")
      ...>   |> Yog.add_node(4, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {1, 3, 1}, {1, 4, 1}])
      iex> assort = Yog.Health.assortativity(graph)
      iex> assort < 0.0
      true

      iex> # Empty graph returns 0.0
      iex> Yog.Health.assortativity(Yog.undirected())
      0.0
  """
  @spec assortativity(Yog.graph()) :: float()
  def assortativity(graph), do: :yog@health.assortativity(graph)

  @doc """
  Average shortest path length across all node pairs.
  Returns `nil` if the graph is disconnected or empty.
  Requires a function to convert edge weights to Float for averaging.

  **Time Complexity:** O(V × (V+E) log V)

  ## Options

  - `:with_zero` - The zero value for the weight type
  - `:with_add` - Function to add two weights
  - `:with_compare` - Function comparing two weights returning `:lt`, `:eq`, or `:gt`
  - `:with` - Function to extract/transform edge weight
  - `:with_to_float` - Function to convert weight to float

  ## Example

      iex> graph =
      ...>   Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges!([{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> opts = [
      ...>   with_zero: 0,
      ...>   with_add: &Kernel.+/2,
      ...>   with_compare: fn a, b ->
      ...>     cond do a < b -> :lt; a > b -> :gt; true -> :eq end
      ...>   end,
      ...>   with: &Function.identity/1,
      ...>   with_to_float: fn x -> x * 1.0 end
      ...> ]
      iex> avg = Yog.Health.average_path_length(graph, opts)
      iex> # In triangle, average path length is 1.0
      iex> abs(avg - 1.0) < 0.001
      true
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
