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

  > **Migration Note:** This module was ported from Gleam to pure Elixir in v0.53.0.
  > The API remains unchanged.
  """

  alias Yog.Model

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

    nodes = Model.all_nodes(graph)

    if nodes == [] do
      nil
    else
      eccentricities =
        nodes
        |> Enum.map(fn node ->
          case eccentricity(graph, node,
                 with_zero: zero,
                 with_add: add,
                 with_compare: compare,
                 with: weight_fn
               ) do
            nil -> nil
            ecc -> ecc
          end
        end)
        |> Enum.reject(&is_nil/1)

      if eccentricities == [] do
        nil
      else
        Enum.reduce(eccentricities, fn ecc, max_ecc ->
          if compare.(ecc, max_ecc) == :gt, do: ecc, else: max_ecc
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

    nodes = Model.all_nodes(graph)

    if nodes == [] do
      nil
    else
      eccentricities =
        nodes
        |> Enum.map(fn node ->
          case eccentricity(graph, node,
                 with_zero: zero,
                 with_add: add,
                 with_compare: compare,
                 with: weight_fn
               ) do
            nil -> nil
            ecc -> ecc
          end
        end)
        |> Enum.reject(&is_nil/1)

      if eccentricities == [] do
        nil
      else
        Enum.reduce(eccentricities, fn ecc, min_ecc ->
          if compare.(ecc, min_ecc) == :lt, do: ecc, else: min_ecc
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

    all_nodes = Model.all_nodes(graph)
    num_nodes = length(all_nodes)

    if num_nodes <= 1 do
      zero
    else
      # Apply weight function to all edges and run Dijkstra
      distances = dijkstra_single_source(graph, node, zero, add, compare, weight_fn)

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

    # Calculate degrees for all nodes
    degrees =
      Enum.reduce(nodes, %{}, fn node, acc ->
        degree = length(Model.neighbors(graph, node))
        Map.put(acc, node, degree)
      end)

    # Collect edges with their degree pairs
    edges_data =
      Enum.flat_map(nodes, fn u ->
        Model.successors(graph, u)
        |> Enum.map(fn {v, _weight} ->
          du = Map.get(degrees, u, 0)
          dv = Map.get(degrees, v, 0)
          {du, dv}
        end)
      end)

    if edges_data == [] do
      0.0
    else
      m = length(edges_data) * 1.0

      sum_jk =
        Enum.reduce(edges_data, 0.0, fn {j, k}, acc ->
          acc + j * k * 1.0
        end)

      sum_j =
        Enum.reduce(edges_data, 0.0, fn {j, _}, acc ->
          acc + j * 1.0
        end)

      sum_k =
        Enum.reduce(edges_data, 0.0, fn {_, k}, acc ->
          acc + k * 1.0
        end)

      sum_j_squared =
        Enum.reduce(edges_data, 0.0, fn {j, _}, acc ->
          acc + j * j * 1.0
        end)

      sum_k_squared =
        Enum.reduce(edges_data, 0.0, fn {_, k}, acc ->
          acc + k * k * 1.0
        end)

      numerator = sum_jk / m - sum_j / m * (sum_k / m)

      denom_j = sum_j_squared / m - sum_j / m * (sum_j / m)
      denom_k = sum_k_squared / m - sum_k / m * (sum_k / m)

      denominator = :math.sqrt(denom_j * denom_k)

      if denominator > 0.0 do
        numerator / denominator
      else
        0.0
      end
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

    nodes = Model.all_nodes(graph)
    num_nodes = length(nodes)

    if num_nodes <= 1 do
      nil
    else
      # Calculate all-pairs shortest paths
      all_distances =
        Enum.map(nodes, fn source ->
          dijkstra_single_source(graph, source, zero, add, compare, weight_fn)
        end)

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

  # =============================================================================
  # Internal Dijkstra Implementation
  # =============================================================================

  # Single-source shortest paths using Dijkstra's algorithm
  # Returns a map of node_id => distance
  defp dijkstra_single_source(graph, source, zero, add, compare, weight_fn) do
    # Priority queue as sorted list: [{distance, node_id}]
    initial_pq = [{zero, source}]
    initial_distances = %{source => zero}

    do_dijkstra(graph, initial_pq, initial_distances, add, compare, weight_fn)
  end

  defp do_dijkstra(_graph, [], distances, _add, _compare, _weight_fn) do
    distances
  end

  defp do_dijkstra(graph, [{dist, node} | rest_pq], distances, add, compare, weight_fn) do
    # Check if we've already found a better path to this node
    current_best = Map.get(distances, node)

    if compare.(dist, current_best) == :gt do
      # This entry is outdated, skip it
      do_dijkstra(graph, rest_pq, distances, add, compare, weight_fn)
    else
      # Relax neighbors
      neighbors = Model.successors(graph, node)

      {new_pq, new_distances} =
        Enum.reduce(neighbors, {rest_pq, distances}, fn {neighbor, weight}, {pq, dists} ->
          new_dist = add.(dist, weight_fn.(weight))

          case Map.fetch(dists, neighbor) do
            :error ->
              # First time visiting this node
              new_dists = Map.put(dists, neighbor, new_dist)
              new_pq = insert_sorted(pq, {new_dist, neighbor}, compare)
              {new_pq, new_dists}

            {:ok, old_dist} ->
              if compare.(new_dist, old_dist) == :lt do
                new_dists = Map.put(dists, neighbor, new_dist)
                new_pq = insert_sorted(pq, {new_dist, neighbor}, compare)
                {new_pq, new_dists}
              else
                {pq, dists}
              end
          end
        end)

      do_dijkstra(graph, new_pq, new_distances, add, compare, weight_fn)
    end
  end

  # Insert into sorted priority queue (min-heap based on distance)
  defp insert_sorted([], item, _compare), do: [item]

  defp insert_sorted([{dist, _} | _] = list, {new_dist, _} = item, compare) do
    if compare.(new_dist, dist) == :lt or compare.(new_dist, dist) == :eq do
      [item | list]
    else
      [hd(list) | insert_sorted(tl(list), item, compare)]
    end
  end
end
