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

  alias Yog.Model
  alias Yog.Pathfinding.Dijkstra
  alias Yog.Transform

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
  def diameter(graph, opts \\ []) do
    zero = opts[:with_zero] || 0
    add = opts[:with_add] || (&Kernel.+/2)
    compare = opts[:with_compare] || (&Yog.Utils.compare/2)
    weight_fn = opts[:with] || (&Function.identity/1)

    # Reweight graph ONCE
    reweighted_graph =
      if weight_fn != (&Function.identity/1),
        do: Transform.map_edges(graph, weight_fn),
        else: graph

    nodes = Model.all_nodes(reweighted_graph)

    if nodes == [] do
      nil
    else
      parallel_opts = [
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      ]

      eccentricities =
        nodes
        |> Task.async_stream(
          fn node ->
            eccentricity(reweighted_graph, node,
              with_zero: zero,
              with_add: add,
              with_compare: compare,
              with: &Function.identity/1
            )
          end,
          parallel_opts
        )
        |> Enum.map(fn {:ok, ecc} -> ecc end)
        |> Enum.reject(&is_nil/1)

      if length(eccentricities) < length(nodes) do
        nil
      else
        Enum.reduce(eccentricities, fn ecc, max ->
          if compare.(ecc, max) == :gt, do: ecc, else: max
        end)
      end
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
  def radius(graph, opts \\ []) do
    zero = opts[:with_zero] || 0
    add = opts[:with_add] || (&Kernel.+/2)
    compare = opts[:with_compare] || (&Yog.Utils.compare/2)
    weight_fn = opts[:with] || (&Function.identity/1)

    # Reweight graph ONCE
    reweighted_graph =
      if weight_fn != (&Function.identity/1),
        do: Transform.map_edges(graph, weight_fn),
        else: graph

    nodes = Model.all_nodes(reweighted_graph)

    if nodes == [] do
      nil
    else
      parallel_opts = [
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      ]

      eccentricities =
        nodes
        |> Task.async_stream(
          fn node ->
            eccentricity(reweighted_graph, node,
              with_zero: zero,
              with_add: add,
              with_compare: compare,
              with: &Function.identity/1
            )
          end,
          parallel_opts
        )
        |> Enum.map(fn {:ok, ecc} -> ecc end)
        |> Enum.reject(&is_nil/1)

      if length(eccentricities) < length(nodes) do
        nil
      else
        Enum.reduce(eccentricities, fn ecc, min ->
          if compare.(ecc, min) == :lt, do: ecc, else: min
        end)
      end
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
  def eccentricity(graph, node, opts \\ []) do
    zero = opts[:with_zero] || 0
    add = opts[:with_add] || (&Kernel.+/2)
    compare = opts[:with_compare] || (&Yog.Utils.compare/2)
    weight_fn = opts[:with] || (&Function.identity/1)

    # Reweight graph if needed (usually already reweighted by callers)
    reweighted_graph =
      if weight_fn != (&Function.identity/1),
        do: Transform.map_edges(graph, weight_fn),
        else: graph

    all_nodes = Model.all_nodes(reweighted_graph)
    num_nodes = length(all_nodes)

    if num_nodes <= 1 do
      zero
    else
      distances = Dijkstra.single_source_distances(reweighted_graph, node, zero, add, compare)

      # Check if all nodes are reachable
      if map_size(distances) < num_nodes do
        nil
      else
        # Find maximum distance
        distances
        |> Map.values()
        |> Enum.reduce(fn dist, max_dist ->
          if compare.(dist, max_dist) == :gt, do: dist, else: max_dist
        end)
      end
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
  def assortativity(graph) do
    nodes = Model.all_nodes(graph)

    # 1. Pre-calculate degrees
    degrees =
      Enum.reduce(nodes, %{}, fn node, acc ->
        deg = map_size(graph.out_edges[node] || %{})
        Map.put(acc, node, deg)
      end)

    edges_data =
      Enum.flat_map(nodes, fn u ->
        Model.successors(graph, u)
        |> Enum.map(fn {v, _weight} ->
          {Map.get(degrees, u, 0), Map.get(degrees, v, 0)}
        end)
      end)

    m = length(edges_data) * 1.0

    if m == 0.0 do
      0.0
    else
      {sum_jk, sum_j_plus_k, sum_j2_plus_k2} =
        Enum.reduce(edges_data, {0.0, 0.0, 0.0}, fn {j, k}, {sjk, sjk_add, sjk2_add} ->
          {
            sjk + j * k,
            sjk_add + (j + k),
            sjk2_add + (j * j + k * k)
          }
        end)

      # Simplified Newman formula for symmetric edge lists
      # r = [ Σ(jk) - (Σ(j+k)/2)^2 / M ] / [ Σ(j^2+k^2)/2 - (Σ(j+k)/2)^2 / M ]

      term1 = sum_j_plus_k / 2.0
      numerator = sum_jk / m - :math.pow(term1 / m, 2)
      denominator = sum_j2_plus_k2 / (2.0 * m) - :math.pow(term1 / m, 2)

      if denominator > 0.0, do: numerator / denominator, else: 0.0
    end
  end

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
  def average_path_length(graph, opts \\ []) do
    zero = opts[:with_zero] || 0
    add = opts[:with_add] || (&Kernel.+/2)
    compare = opts[:with_compare] || (&Yog.Utils.compare/2)
    weight_fn = opts[:with] || (&Function.identity/1)
    to_float = opts[:with_to_float] || fn x -> x * 1.0 end

    # Reweight graph ONCE
    reweighted_graph =
      if weight_fn != (&Function.identity/1),
        do: Transform.map_edges(graph, weight_fn),
        else: graph

    nodes = Model.all_nodes(reweighted_graph)
    num_nodes = length(nodes)

    if num_nodes <= 1 do
      nil
    else
      parallel_opts = [
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      ]

      # Calculate all-pairs shortest paths in parallel
      all_distances =
        nodes
        |> Task.async_stream(
          fn source ->
            Dijkstra.single_source_distances(reweighted_graph, source, zero, add, compare)
          end,
          parallel_opts
        )
        |> Enum.map(fn {:ok, distances} -> distances end)

      # Check if graph is fully connected
      all_reachable =
        Enum.all?(all_distances, fn distances ->
          map_size(distances) == num_nodes
        end)

      if all_reachable do
        # Sum all distances (including self-distances which are zero)
        total =
          Enum.reduce(all_distances, 0.0, fn distances, acc ->
            sum =
              Enum.reduce(distances, 0.0, fn {_node, dist}, sum ->
                sum + to_float.(dist)
              end)

            acc + sum
          end)

        # Subtract self-distances (all zeros) and divide by number of pairs (n * (n-1))
        zero_distances = num_nodes * to_float.(zero) * 1.0
        num_pairs = num_nodes * (num_nodes - 1) * 1.0

        (total - zero_distances) / num_pairs
      else
        nil
      end
    end
  end
end
