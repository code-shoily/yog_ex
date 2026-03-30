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
      # => %Yog.Flow.MinCutResult{cut_value: 6, source_side: MapSet.new([4]), sink_side: MapSet.new([1, 2, 3])}

  ## References

  - [Wikipedia: Minimum Cut](https://en.wikipedia.org/wiki/Minimum_cut)
  - [Wikipedia: Stoer-Wagner Algorithm](https://en.wikipedia.org/wiki/Stoer%E2%80%93Wagner_algorithm)
  - [CP-Algorithms: Stoer-Wagner](https://cp-algorithms.com/graph/stoer_wagner.html)
  """

  alias Yog.Flow.MinCutResult
  alias Yog.Model
  alias Yog.Transform

  @doc """
  Finds the global minimum cut of an undirected weighted graph.

  This implementation uses the Stoer-Wagner algorithm. It repeatedly finds
  an s-t min-cut in a phase using Maximum Adjacency Search and then contracts
  the nodes s and t. The global minimum cut is the minimum of all phase cuts.

  **Time Complexity:** O(V³)

  ## Examples

  Simple triangle graph:

      iex> {:ok, graph} = Yog.undirected()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      ...>   |> Yog.add_node(3, "C")
      ...>   |> Yog.add_edges([{1, 2, 5}, {2, 3, 3}, {1, 3, 2}])
      iex> result = Yog.Flow.MinCut.global_min_cut(graph)
      iex> result.cut_value
      5
      iex> MapSet.size(result.source_side) + MapSet.size(result.sink_side)
      3

  ## Notes

  - The graph must be undirected
  - Edge weights must be integers
  - Returns a `Yog.Flow.MinCutResult` struct with the actual node partitions
  """
  @spec global_min_cut(Yog.graph()) :: MinCutResult.t()
  def global_min_cut(graph) do
    nodes = Model.all_nodes(graph)

    case length(nodes) do
      n when n <= 1 ->
        MinCutResult.new(MapSet.new(nodes), MapSet.new(), 0)

      _n ->
        # Track actual partitions: node_id => MapSet of original IDs
        partitions = Map.new(nodes, fn id -> {id, MapSet.new([id])} end)
        # Get the full set of original nodes once
        all_original = MapSet.new(nodes)

        do_stoer_wagner(graph, partitions, all_original, nil)
    end
  end

  defp do_stoer_wagner(graph, partitions, all_original, best_cut) do
    # Stoer-Wagner terminates when only one node remains
    if map_size(graph.nodes) <= 1 do
      best_cut
    else
      {s, t} = min_cut_phase(graph)
      cut_weight = phase_cut_weight(graph, t)

      # t_nodes represents one side of the cut
      t_nodes = Map.fetch!(partitions, t)

      new_best =
        if is_nil(best_cut) or cut_weight < best_cut.cut_value do
          MinCutResult.new(
            t_nodes,
            MapSet.difference(all_original, t_nodes),
            cut_weight
          )
        else
          best_cut
        end

      # Contract s and t: merge t_nodes into s_nodes
      new_graph = Transform.contract(graph, s, t, &+/2)

      new_partitions =
        partitions
        |> Map.put(s, MapSet.union(Map.fetch!(partitions, s), t_nodes))
        |> Map.delete(t)

      do_stoer_wagner(new_graph, new_partitions, all_original, new_best)
    end
  end

  # Maximum Adjacency Search finds s and t nodes (last two added to search set)
  defp min_cut_phase(graph) do
    [v0 | rest] = Model.all_nodes(graph)
    # Start MAS: keep remaining as a list to avoid O(V) conversion in loops
    dists = Model.neighbors(graph, v0) |> Map.new()
    in_s = MapSet.new([v0])

    do_mas(graph, in_s, rest, dists, nil, v0)
  end

  # Optimized MAS: No MapSet.to_list in the recursion
  defp do_mas(_graph, _in_s, [], _dists, prev_s, current_t) when is_nil(prev_s) do
    # Single node case - no previous node exists
    {current_t, current_t}
  end

  defp do_mas(_graph, _in_s, [], _dists, prev_s, current_t) do
    {prev_s, current_t}
  end

  defp do_mas(graph, in_s, remaining, dists, _prev_s, current_t) do
    # find_max_dist is O(remaining)
    {next, _w} = find_max_dist(remaining, dists)

    new_in_s = MapSet.put(in_s, next)
    # List.delete is O(V) but only happens once per iteration
    new_remaining = List.delete(remaining, next)

    next_neighbors = Model.neighbors(graph, next)

    new_dists =
      Enum.reduce(next_neighbors, dists, fn {v, w}, acc ->
        if MapSet.member?(new_in_s, v) do
          acc
        else
          Map.update(acc, v, w, &(&1 + w))
        end
      end)

    do_mas(graph, new_in_s, new_remaining, new_dists, current_t, next)
  end

  defp find_max_dist([first | rest], dists) do
    Enum.reduce(rest, {first, Map.get(dists, first, 0)}, fn node, {best_id, best_w} ->
      w = Map.get(dists, node, 0)
      if w > best_w, do: {node, w}, else: {best_id, best_w}
    end)
  end

  defp phase_cut_weight(graph, t) do
    Model.neighbors(graph, t)
    |> Enum.reduce(0, fn {_, w}, acc -> acc + w end)
  end
end
