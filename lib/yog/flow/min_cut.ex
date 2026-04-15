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

  ## Example: Global Minimum Cut

  <div class="graphviz">
  graph G {
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];

    subgraph cluster_side1 {
      label="Side A"; color="#6366f1"; style=rounded;
      node1 [label="1"]; node2 [label="2"];
    }

    subgraph cluster_side2 {
      label="Side B"; color="#f43f5e"; style=rounded;
      node3 [label="3"];
    }

    node1 -- node2 [label="5"];

    // Cut edges (bridging the global partition)
    node1 -- node3 [label="2", color="#ef4444", penwidth=2.5, fontcolor="#ef4444"];
    node2 -- node3 [label="3", color="#ef4444", penwidth=2.5, fontcolor="#ef4444"];
  }
  </div>

      iex> alias Yog.Flow.MinCut
      iex> graph = Yog.from_edges(:undirected, [{1, 2, 5}, {2, 3, 3}, {1, 3, 2}])
      iex> result = MinCut.global_min_cut(graph)
      iex> result.cut_value
      5
      iex> result.source_side_size
      1
      iex> result.sink_side_size
      2
  """

  alias Yog.Flow.MaxFlow
  alias Yog.Flow.MinCutResult
  alias Yog.PairingHeap
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
  @spec global_min_cut(Yog.graph(), keyword()) :: MinCutResult.t()
  def global_min_cut(graph, opts \\ []) do
    track_partitions = Keyword.get(opts, :track_partitions, false)
    nodes = Map.keys(graph.nodes)

    case length(nodes) do
      n when n <= 1 ->
        if track_partitions do
          side = MapSet.new(nodes)
          MinCutResult.new(0, 0, 0, side, MapSet.new())
        else
          MinCutResult.new(0, 0, 0)
        end

      n ->
        sizes = Map.new(nodes, fn node -> {node, 1} end)
        all_nodes = MapSet.new(nodes)

        if track_partitions do
          partitions = Map.new(nodes, fn node -> {node, MapSet.new([node])} end)
          do_min_cut(graph, nil, n, sizes, partitions, all_nodes)
        else
          do_min_cut(graph, nil, n, sizes, nil, nil)
        end
    end
  end

  defp do_min_cut(graph, best_cut, total_nodes, sizes, partitions, all_nodes) do
    if map_size(graph.nodes) <= 1 do
      best_cut
    else
      {s, t, cut_weight} = maximum_adjacency_search(graph)

      t_size = Map.get(sizes, t, 1)
      s_size = Map.get(sizes, s, 1)

      current_cut =
        if is_nil(best_cut) or cut_weight < best_cut.cut_value do
          if is_nil(partitions) do
            MinCutResult.new(
              cut_weight,
              t_size,
              total_nodes - t_size
            )
          else
            t_partition = Map.fetch!(partitions, t)
            rest_partition = MapSet.difference(all_nodes, t_partition)

            MinCutResult.new(
              cut_weight,
              t_size,
              total_nodes - t_size,
              t_partition,
              rest_partition
            )
          end
        else
          best_cut
        end

      new_sizes =
        sizes
        |> Map.put(s, s_size + t_size)
        |> Map.delete(t)

      new_partitions =
        if is_nil(partitions) do
          nil
        else
          partitions
          |> Map.update!(s, &MapSet.union(&1, Map.fetch!(partitions, t)))
          |> Map.delete(t)
        end

      Transform.contract(graph, s, t, &+/2)
      |> do_min_cut(current_cut, total_nodes, new_sizes, new_partitions, all_nodes)
    end
  end

  @doc """
  Computes the minimum s-t cut using a max-flow algorithm.

  This is a convenience wrapper that delegates to `Yog.Flow.MaxFlow.max_flow/4`
  and extracts the corresponding min-cut from the residual graph.

  ## Parameters

  - `graph` - The flow network
  - `source` - Source node ID
  - `sink` - Sink node ID
  - `algorithm` - Algorithm to use: `:edmonds_karp` (default), `:dinic`, or `:push_relabel`

  ## Examples

      iex> {:ok, graph} = Yog.directed()
      ...>   |> Yog.add_node(1, "s")
      ...>   |> Yog.add_node(2, "a")
      ...>   |> Yog.add_node(3, "t")
      ...>   |> Yog.add_edges([{1, 2, 10}, {2, 3, 5}])
      iex> result = Yog.Flow.MinCut.s_t_min_cut(graph, 1, 3)
      iex> result.cut_value
      5
  """
  @spec s_t_min_cut(Yog.graph(), Yog.node_id(), Yog.node_id(), atom()) :: MinCutResult.t()
  def s_t_min_cut(graph, source, sink, algorithm \\ :edmonds_karp) do
    graph
    |> MaxFlow.max_flow(source, sink, algorithm)
    |> MaxFlow.extract_min_cut()
  end

  @doc """
  Finds the global minimum cut using the randomized Karger-Stein algorithm.

  Karger-Stein uses repeated random edge contraction with recursive branching
  to achieve high success probability. It is particularly effective on dense
  graphs where the exact Stoer-Wagner algorithm may be slower.

  ## Parameters

  - `graph` - The undirected weighted graph
  - `opts` - Options:
    - `:iterations` - Number of independent runs of the recursive fast-cut
      procedure (default: `max(1, trunc(n * log2(n + 1)))`)

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [{1, 2, 5}, {2, 3, 3}, {1, 3, 2}])
      iex> result = Yog.Flow.MinCut.karger_stein(graph)
      iex> result.cut_value
      5
  """
  @spec karger_stein(Yog.graph(), keyword()) :: MinCutResult.t()
  def karger_stein(graph, opts \\ []) do
    nodes = Map.keys(graph.nodes)
    n = length(nodes)

    if n <= 1 do
      side = MapSet.new(nodes)
      MinCutResult.new(0, 0, 0, side, MapSet.new())
    else
      {adj, vertices} = build_karger_adj(graph)

      default_iterations = max(1, trunc(n * :math.log2(n + 1)))
      iterations = Keyword.get(opts, :iterations, default_iterations)

      {best_cut, {best_a, best_b}} =
        Enum.reduce(1..iterations, {nil, nil}, fn _, {best_val, best_part} ->
          {cut_val, {part_a, part_b}} = fast_cut(adj, vertices)

          if is_nil(best_val) or cut_val < best_val do
            {cut_val, {part_a, part_b}}
          else
            {best_val, best_part}
          end
        end)

      MinCutResult.new(
        best_cut,
        MapSet.size(best_a),
        MapSet.size(best_b),
        best_a,
        best_b
      )
    end
  end

  # ==========================================================================
  # Karger-Stein Internals
  # ==========================================================================

  defp build_karger_adj(graph) do
    edges = Yog.Model.all_edges(graph)

    adj =
      Enum.reduce(edges, %{}, fn {u, v, w}, acc ->
        acc
        |> Map.update(u, %{v => w}, &Map.put(&1, v, w))
        |> Map.update(v, %{u => w}, &Map.put(&1, u, w))
      end)

    vertices = Map.new(Map.keys(graph.nodes), fn u -> {u, MapSet.new([u])} end)
    {adj, vertices}
  end

  defp fast_cut(adj, vertices) when map_size(vertices) <= 6 do
    brute_force_min_cut(adj, vertices)
  end

  defp fast_cut(adj, vertices) do
    n = map_size(vertices)
    t = trunc(Float.ceil(1 + n / :math.sqrt(2)))

    {adj1, vertices1} = contract_until(adj, vertices, t)
    {adj2, vertices2} = contract_until(adj, vertices, t)

    {cut1, part1} = fast_cut(adj1, vertices1)
    {cut2, part2} = fast_cut(adj2, vertices2)

    if cut1 <= cut2 do
      {cut1, part1}
    else
      {cut2, part2}
    end
  end

  defp contract_until(adj, vertices, target_count) do
    if map_size(vertices) <= target_count do
      {adj, vertices}
    else
      case random_edge(adj, vertices) do
        nil ->
          {adj, vertices}

        {u, v} ->
          {new_adj, new_vertices} = contract_edge(adj, vertices, u, v)
          contract_until(new_adj, new_vertices, target_count)
      end
    end
  end

  defp contract_edge(adj, vertices, u, v) do
    u_set = Map.fetch!(vertices, u)
    v_set = Map.fetch!(vertices, v)
    merged_set = MapSet.union(u_set, v_set)

    u_adj = Map.get(adj, u, %{})
    v_adj = Map.get(adj, v, %{})

    merged_adj =
      v_adj
      |> Enum.reduce(u_adj, fn {n, w}, acc ->
        if n == u or n == v do
          acc
        else
          Map.update(acc, n, w, &(&1 + w))
        end
      end)
      |> Map.delete(u)
      |> Map.delete(v)

    adj =
      v_adj
      |> Enum.reduce(adj, fn {n, w}, acc ->
        if n == u or n == v do
          acc
        else
          n_adj =
            acc
            |> Map.fetch!(n)
            |> Map.delete(v)
            |> Map.update(u, w, &(&1 + w))

          Map.put(acc, n, n_adj)
        end
      end)
      |> Map.put(u, merged_adj)
      |> Map.delete(v)

    vertices = vertices |> Map.put(u, merged_set) |> Map.delete(v)

    {adj, vertices}
  end

  defp random_edge(adj, vertices) do
    {edges, _} =
      vertices
      |> Map.keys()
      |> Enum.reduce({[], MapSet.new()}, fn u, {e_acc, seen} ->
        adj
        |> Map.get(u, %{})
        |> Enum.reduce({e_acc, seen}, fn {v, w}, {edges, s} ->
          key = {u, v}

          if MapSet.member?(s, key) do
            {edges, s}
          else
            {[{u, v, w} | edges], MapSet.put(s, {v, u})}
          end
        end)
      end)

    total = Enum.reduce(edges, 0, fn {_, _, w}, acc -> acc + w end)

    if total == 0 do
      nil
    else
      target = :rand.uniform() * total
      pick_weighted_edge(edges, target, 0)
    end
  end

  defp pick_weighted_edge([{u, v, w} | rest], target, acc) do
    acc = acc + w

    if acc >= target do
      {u, v}
    else
      pick_weighted_edge(rest, target, acc)
    end
  end

  defp brute_force_min_cut(adj, vertices) do
    vertex_list = Map.keys(vertices)
    n = length(vertex_list)

    {best_cut, {side_a_supers, side_b_supers}} =
      1..(trunc(:math.pow(2, n - 1)) - 1)
      |> Enum.reduce({nil, nil}, fn mask, {best_val, best_part} ->
        {side_a, side_b} = partition_from_mask(vertex_list, mask)
        cut_val = cut_weight_between(adj, side_a, side_b)

        if is_nil(best_val) or cut_val < best_val do
          {cut_val, {side_a, side_b}}
        else
          {best_val, best_part}
        end
      end)

    side_a_nodes = flatten_partition(vertices, side_a_supers)
    side_b_nodes = flatten_partition(vertices, side_b_supers)

    {best_cut, {side_a_nodes, side_b_nodes}}
  end

  defp partition_from_mask(vertex_list, mask) do
    vertex_list
    |> Enum.with_index()
    |> Enum.reduce({MapSet.new(), MapSet.new()}, fn {v, i}, {a, b} ->
      if Bitwise.band(Bitwise.bsr(mask, i), 1) == 1 do
        {MapSet.put(a, v), b}
      else
        {a, MapSet.put(b, v)}
      end
    end)
  end

  defp cut_weight_between(adj, side_a, side_b) do
    side_a
    |> MapSet.to_list()
    |> Enum.reduce(0, fn u, acc ->
      u_adj = Map.get(adj, u, %{})

      side_b
      |> MapSet.to_list()
      |> Enum.reduce(acc, fn v, inner_acc ->
        inner_acc + Map.get(u_adj, v, 0)
      end)
    end)
  end

  defp flatten_partition(vertices, supernode_set) do
    supernode_set
    |> MapSet.to_list()
    |> Enum.reduce(MapSet.new(), fn u, acc ->
      MapSet.union(acc, Map.fetch!(vertices, u))
    end)
  end

  # Maximum Adjacency Search: finds the two most tightly connected nodes.
  # Returns {s, t, cut_weight} where:
  # - s: second-to-last node added
  # - t: last node added
  # - cut_weight: accumulated weight in the MAS weights dict for t
  defp maximum_adjacency_search(graph) do
    nodes = Map.keys(graph.nodes)
    [start | rest] = nodes

    # Direct edge access for performance
    out_edges = graph.out_edges

    initial_dists =
      case Map.fetch(out_edges, start) do
        {:ok, neighbors} ->
          List.foldl(Map.to_list(neighbors), %{}, fn {neighbor, weight}, acc ->
            Map.put(acc, neighbor, weight)
          end)

        :error ->
          %{}
      end

    pq =
      List.foldl(rest, PairingHeap.new(fn a, b -> a >= b end), fn node, acc ->
        dist = Map.get(initial_dists, node, 0)
        PairingHeap.push(acc, {dist, node})
      end)

    remaining = MapSet.new(rest)

    {final_order, final_weights} =
      build_mas_order(
        out_edges,
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
  # Uses direct out_edges access for performance.
  defp build_mas_order(out_edges, current_order, remaining, weights, queue) do
    if MapSet.size(remaining) == 0 do
      {current_order, weights}
    else
      {node, new_queue} = get_next_mas_node(queue, remaining, weights)
      new_remaining = MapSet.delete(remaining, node)

      {new_weights, updated_queue} =
        case Map.fetch(out_edges, node) do
          {:ok, neighbors} ->
            List.foldl(Map.to_list(neighbors), {weights, new_queue}, fn {neighbor, weight},
                                                                        {weights_acc, queue_acc} ->
              if MapSet.member?(new_remaining, neighbor) do
                existing_w = Map.get(weights_acc, neighbor, 0)
                new_w = existing_w + weight

                new_weights_acc = Map.put(weights_acc, neighbor, new_w)
                new_queue_acc = PairingHeap.push(queue_acc, {new_w, neighbor})

                {new_weights_acc, new_queue_acc}
              else
                {weights_acc, queue_acc}
              end
            end)

          :error ->
            {weights, new_queue}
        end

      build_mas_order(
        out_edges,
        [node | current_order],
        new_remaining,
        new_weights,
        updated_queue
      )
    end
  end

  defp get_next_mas_node(queue, remaining, weights) do
    case PairingHeap.pop(queue) do
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
