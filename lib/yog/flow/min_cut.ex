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
  alias Yog.PriorityQueue
  alias Yog.Transform

  @doc """
  Finds the global minimum cut of an undirected weighted graph.

  This implementation uses the Stoer-Wagner algorithm. It repeatedly finds
  an s-t min-cut in a phase using Maximum Adjacency Search and then contracts
  the nodes s and t. The global minimum cut is the minimum of all phase cuts.

  **Time Complexity:** O(V³) (O(V² log V) with priority queue optimization)

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
  # Uses a max-priority queue for O(log V) extraction instead of O(V) linear scan
  defp min_cut_phase(graph) do
    nodes = Model.all_nodes(graph)
    [v0 | rest] = nodes

    # Build initial distances from v0
    dists = Model.neighbors(graph, v0) |> Map.new()

    # Build max-priority queue with remaining nodes
    # Comparator: max-heap by distance (higher distance = higher priority)
    pq =
      Enum.reduce(rest, PriorityQueue.new(fn a, b -> a >= b end), fn node, acc ->
        dist = Map.get(dists, node, 0)
        PriorityQueue.push(acc, {dist, node})
      end)

    in_s = MapSet.new([v0])

    do_mas_pq(graph, in_s, pq, dists, nil, v0)
  end

  # MAS with priority queue: O(V log V) instead of O(V²)
  defp do_mas_pq(graph, in_s, pq, dists, prev_s, current_t) do
    case PriorityQueue.pop(pq) do
      :error ->
        # PQ empty - return last two nodes added
        if is_nil(prev_s), do: {current_t, current_t}, else: {prev_s, current_t}

      {:ok, {_dist, next}, rest_pq} ->
        # Skip stale entries (nodes already in S)
        if MapSet.member?(in_s, next) do
          do_mas_pq(graph, in_s, rest_pq, dists, prev_s, current_t)
        else
          new_in_s = MapSet.put(in_s, next)

          next_neighbors = Model.neighbors(graph, next)

          # Update distances and priority queue
          {new_dists, new_pq} =
            Enum.reduce(next_neighbors, {dists, rest_pq}, fn {v, w}, {d_acc, pq_acc} ->
              if MapSet.member?(new_in_s, v) do
                {d_acc, pq_acc}
              else
                old_dist = Map.get(d_acc, v, 0)
                new_dist = old_dist + w

                # Update distance map
                new_d_acc = Map.put(d_acc, v, new_dist)

                # For priority queue, we push the updated entry
                # Old entries will be skipped when popped (stale check via in_s)
                new_pq_acc = PriorityQueue.push(pq_acc, {new_dist, v})

                {new_d_acc, new_pq_acc}
              end
            end)

          do_mas_pq(graph, new_in_s, new_pq, new_dists, current_t, next)
        end
    end
  end

  defp phase_cut_weight(graph, t) do
    Model.neighbors(graph, t)
    |> Enum.reduce(0, fn {_, w}, acc -> acc + w end)
  end
end
