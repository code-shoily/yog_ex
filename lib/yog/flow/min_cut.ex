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
      # => %Yog.Flow.MinCutResult{cut_value: 6, source_side_size: 1, sink_side_size: 3}

  ## References

  - [Wikipedia: Minimum Cut](https://en.wikipedia.org/wiki/Minimum_cut)
  - [Wikipedia: Stoer-Wagner Algorithm](https://en.wikipedia.org/wiki/Stoer%E2%80%93Wagner_algorithm)
  - [CP-Algorithms: Stoer-Wagner](https://cp-algorithms.com/graph/stoer_wagner.html)
  """

  use Yog.Algorithm

  alias Yog.Flow.MinCutResult
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
      iex> result.source_side_size + result.sink_side_size
      3

  ## Notes

  - The graph must be undirected
  - Edge weights must be integers
  - Returns a `Yog.Flow.MinCutResult` struct with partition sizes
  """
  @spec global_min_cut(Yog.graph()) :: MinCutResult.t()
  def global_min_cut(graph) do
    nodes = Model.all_nodes(graph)

    case length(nodes) do
      n when n <= 1 ->
        MinCutResult.new(0, 0, 0)

      n ->
        graph = Transform.map_nodes(graph, fn _ -> 1 end)
        do_min_cut(graph, nil, n)
    end
  end

  defp do_min_cut(graph, best_cut, total_nodes) do
    if Model.node_count(graph) <= 1 do
      best_cut
    else
      {s, t, cut_weight} = maximum_adjacency_search(graph)

      t_size = Model.node(graph, t) || 1
      s_size = Model.node(graph, s) || 1

      current_cut =
        if is_nil(best_cut) or cut_weight < best_cut.cut_value do
          MinCutResult.new(
            cut_weight,
            t_size,
            total_nodes - t_size
          )
        else
          best_cut
        end

      Transform.contract(graph, s, t, &+/2)
      |> Mutator.add_node(s, s_size + t_size)
      |> do_min_cut(current_cut, total_nodes)
    end
  end

  # Maximum Adjacency Search: finds the two most tightly connected nodes.
  # Returns {s, t, cut_weight} where:
  # - s: second-to-last node added
  # - t: last node added
  # - cut_weight: accumulated weight in the MAS weights dict for t
  defp maximum_adjacency_search(graph) do
    nodes = Model.all_nodes(graph)
    [start | rest] = nodes

    initial_dists =
      Model.neighbors(graph, start)
      |> Enum.reduce(%{}, fn {neighbor, weight}, acc ->
        Map.put(acc, neighbor, weight)
      end)

    pq =
      Enum.reduce(rest, PriorityQueue.new(fn a, b -> a >= b end), fn node, acc ->
        dist = Map.get(initial_dists, node, 0)
        PriorityQueue.push(acc, {dist, node})
      end)

    remaining = MapSet.new(rest)

    {final_order, final_weights} =
      build_mas_order(
        graph,
        [start],
        remaining,
        initial_dists,
        pq
      )

    [t, s | _] = final_order

    cut_weight = Map.get(final_weights, t, 0)

    {s, t, cut_weight}
  end

  # Builds the MAS ordering by greedily adding the most tightly connected node.
  defp build_mas_order(graph, current_order, remaining, weights, queue) do
    if MapSet.size(remaining) == 0 do
      {current_order, weights}
    else
      {node, new_queue} = get_next_mas_node(queue, remaining, weights)
      new_remaining = MapSet.delete(remaining, node)

      {new_weights, updated_queue} =
        graph
        |> Model.neighbors(node)
        |> Enum.reduce({weights, new_queue}, fn {neighbor, weight}, {weights_acc, queue_acc} ->
          if MapSet.member?(new_remaining, neighbor) do
            existing_w = Map.get(weights_acc, neighbor, 0)
            new_w = existing_w + weight

            new_weights_acc = Map.put(weights_acc, neighbor, new_w)
            new_queue_acc = PriorityQueue.push(queue_acc, {new_w, neighbor})

            {new_weights_acc, new_queue_acc}
          else
            {weights_acc, queue_acc}
          end
        end)

      build_mas_order(
        graph,
        [node | current_order],
        new_remaining,
        new_weights,
        updated_queue
      )
    end
  end

  defp get_next_mas_node(queue, remaining, weights) do
    case PriorityQueue.pop(queue) do
      {:ok, {w, node}, q_rest} ->
        if MapSet.member?(remaining, node) do
          current_weight = Map.get(weights, node, 0)

          if w == current_weight do
            {node, q_rest}
          else
            get_next_mas_node(q_rest, remaining, weights)
          end
        else
          get_next_mas_node(q_rest, remaining, weights)
        end

      :error ->
        [node | _] = MapSet.to_list(remaining)
        {node, queue}
    end
  end
end
