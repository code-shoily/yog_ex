defmodule Yog.Pathfinding.Matrix do
  @moduledoc """
  Optimized distance matrix computation for subsets of nodes.

  This module provides an auto-selecting algorithm for computing shortest path
  distances between specified "points of interest" (POIs) in a graph. It intelligently
  chooses between Floyd-Warshall, Johnson's, and multiple Dijkstra runs based on
  graph characteristics and POI density.

  ## Algorithm Selection

  **With negative weights support** (when `subtract` is provided):

  | Algorithm | When Selected | Complexity |
  |-----------|---------------|------------|
  | [Johnson's](https://en.wikipedia.org/wiki/Johnson%27s_algorithm) | Sparse graphs (E < V²/4) | O(V² log V + VE) then filter |
  | [Floyd-Warshall](https://en.wikipedia.org/wiki/Floyd%E2%80%93Warshall_algorithm) | Dense graphs (E ≥ V²/4) | O(V³) then filter |

  **Without negative weights** (when `subtract` is `nil`):

  | Algorithm | When Selected | Complexity |
  |-----------|---------------|------------|
  | [Dijkstra](https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm) × P | Few POIs (P ≤ V/3) | O(P × (V + E) log V) |
  | [Floyd-Warshall](https://en.wikipedia.org/wiki/Floyd%E2%80%93Warshall_algorithm) | Many POIs (P > V/3) | O(V³) then filter |

  ## Heuristics

  **For graphs with potential negative weights:**
  - Johnson's algorithm is preferred for sparse graphs where E < V²/4
  - Floyd-Warshall is preferred for denser graphs

  **For non-negative weights only:**
  - Multiple Dijkstra runs when P ≤ V/3 (few POIs)
  - Floyd-Warshall when P > V/3 (many POIs)

  ## Use Cases

  - **Game AI**: Pathfinding between key locations (not all nodes)
  - **Logistics**: Distance matrix for delivery stops
  - **Facility location**: Distances between candidate sites
  - **Network analysis**: Selected node pairwise distances

  ## Examples

      # Compute distances only between important waypoints
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 4)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 4, with: 2)
      iex> pois = [1, 2, 4]  # Only care about these 3 nodes
      iex> {:ok, distances} = Yog.Pathfinding.Matrix.distance_matrix(
      ...>   graph, pois, 0, &(&1 + &2), &Yog.Utils.compare/2
      ...> )
      iex> # Distance from 1 to 4 should be 1->2->3->4 = 7
      ...> distances[{1, 4}]
      7
      iex> # Matrix only contains 3×3 = 9 entries
      ...> map_size(distances)
      9

  ## References

  - See `Yog.Pathfinding.FloydWarshall` for all-pairs algorithm details (O(V³))
  - See `Yog.Pathfinding.Johnson` for sparse all-pairs with negative weights (O(V² log V + VE))
  - See `Yog.Pathfinding.Dijkstra` for single-source algorithm details (O((V+E) log V))
  """

  use Yog.Algorithm

  alias Yog.Pathfinding.Dijkstra
  alias Yog.Pathfinding.FloydWarshall
  alias Yog.Pathfinding.Johnson

  @typedoc """
  Distance matrix: map from `{from, to}` tuple to distance.
  """
  @type distance_matrix :: %{{Yog.node_id(), Yog.node_id()} => any()}

  @doc """
  Computes shortest distances between all pairs of points of interest.

  Automatically chooses the best algorithm based on:
  - Whether negative weights are possible (presence of `subtract`)
  - Graph sparsity (E relative to V²)
  - POI density (P relative to V)

  **Time Complexity:** O(V³), O(V² log V + VE), or O(P × (V + E) log V)

  ## Parameters

  - `graph` - The graph to analyze
  - `points_of_interest` - List of node IDs to compute distances between
  - `zero` - Identity element for addition
  - `add` - Function to add two weights
  - `compare` - Function to compare two weights
  - `subtract` - Optional subtraction function for negative weight support.
    If provided, enables Johnson's algorithm for sparse graphs with negative weights.
    If `nil`, assumes non-negative weights and may use Dijkstra.

  ## Examples

      # Non-negative weights only (uses Dijkstra or Floyd-Warshall)
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 4)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> {:ok, distances} = Yog.Pathfinding.Matrix.distance_matrix(
      ...>   graph, [1, 3], 0, &(&1 + &2), &Yog.Utils.compare/2
      ...> )
      iex> distances[{1, 3}]
      5

      # Support negative weights (uses Johnson's or Floyd-Warshall)
      iex> neg_graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 4)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: -2)
      iex> {:ok, distances} = Yog.Pathfinding.Matrix.distance_matrix(
      ...>   neg_graph, [1, 3], 0, &(&1 + &2), &Yog.Utils.compare/2, &(&1 - &2)
      ...> )
      iex> distances[{1, 3}]
      2
  """
  @spec distance_matrix(
          Yog.graph(),
          [Yog.node_id()],
          any(),
          (any(), any() -> any()),
          (any(), any() -> :lt | :eq | :gt),
          (any(), any() -> any()) | nil
        ) :: {:ok, distance_matrix()} | {:error, :negative_cycle}
  def distance_matrix(
        graph,
        points_of_interest,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2,
        subtract \\ nil
      ) do
    poi_set = MapSet.new(points_of_interest)
    node_count = Model.node_count(graph)
    edge_count = Model.edge_count(graph)

    # Check if any POI is not in the graph
    all_nodes = Model.all_nodes(graph)
    all_node_set = MapSet.new(all_nodes)

    _check_pois =
      if not all_in_set?(poi_set, all_node_set) do
        # Some POIs don't exist in graph - still compute for valid ones
        :ok
      end

    if subtract != nil do
      # Negative weight support needed: choose between Johnson's and Floyd-Warshall
      # Johnson's is better for sparse graphs (E < V²/4)
      if edge_count < div(node_count * node_count, 4) do
        run_johnson(graph, points_of_interest, poi_set, zero, add, subtract, compare)
      else
        run_floyd_warshall(graph, points_of_interest, poi_set, zero, add, compare)
      end
    else
      # Non-negative weights: choose between Dijkstra × P and Floyd-Warshall
      # Dijkstra is better when few POIs (P ≤ V/3)
      poi_count = length(points_of_interest)

      if poi_count <= div(node_count, 3) do
        run_dijkstra_multi(graph, points_of_interest, poi_set, zero, add, compare)
      else
        run_floyd_warshall(graph, points_of_interest, poi_set, zero, add, compare)
      end
    end
  end

  # Run Johnson's algorithm and filter to POIs
  defp run_johnson(graph, _points_of_interest, poi_set, zero, add, subtract, compare) do
    case Johnson.johnson(graph, zero, add, subtract, compare) do
      {:ok, all_distances} ->
        {:ok, filter_to_pois(all_distances, poi_set)}

      {:error, :negative_cycle} ->
        {:error, :negative_cycle}
    end
  end

  # Run Floyd-Warshall algorithm and filter to POIs
  defp run_floyd_warshall(graph, _points_of_interest, poi_set, zero, add, compare) do
    case FloydWarshall.floyd_warshall(graph, zero, add, compare) do
      {:ok, all_distances} ->
        {:ok, filter_to_pois(all_distances, poi_set)}

      {:error, :negative_cycle} ->
        {:error, :negative_cycle}
    end
  end

  # Run Dijkstra from each POI and collect results in parallel
  defp run_dijkstra_multi(graph, points_of_interest, _poi_set, zero, add, compare) do
    parallel_opts = [
      max_concurrency: System.schedulers_online(),
      timeout: :infinity
    ]

    results =
      points_of_interest
      |> Task.async_stream(
        fn from ->
          distances = Dijkstra.single_source_distances(graph, from, zero, add, compare)

          # Add entries for this source to all reachable POIs
          Enum.reduce(points_of_interest, %{}, fn to, acc ->
            case Map.fetch(distances, to) do
              {:ok, dist} -> Map.put(acc, {from, to}, dist)
              :error -> acc
            end
          end)
        end,
        parallel_opts
      )
      |> Enum.reduce(%{}, fn {:ok, source_results}, acc ->
        Map.merge(acc, source_results)
      end)

    {:ok, results}
  end

  # Filter a full distance matrix to only include POI pairs
  defp filter_to_pois(all_distances, poi_set) do
    Enum.reduce(all_distances, %{}, fn {{from, to}, dist}, acc ->
      if MapSet.member?(poi_set, from) and MapSet.member?(poi_set, to) do
        Map.put(acc, {from, to}, dist)
      else
        acc
      end
    end)
  end

  # Check if all elements of set1 are in set2
  defp all_in_set?(set1, set2) do
    MapSet.subset?(set1, set2)
  end
end
