defmodule Yog.Matching do
  @moduledoc """
  Graph matching algorithms.

  This module provides algorithms for finding matchings in graphs.
  A matching is a set of edges without common vertices.

  ## Algorithms

  | Problem | Algorithm | Function | Complexity |
  |---------|-----------|----------|------------|
  | Maximum bipartite matching | [Hopcroft-Karp](https://en.wikipedia.org/wiki/Hopcroft%E2%80%93Karp_algorithm) | `hopcroft_karp/1` | O(E√V) |
  | Weighted bipartite matching | [Hungarian (Kuhn-Munkres)](https://en.wikipedia.org/wiki/Hungarian_algorithm) | `hungarian/2` | O(V³) |
  | Maximum general matching | [Edmonds' Blossom](https://en.wikipedia.org/wiki/Blossom_algorithm) | `blossom_maximum_matching/1` | O(V²E) |

  ## Key Concepts

  - **Matching**: A set of edges with no shared vertices
  - **Maximum Matching**: A matching with the largest possible number of edges
  - **Perfect Matching**: Every vertex is matched (requires equal partitions)
  - **Assignment Problem**: Optimal assignment of workers to jobs with costs/weights

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [{:a1, :b1, 1}, {:a1, :b2, 1}, {:a2, :b2, 1}, {:a2, :b3, 1}])
      iex> matching = Yog.Matching.hopcroft_karp(graph)
      iex> map_size(matching)
      4
      iex> matching[:a1] in [:b1, :b2]
      true
      iex> matching[:a2] in [:b2, :b3]
      true
      iex> matching[:a1] != matching[:a2]
  """

  alias Yog.Graph
  alias Yog.Model
  alias Yog.Property.Bipartite

  @nil_key :__hopcroft_karp_nil__

  @doc """
  Finds a maximum cardinality matching in a bipartite graph using the
  Hopcroft-Karp algorithm.

  The algorithm repeatedly finds a maximal set of shortest vertex-disjoint
  augmenting paths via BFS layering, then augments the matching along each
  path via DFS. This yields O(E√V) time complexity, significantly faster
  than the naive O(VE) augmenting-path approach on dense graphs.

  Returns a bidirectional map where each matched pair appears twice
  (`u => v` and `v => u`) for easy lookup in either direction.

  Raises `ArgumentError` if the input graph is not bipartite.

  ## Examples

      # Simple path graph
      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
      iex> matching = Yog.Matching.hopcroft_karp(graph)
      iex> map_size(matching)
      4

      # Star graph
      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {1, 3, 1}, {1, 4, 1}])
      iex> matching = Yog.Matching.hopcroft_karp(graph)
      iex> map_size(matching)
      2

      # Complete bipartite K_{2,2}
      iex> graph = Yog.from_edges(:undirected, [{:a1, :b1, 1}, {:a1, :b2, 1}, {:a2, :b1, 1}, {:a2, :b2, 1}])
      iex> matching = Yog.Matching.hopcroft_karp(graph)
      iex> map_size(matching)
      4

      # Empty graph
      iex> matching = Yog.Matching.hopcroft_karp(Yog.undirected())
      iex> matching == %{}
      true

  ## Time Complexity

  O(E√V)
  """
  @spec hopcroft_karp(Graph.t()) :: %{Yog.node_id() => Yog.node_id()}
  def hopcroft_karp(%Graph{} = graph) do
    case Bipartite.partition(graph) do
      {:ok, %{left: left, right: right}} ->
        do_hopcroft_karp(graph, left, right)

      {:error, :not_bipartite} ->
        raise ArgumentError, "hopcroft_karp/1 requires a bipartite graph"
    end
  end

  defp do_hopcroft_karp(graph, left, right) do
    u_nodes = MapSet.to_list(left)
    v_nodes = MapSet.to_list(right)

    adj =
      Map.new(u_nodes, fn u ->
        neighbors = Model.neighbor_ids(graph, u)
        valid = Enum.filter(neighbors, fn v -> MapSet.member?(right, v) end)
        {u, valid}
      end)

    pair_u = Map.new(u_nodes, fn u -> {u, @nil_key} end)
    pair_v = Map.new(v_nodes, fn v -> {v, @nil_key} end)

    {final_pair_u, _final_pair_v} = hk_loop(adj, u_nodes, pair_u, pair_v)

    Enum.reduce(u_nodes, %{}, fn u, acc ->
      case Map.fetch!(final_pair_u, u) do
        @nil_key -> acc
        v -> acc |> Map.put(u, v) |> Map.put(v, u)
      end
    end)
  end

  defp hk_loop(adj, u_nodes, pair_u, pair_v) do
    {dist, found_aug} = bfs(adj, u_nodes, pair_u, pair_v)

    if found_aug do
      {new_pair_u, new_pair_v} = dfs_all(u_nodes, adj, pair_u, pair_v, dist)
      hk_loop(adj, u_nodes, new_pair_u, new_pair_v)
    else
      {pair_u, pair_v}
    end
  end

  defp bfs(adj, u_nodes, pair_u, pair_v) do
    dist =
      Enum.reduce(u_nodes, %{}, fn u, acc ->
        if Map.fetch!(pair_u, u) == @nil_key do
          Map.put(acc, u, 0)
        else
          Map.put(acc, u, :infinity)
        end
      end)
      |> Map.put(@nil_key, :infinity)

    queue = :queue.from_list(Enum.filter(u_nodes, fn u -> Map.fetch!(pair_u, u) == @nil_key end))

    do_bfs(queue, adj, pair_v, dist)
  end

  defp do_bfs(queue, adj, pair_v, dist) do
    case :queue.out(queue) do
      {:empty, _} ->
        {dist, Map.fetch!(dist, @nil_key) != :infinity}

      {{:value, u}, rest_q} ->
        if Map.fetch!(dist, u) < Map.fetch!(dist, @nil_key) do
          neighbors = Map.get(adj, u, [])

          {new_dist, new_q} =
            Enum.reduce(neighbors, {dist, rest_q}, fn v, {d, q} ->
              u2 = Map.fetch!(pair_v, v)

              if Map.fetch!(d, u2) == :infinity do
                d2 = Map.put(d, u2, Map.fetch!(d, u) + 1)
                q2 = :queue.in(u2, q)
                {d2, q2}
              else
                {d, q}
              end
            end)

          do_bfs(new_q, adj, pair_v, new_dist)
        else
          do_bfs(rest_q, adj, pair_v, dist)
        end
    end
  end

  defp dfs_all(u_nodes, adj, pair_u, pair_v, dist) do
    {new_pair_u, new_pair_v, _} =
      Enum.reduce(u_nodes, {pair_u, pair_v, dist}, fn u, {pu, pv, d} ->
        if Map.fetch!(pu, u) == @nil_key do
          case dfs(u, adj, pu, pv, d) do
            {true, new_pu, new_pv, new_dist} ->
              {new_pu, new_pv, new_dist}

            {false, new_pu, new_pv, new_dist} ->
              {new_pu, new_pv, Map.put(new_dist, u, :infinity)}
          end
        else
          {pu, pv, d}
        end
      end)

    {new_pair_u, new_pair_v}
  end

  defp dfs(@nil_key, _adj, pair_u, pair_v, dist) do
    {true, pair_u, pair_v, dist}
  end

  defp dfs(u, adj, pair_u, pair_v, dist) do
    neighbors = Map.get(adj, u, [])

    result =
      Enum.reduce_while(neighbors, {false, pair_u, pair_v, dist}, fn v, {_success, pu, pv, d} ->
        u2 = Map.fetch!(pv, v)

        if Map.fetch!(d, u2) == Map.fetch!(d, u) + 1 do
          case dfs(u2, adj, pu, pv, d) do
            {true, new_pu, new_pv, new_dist} ->
              new_pu2 = Map.put(new_pu, u, v)
              new_pv2 = Map.put(new_pv, v, u)
              {:halt, {true, new_pu2, new_pv2, new_dist}}

            {false, new_pu, new_pv, new_dist} ->
              {:cont, {false, new_pu, new_pv, new_dist}}
          end
        else
          {:cont, {false, pu, pv, d}}
        end
      end)

    case result do
      {true, _, _, _} -> result
      {false, pu, pv, d} -> {false, pu, pv, Map.put(d, u, :infinity)}
    end
  end

  # =============================================================================
  # Hungarian Algorithm (Kuhn-Munkres)
  # =============================================================================

  @type optimization :: :min | :max

  @doc """
  Finds a minimum or maximum weight perfect matching in a bipartite graph using
  the Hungarian (Kuhn-Munkres) algorithm.

  The graph must be bipartite. Rectangular partitions (|L| ≠ |R|) are padded with
  dummy nodes at zero cost so the algorithm can proceed. Missing edges are not
  supported: the graph must be complete between the two partitions.

  Returns `{total_cost, matching}` where `matching` is a bidirectional map
  (`u => v` and `v => u` for every matched pair). Dummy nodes are excluded from
  the result.

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [
      ...>   {:a, :x, 10}, {:a, :y, 19}, {:a, :z, 8},
      ...>   {:b, :x, 15}, {:b, :y, 17}, {:b, :z, 12},
      ...>   {:c, :x, 8},  {:c, :y, 18}, {:c, :z, 9}
      ...> ])
      iex> {cost, matching} = Yog.Matching.hungarian(graph, :min)
      iex> cost
      33
      iex> matching[:a]
      :z
  """
  @spec hungarian(Graph.t(), optimization()) ::
          {number(), %{Yog.node_id() => Yog.node_id()}}
  def hungarian(%Graph{} = graph, optimization \\ :min) when optimization in [:min, :max] do
    case Bipartite.partition(graph) do
      {:ok, %{left: left, right: right}} ->
        do_hungarian(graph, left, right, optimization)

      {:error, :not_bipartite} ->
        raise ArgumentError, "hungarian/2 requires a bipartite graph"
    end
  end

  defp do_hungarian(graph, left, right, optimization) do
    left_nodes = MapSet.to_list(left) |> Enum.sort()
    right_nodes = MapSet.to_list(right) |> Enum.sort()
    n = length(left_nodes)
    m = length(right_nodes)
    k = max(n, m)

    if k == 0 do
      {0, %{}}
    else
      padded_left =
        if k > n, do: left_nodes ++ Enum.map(1..(k - n), &{:__dummy_left__, &1}), else: left_nodes

      padded_right =
        if k > m,
          do: right_nodes ++ Enum.map(1..(k - m), &{:__dummy_right__, &1}),
          else: right_nodes

      cost_matrix = build_cost_matrix(graph, padded_left, padded_right, optimization)

      {total_cost, matching_indices} = hungarian_impl(cost_matrix, k)

      # Build result matching map
      real_left = MapSet.new(left_nodes)
      real_right = MapSet.new(right_nodes)

      left_tuple = List.to_tuple(padded_left)
      right_tuple = List.to_tuple(padded_right)

      matching =
        Enum.reduce(matching_indices, %{}, fn {j, i}, acc ->
          u = elem(left_tuple, i - 1)
          v = elem(right_tuple, j - 1)

          if MapSet.member?(real_left, u) and MapSet.member?(real_right, v) do
            acc |> Map.put(u, v) |> Map.put(v, u)
          else
            acc
          end
        end)

      cost =
        if optimization == :max do
          -total_cost
        else
          total_cost
        end

      {cost, matching}
    end
  end

  defp build_cost_matrix(graph, left, right, optimization) do
    left_indexed = Enum.with_index(left, 1)
    right_indexed = Enum.with_index(right, 1)

    for {u, i} <- left_indexed, {v, j} <- right_indexed, into: %{} do
      weight =
        case {u, v} do
          {{:__dummy_left__, _}, _} ->
            0

          {_, {:__dummy_right__, _}} ->
            0

          _ ->
            weight = Model.edge_data(graph, u, v) || Model.edge_data(graph, v, u)

            if is_nil(weight) do
              raise ArgumentError, "hungarian/2 requires a complete bipartite graph"
            end

            weight
        end

      cost = if optimization == :max, do: -weight, else: weight
      {{i, j}, cost}
    end
  end

  defp hungarian_impl(matrix, n) do
    u = Map.new(0..n, fn i -> {i, 0} end)
    v = Map.new(0..n, fn j -> {j, 0} end)
    p = Map.new(0..n, fn j -> {j, 0} end)
    way = Map.new(0..n, fn j -> {j, 0} end)

    {_u, final_v, final_p} =
      Enum.reduce(1..n, {u, v, p}, fn i, {u_acc, v_acc, p_acc} ->
        minv = Map.new(0..n, fn j -> {j, :infinity} end)
        used = Map.new(0..n, fn j -> {j, false} end)
        p_acc = Map.put(p_acc, 0, i)

        {p_res, u_res, v_res} =
          perform_augmentation(matrix, p_acc, u_acc, v_acc, way, minv, used, 0, n)

        {u_res, v_res, p_res}
      end)

    matching =
      Enum.reduce(1..n, %{}, fn j, acc ->
        i = Map.get(final_p, j)
        if i != 0, do: Map.put(acc, j, i), else: acc
      end)

    total_cost = -Map.get(final_v, 0)
    {total_cost, matching}
  end

  defp perform_augmentation(matrix, p, u, v, way, minv, used, j0, n) do
    used = Map.put(used, j0, true)
    i0 = Map.get(p, j0)

    {minv, way, j1} =
      Enum.reduce(1..n, {minv, way, 0}, fn j, {mv_acc, w_acc, best_j} ->
        if Map.get(used, j) do
          {mv_acc, w_acc, best_j}
        else
          cur = Map.get(matrix, {i0, j}) - Map.get(u, i0) - Map.get(v, j)

          {mv_acc, w_acc} =
            if cur < Map.get(mv_acc, j) do
              {Map.put(mv_acc, j, cur), Map.put(w_acc, j, j0)}
            else
              {mv_acc, w_acc}
            end

          best_j =
            if best_j == 0 or Map.get(mv_acc, j) < Map.get(mv_acc, best_j), do: j, else: best_j

          {mv_acc, w_acc, best_j}
        end
      end)

    delta = Map.get(minv, j1)

    {u, v, minv2} =
      Enum.reduce(0..n, {u, v, minv}, fn j, {u_ptr, v_ptr, mv_ptr} ->
        if Map.get(used, j) do
          u_ptr = Map.update!(u_ptr, Map.get(p, j), &(&1 + delta))
          v_ptr = Map.update!(v_ptr, j, &(&1 - delta))
          {u_ptr, v_ptr, mv_ptr}
        else
          mv_ptr = Map.update!(mv_ptr, j, &(&1 - delta))
          {u_ptr, v_ptr, mv_ptr}
        end
      end)

    if Map.get(p, j1) == 0 do
      p = backtrack_matching(p, way, j1)
      {p, u, v}
    else
      perform_augmentation(matrix, p, u, v, way, minv2, used, j1, n)
    end
  end

  defp backtrack_matching(p, way, j) do
    prev_j = Map.get(way, j)
    p = Map.put(p, j, Map.get(p, prev_j))
    if prev_j != 0, do: backtrack_matching(p, way, prev_j), else: p
  end

  # =============================================================================
  # Edmonds' Blossom Algorithm
  # =============================================================================

  @doc """
  Finds a maximum cardinality matching in a general (possibly non-bipartite) graph
  using Edmonds' Blossom algorithm.

  Unlike `hopcroft_karp/1`, this works on **any** undirected graph, including those
  with odd cycles. The algorithm detects odd cycles (blossoms), contracts them into
  super-vertices, and continues the search for augmenting paths.

  Returns a bidirectional map where each matched pair appears twice
  (`u => v` and `v => u`) for easy lookup in either direction.

  ## Examples

      # Triangle - odd cycle requires blossom contraction
      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> matching = Yog.Matching.blossom_maximum_matching(graph)
      iex> div(map_size(matching), 2)
      1

      # Square - even cycle, perfect matching exists
      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}, {4, 1, 1}])
      iex> matching = Yog.Matching.blossom_maximum_matching(graph)
      iex> div(map_size(matching), 2)
      2

      # Empty graph
      iex> matching = Yog.Matching.blossom_maximum_matching(Yog.undirected())
      iex> matching == %{}
      true

  ## Time Complexity

  O(V²E) — practical for graphs up to ~1000 nodes.

  ## References

  - [Wikipedia: Blossom algorithm](https://en.wikipedia.org/wiki/Blossom_algorithm)
  - Edmonds, J. (1965). "Paths, trees, and flowers"
  """
  @spec blossom_maximum_matching(Graph.t()) :: %{Yog.node_id() => Yog.node_id()}
  def blossom_maximum_matching(%Graph{} = graph) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      %{}
    else
      adj = blossom_adj(graph, nodes)

      Enum.reduce(nodes, %{}, fn u, match_acc ->
        if Map.has_key?(match_acc, u) do
          match_acc
        else
          blossom_try_augment(u, adj, match_acc, nodes)
        end
      end)
    end
  end

  defp blossom_adj(graph, nodes) do
    Map.new(nodes, fn u -> {u, Model.neighbor_ids(graph, u)} end)
  end

  # Try to find an augmenting path from `root` and augment the matching.
  # Returns updated matching (or unchanged if no augmenting path exists).
  defp blossom_try_augment(root, adj, match, nodes) do
    base = Map.new(nodes, fn n -> {n, n} end)
    parent = %{}
    used = MapSet.new([root])
    queue = :queue.in(root, :queue.new())

    blossom_bfs(queue, adj, match, base, parent, used, root)
  end

  defp blossom_bfs(queue, adj, match, base, parent, used, root) do
    case :queue.out(queue) do
      {:empty, _} ->
        # No augmenting path found from root
        root_match(match, root)

      {{:value, v}, rest} ->
        neighbors = Map.get(adj, v, [])

        blossom_process_neighbors(
          neighbors,
          v,
          rest,
          adj,
          match,
          base,
          parent,
          used,
          root
        )
    end
  end

  # Return the match map unchanged (root stays unmatched)
  defp root_match(match, _root), do: match

  defp blossom_process_neighbors([], _v, queue, adj, match, base, parent, used, root) do
    blossom_bfs(queue, adj, match, base, parent, used, root)
  end

  defp blossom_process_neighbors(
         [to | rest],
         v,
         queue,
         adj,
         match,
         base,
         parent,
         used,
         root
       ) do
    v_base = Map.fetch!(base, v)
    to_base = Map.fetch!(base, to)

    cond do
      # Same blossom or matched edge — skip
      v_base == to_base or Map.get(match, v) == to ->
        blossom_process_neighbors(rest, v, queue, adj, match, base, parent, used, root)

      # `to` is an even vertex in the tree — blossom found
      to == root or (Map.get(match, to) != nil and Map.has_key?(parent, Map.get(match, to))) ->
        cur_base = blossom_lca(v, to, base, match, parent)

        {base2, queue2, used2, parent2} =
          blossom_contract(v, cur_base, to, base, match, parent, queue, used)

        {base3, queue3, used3, parent3} =
          blossom_contract(to, cur_base, v, base2, match, parent2, queue2, used2)

        # Update base for all vertices whose base was contracted
        base4 =
          Enum.reduce(Map.keys(base3), base3, fn i, b_acc ->
            if MapSet.member?(used3, Map.fetch!(b_acc, i)) or
                 Map.fetch!(b_acc, Map.fetch!(b_acc, i)) == cur_base do
              # Walk base chain to find ultimate base
              resolve_base(i, b_acc, cur_base)
            else
              b_acc
            end
          end)

        blossom_process_neighbors(rest, v, queue3, adj, match, base4, parent3, used3, root)

      # `to` is not in the tree yet
      not Map.has_key?(parent, to) and to != root ->
        if Map.get(match, to) == nil do
          # Free vertex — augmenting path found!
          parent2 = Map.put(parent, to, v)
          blossom_augment(to, parent2, match)
        else
          # Matched vertex — extend the tree
          mate = Map.fetch!(match, to)
          parent2 = Map.put(parent, to, v)
          used2 = MapSet.put(used, mate)
          queue2 = :queue.in(mate, queue)
          blossom_process_neighbors(rest, v, queue2, adj, match, base, parent2, used2, root)
        end

      # `to` is odd in tree — skip
      true ->
        blossom_process_neighbors(rest, v, queue, adj, match, base, parent, used, root)
    end
  end

  # Find LCA of two even vertices in the alternating tree.
  # Walk up from both vertices alternately; first vertex visited twice is the LCA.
  defp blossom_lca(a, b, base, match, parent) do
    do_blossom_lca(a, b, base, match, parent, MapSet.new())
  end

  defp do_blossom_lca(:none, :none, _base, _match, _parent, _visited), do: :none

  defp do_blossom_lca(:none, b, base, match, parent, visited) do
    do_blossom_lca(b, :none, base, match, parent, visited)
  end

  defp do_blossom_lca(a, b, base, match, parent, visited) do
    a_base = Map.fetch!(base, a)

    if MapSet.member?(visited, a_base) do
      a_base
    else
      visited = MapSet.put(visited, a_base)

      next_a =
        case Map.get(match, a_base) do
          nil -> :none
          m -> Map.get(parent, m, :none)
        end

      # Swap: process b next, with next_a as the new b
      do_blossom_lca(b, next_a, base, match, parent, visited)
    end
  end

  # Contract one side of a blossom: walk from `v` up to `b` (the blossom base),
  # updating parent pointers and adding odd vertices to the queue.
  defp blossom_contract(v, b, child, base, match, parent, queue, used) do
    do_blossom_contract(v, b, child, base, match, parent, queue, used)
  end

  defp do_blossom_contract(v, b, child, base, match, parent, queue, used) do
    v_base = Map.fetch!(base, v)

    if v_base == b do
      {base, queue, used, parent}
    else
      # Mark both v_base and its match's base as part of the blossom
      base = Map.put(base, v_base, b)
      mate = Map.get(match, v_base)

      base =
        if mate != nil do
          Map.put(base, Map.fetch!(base, mate), b)
        else
          base
        end

      # Set parent for path retracing through the blossom
      parent = Map.put(parent, v, child)
      child = if mate != nil, do: mate, else: child

      # If vertex wasn't used (even), add to queue
      {queue, used} =
        if mate != nil and not MapSet.member?(used, mate) do
          {:queue.in(mate, queue), MapSet.put(used, mate)}
        else
          {queue, used}
        end

      # Walk up: v -> match[v] -> parent[match[v]]
      next_v =
        if mate != nil do
          Map.get(parent, mate, v)
        else
          b
        end

      do_blossom_contract(next_v, b, child, base, match, parent, queue, used)
    end
  end

  # Resolve base chain: ensure base[i] points to cur_base if it's in the blossom
  defp resolve_base(i, base, cur_base) do
    b = Map.fetch!(base, i)

    if b == cur_base or b == i do
      base
    else
      # Check if b's base resolves to cur_base
      base2 = resolve_base(b, base, cur_base)

      if Map.fetch!(base2, b) == cur_base do
        Map.put(base2, i, cur_base)
      else
        base2
      end
    end
  end

  # Augment matching along the alternating path ending at free vertex `v`.
  defp blossom_augment(v, parent, match) do
    pv = Map.fetch!(parent, v)
    ppv = Map.get(match, pv)

    match = match |> Map.put(v, pv) |> Map.put(pv, v)

    if ppv != nil do
      blossom_augment(ppv, parent, match)
    else
      match
    end
  end
end
