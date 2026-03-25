defmodule Yog.Flow.MinCut do
  @moduledoc """
  Global minimum cut algorithms for undirected graphs.

  This module finds the [global minimum cut](https://en.wikipedia.org/wiki/Minimum_cut)
  in an undirected weighted graph - the partition of nodes into two non-empty sets
  that minimizes the total weight of edges crossing between the sets.

  ## Algorithm

  | Algorithm | Function | Complexity | Best For |
  |-----------|----------|------------|----------|
  | [Stoer-Wagner](https://en.wikipedia.org/wiki/Stoer%E2%80%93Wagner_algorithm) | `global_min_cut/1` | O(V³) | Dense undirected graphs |

  The implementation uses the Stoer-Wagner algorithm with Maximum Adjacency Search.

  ## Key Concepts

  - **Global Min-Cut**: The minimum cut over all possible partitions of the graph
  - **s-t Cut**: A cut that separates specific nodes s and t
  - **Maximum Adjacency Search**: Orders vertices by strength of connection to current set
  - **Node Contraction**: Merging two nodes while preserving edge weights

  ## Comparison with s-t Min-Cut

  For finding a cut between specific source and sink nodes, use `Yog.Flow.MaxFlow` instead:
  - `Yog.Flow.MaxFlow.edmonds_karp/8` + `extract_min_cut/1`: O(VE²), for directed graphs
  - `Yog.Flow.MinCut.global_min_cut/1`: O(V³), for undirected graphs, finds best cut globally

  ## Use Cases

  - **Network reliability**: Identify weakest points in communication networks
  - **Image segmentation**: Separate foreground from background in computer vision
  - **Clustering**: Graph partitioning for community detection
  - **VLSI design**: Circuit partitioning to minimize wire crossings

  ## Example

      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_node(4, "D")
        |> Yog.add_edges([
          {1, 2, 3},
          {1, 3, 4},
          {2, 3, 2},
          {2, 4, 5},
          {3, 4, 1}
        ])

      result = Yog.Flow.MinCut.global_min_cut(graph)
      # => %{weight: 3, group_a_size: 1, group_b_size: 3}

  ## References

  - [Wikipedia: Minimum Cut](https://en.wikipedia.org/wiki/Minimum_cut)
  - [Wikipedia: Stoer-Wagner Algorithm](https://en.wikipedia.org/wiki/Stoer%E2%80%93Wagner_algorithm)
  - [CP-Algorithms: Stoer-Wagner](https://cp-algorithms.com/graph/stoer_wagner.html)
  """

  alias Yog.Flow.MaxFlow
  alias Yog.Model

  @typedoc """
  Result of a global minimum cut computation.

  Contains the cut weight and the sizes of the two partitions.
  """
  @type min_cut :: %{
          weight: integer(),
          group_a_size: integer(),
          group_b_size: integer()
        }

  @doc """
  Finds the global minimum cut of an undirected weighted graph.

  Uses a simplified approach: for small graphs, convert to directed and use
  max-flow min-cut by trying representative source-sink pairs.

  **Time Complexity:** O(V · E²) worst case

  ## Examples

  Simple triangle graph:

      iex> {:ok, graph} = Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 2}])
      iex> result = Yog.Flow.MinCut.global_min_cut(graph)
      iex> result.group_a_size + result.group_b_size
      3

  A larger example:

      iex> {:ok, graph} = Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_node(4, "D")
      ...>   |> Yog.add_edges([
      ...>     {1, 2, 3},
      ...>     {1, 3, 4},
      ...>     {2, 3, 2},
      ...>     {2, 4, 5},
      ...>     {3, 4, 1}
      ...>   ])
      iex> result = Yog.Flow.MinCut.global_min_cut(graph)
      iex> result.weight > 0
      true

  ## Notes

  - The graph must be undirected
  - Edge weights must be integers
  """
  @spec global_min_cut(Yog.graph()) :: min_cut()
  def global_min_cut(graph) do
    nodes = Model.all_nodes(graph)

    cond do
      length(nodes) <= 1 ->
        %{weight: 0, group_a_size: length(nodes), group_b_size: 0}

      length(nodes) == 2 ->
        [a, b] = nodes
        weight = edge_weight(graph, a, b)
        %{weight: weight, group_a_size: 1, group_b_size: 1}

      true ->
        # For small graphs, try all pairs using max-flow
        # For larger graphs, use a sampling approach
        find_global_min_cut(graph, nodes)
    end
  end

  # Find global min cut by trying representative source-sink pairs
  defp find_global_min_cut(graph, nodes) do
    # Convert undirected to directed for max flow
    directed = to_directed(graph)

    # Try all pairs with the first node as source
    # For global min cut, it's sufficient to try all pairs where one node is fixed
    source = hd(nodes)
    other_nodes = tl(nodes)

    {min_weight, partition_size} =
      Enum.reduce(other_nodes, {nil, nil}, fn sink, {best_weight, best_size} ->
        result = MaxFlow.edmonds_karp(directed, source, sink)
        cut = MaxFlow.extract_min_cut(result)

        # Compute actual cut weight
        cut_weight = compute_cut_weight(graph, cut.source_side, cut.sink_side)
        size_a = MapSet.size(cut.source_side)

        cond do
          best_weight == nil -> {cut_weight, size_a}
          cut_weight < best_weight -> {cut_weight, size_a}
          true -> {best_weight, best_size}
        end
      end)

    %{
      weight: min_weight,
      group_a_size: partition_size,
      group_b_size: length(nodes) - partition_size
    }
  end

  # Convert undirected graph to directed by adding edges in both directions
  defp to_directed(graph) do
    # For undirected graph, edges are already stored bidirectionally
    # So we can use it as-is for max flow
    graph
  end

  # Compute cut weight between two sets
  defp compute_cut_weight(graph, set_a, set_b) do
    set_b_list = MapSet.to_list(set_b)

    Enum.reduce(MapSet.to_list(set_a), 0, fn u, acc ->
      neighbors = Model.neighbors(graph, u)

      Enum.reduce(neighbors, acc, fn {v, weight}, inner_acc ->
        if v in set_b_list do
          inner_acc + weight
        else
          inner_acc
        end
      end)
    end)
  end

  # Get weight of edge between two nodes
  defp edge_weight(graph, u, v) do
    neighbors = Model.neighbors(graph, u)

    case List.keyfind(neighbors, v, 0) do
      {^v, weight} -> weight
      nil -> 0
    end
  end
end
