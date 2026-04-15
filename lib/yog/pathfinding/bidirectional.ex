defmodule Yog.Pathfinding.Bidirectional do
  @moduledoc """
  Bidirectional search algorithms that meet in the middle for dramatic speedups.

  These algorithms start two simultaneous searches — one from the source
  and one from the target — that meet in the middle. This can dramatically
  reduce the search space compared to single-direction search.

  For a graph with branching factor `b` and depth `d`:
  - **Standard BFS**: `O(b^d)` nodes explored
  - **Bidirectional BFS**: `O(2 × b^(d/2))` nodes explored (up to 500x faster for long paths)

  ## Requirements

  - Target node must be known in advance (unlike Dijkstra, which can route many at once).
  - Designed for point-to-point queries.

  ## Examples

  <div class="graphviz">
  digraph G {
    rankdir=LR;
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];
    S [label="S"]; A [label="A"]; B [label="B"];
    M [label="M", color="#6366f1", penwidth=2];
    C [label="C"]; D [label="D"]; T [label="T"];
    S -> A [label="2", color="#6366f1", penwidth=2.5];
    A -> M [label="2", color="#6366f1", penwidth=2.5];
    S -> B [label="5"];
    B -> M [label="1"];
    M -> C [label="2", color="#6366f1", penwidth=2.5];
    C -> T [label="2", color="#6366f1", penwidth=2.5];
    M -> D [label="5"];
    D -> T [label="1"];
  }
  </div>

      iex> alias Yog.Pathfinding.Bidirectional
      iex> graph = Yog.from_edges(:directed, [
      ...>   {"S", "A", 2}, {"A", "M", 2}, {"S", "B", 5}, {"B", "M", 1},
      ...>   {"M", "C", 2}, {"C", "T", 2}, {"M", "D", 5}, {"D", "T", 1}
      ...> ])
      iex> {:ok, path} = Bidirectional.shortest_path(graph, "S", "T")
      iex> path.nodes
      ["S", "A", "M", "C", "T"]
      iex> path.weight
      8
  """

  # credo:disable-for-this-file Credo.Check.Refactor.AppendSingleItem

  alias Yog.PairingHeap, as: PQ
  alias Yog.Pathfinding.Path

  @typedoc "Result type for shortest path queries"
  @type path_result :: {:ok, Path.t()} | :error

  # ============================================================
  # Keyword-style API (for Pathfinding module delegation)
  # ============================================================

  @doc """
  Finds the shortest path in an unweighted graph using bidirectional BFS.

  This runs BFS from both source and target simultaneously, stopping when
  the frontiers meet.

  ## Options

    * `:in` - The graph
    * `:from` - The starting node ID
    * `:to` - The target node ID

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> {:ok, path} = Yog.Pathfinding.Bidirectional.shortest_path_unweighted(in: graph, from: 1, to: 3)
      iex> path.nodes
      [1, 2, 3]
      iex> path.weight
      2
      iex> Yog.Pathfinding.Bidirectional.shortest_path_unweighted(in: graph, from: 1, to: 99)
      :error

  """
  @spec shortest_path_unweighted(keyword()) :: path_result()
  def shortest_path_unweighted(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)

    shortest_path_unweighted(graph, from, to)
  end

  @doc """
  Finds the shortest path in a weighted graph using bidirectional Dijkstra.

  ## Options

    * `:in` - The graph
    * `:from` - The starting node ID
    * `:to` - The target node ID
    * `:zero` - The identity element for weights (e.g. `0`)
    * `:add` - Weight addition function (e.g. `fn a, b -> a + b end`)
    * `:compare` - Comparison function (e.g. `&Yog.Utils.compare/2`)

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)
      iex> {:ok, path} = Yog.Pathfinding.Bidirectional.shortest_path(
      ...>   in: graph, from: 1, to: 3,
      ...>   zero: 0, add: &+/2, compare: &Yog.Utils.compare/2
      ...> )
      iex> path.nodes
      [1, 2, 3]
      iex> path.weight
      15
  """
  @spec shortest_path(keyword()) :: path_result()
  def shortest_path(opts) do
    graph = Keyword.fetch!(opts, :in)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    zero = opts[:zero] || 0
    add = opts[:add] || (&Kernel.+/2)
    compare = opts[:compare] || (&Yog.Utils.compare/2)

    shortest_path(graph, from, to, zero, add, compare)
  end

  # ============================================================
  # Direct API
  # ============================================================

  @doc """
  Finds the shortest path in an unweighted graph using bidirectional BFS.

  ## Parameters

    * `graph` - The graph to search
    * `from` - The starting node ID
    * `to` - The target node ID

  ## Returns

    * `{:ok, path}` - A `Path` struct containing the nodes and edge count
    * `:error` - No path exists between the nodes

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> {:ok, path} = Yog.Pathfinding.Bidirectional.shortest_path_unweighted(graph, 1, 3)
      iex> path.nodes
      [1, 2, 3]
      iex> path.weight
      2
      iex> Yog.Pathfinding.Bidirectional.shortest_path_unweighted(graph, 1, 99)
      :error
  """
  @spec shortest_path_unweighted(Yog.t(), Yog.node_id(), Yog.node_id()) ::
          path_result() | :error
  def shortest_path_unweighted(graph, from, to) do
    if from == to do
      {:ok, Path.new([from], 0, :bidirectional_bfs)}
    else
      do_bidirectional_bfs(graph, from, to)
    end
  end

  @doc """
  Finds the shortest path in a weighted graph using bidirectional Dijkstra.

  ## Parameters

    * `graph` - The graph to search
    * `from` - The starting node ID
    * `to` - The target node ID
    * `zero` - The identity element for weights (e.g. `0`)
    * `add` - Weight addition function (e.g. `fn a, b -> a + b end`)
    * `compare` - Comparison function returning `:lt`, `:eq`, or `:gt`

  ## Returns

    * `{:ok, path}` - A `Path` struct containing the nodes and total weight
    * `:error` - No path exists between the nodes

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)
      iex> {:ok, path} = Yog.Pathfinding.Bidirectional.shortest_path(graph, 1, 3, 0, &+/2, &Yog.Utils.compare/2)
      iex> path.nodes
      [1, 2, 3]
      iex> path.weight
      15
  """
  @spec shortest_path(
          Yog.t(),
          Yog.node_id(),
          Yog.node_id(),
          weight,
          (weight, weight -> weight),
          (weight, weight -> :lt | :eq | :gt)
        ) :: path_result() | :error
        when weight: var
  def shortest_path(
        graph,
        from,
        to,
        zero \\ 0,
        add \\ &Kernel.+/2,
        compare \\ &Yog.Utils.compare/2
      ) do
    if from == to do
      {:ok, Path.new([from], zero, :bidirectional_dijkstra)}
    else
      do_bidirectional_dijkstra(graph, from, to, zero, add, compare)
    end
  end

  # ============================================================
  # Helper functions
  # ============================================================

  # Bidirectional BFS implementation
  # Uses level-by-level expansion and tracks the best meeting point to guarantee
  # the shortest path is found, not just the first meeting point.
  defp do_bidirectional_bfs(graph, from, to) do
    fwd_frontier = [{from, [from]}]
    bwd_frontier = [{to, [to]}]
    visited_fwd = %{from => [from]}
    visited_bwd = %{to => [to]}

    do_bfs_level(graph, fwd_frontier, bwd_frontier, visited_fwd, visited_bwd, 0, 0, nil)
  end

  defp do_bfs_level(_graph, [], _, _, _, _, _, nil), do: :error
  defp do_bfs_level(_graph, _, [], _, _, _, _, nil), do: :error

  defp do_bfs_level(_graph, [], _, _, _, _, _, {best_len, best_path}),
    do: {:ok, Path.new(best_path, best_len, :bidirectional_bfs)}

  defp do_bfs_level(_graph, _, [], _, _, _, _, {best_len, best_path}),
    do: {:ok, Path.new(best_path, best_len, :bidirectional_bfs)}

  defp do_bfs_level(graph, fwd_frontier, bwd_frontier, v_fwd, v_bwd, depth_fwd, depth_bwd, best) do
    best_len = if best, do: elem(best, 0), else: nil

    # Stop when both sides have expanded enough that no shorter path can exist
    if best_len != nil and depth_fwd + depth_bwd >= best_len do
      {best_len, best_path} = best
      {:ok, Path.new(best_path, best_len, :bidirectional_bfs)}
    else
      if length(fwd_frontier) <= length(bwd_frontier) do
        {new_frontier, new_v, new_best} =
          expand_frontier(graph, :fwd, fwd_frontier, v_fwd, v_bwd, best)

        do_bfs_level(
          graph,
          new_frontier,
          bwd_frontier,
          new_v,
          v_bwd,
          depth_fwd + 1,
          depth_bwd,
          new_best
        )
      else
        {new_frontier, new_v, new_best} =
          expand_frontier(graph, :bwd, bwd_frontier, v_bwd, v_fwd, best)

        do_bfs_level(
          graph,
          fwd_frontier,
          new_frontier,
          v_fwd,
          new_v,
          depth_fwd,
          depth_bwd + 1,
          new_best
        )
      end
    end
  end

  defp expand_frontier(graph, side, frontier, visited, other_visited, best) do
    edges_map =
      case side do
        :fwd -> graph.out_edges
        :bwd -> graph.in_edges
      end

    expand_frontier_nodes(frontier, edges_map, side, visited, other_visited, [], best)
  end

  defp expand_frontier_nodes([], _edges_map, _side, visited, _other_visited, acc, best) do
    {acc, visited, best}
  end

  defp expand_frontier_nodes(
         [{node, path} | rest],
         edges_map,
         side,
         visited,
         other_visited,
         acc,
         best
       ) do
    neighbors =
      case Map.fetch(edges_map, node) do
        {:ok, edges} -> Map.keys(edges)
        :error -> []
      end

    {new_acc, new_visited, new_best} =
      Enum.reduce(neighbors, {acc, visited, best}, fn neighbor, {a, v, b} ->
        if Map.has_key?(v, neighbor) do
          {a, v, b}
        else
          new_path = [neighbor | path]
          new_v = Map.put(v, neighbor, new_path)

          b2 =
            case Map.fetch(other_visited, neighbor) do
              {:ok, other_path} ->
                full_path =
                  if side == :fwd do
                    Enum.reverse(new_path) ++ tl(other_path)
                  else
                    Enum.reverse(other_path) ++ tl(new_path)
                  end

                len = length(full_path) - 1

                if is_nil(b) or len < elem(b, 0) do
                  {len, full_path}
                else
                  b
                end

              :error ->
                b
            end

          {[{neighbor, new_path} | a], new_v, b2}
        end
      end)

    expand_frontier_nodes(rest, edges_map, side, new_visited, other_visited, new_acc, new_best)
  end

  # Bidirectional Dijkstra implementation
  # Runs two Dijkstra searches simultaneously (forward from source, backward from target)
  # and stops when they meet. This is significantly faster than single-direction Dijkstra
  # for point-to-point queries.
  defp do_bidirectional_dijkstra(graph, from, to, zero, add, compare) do
    # Forward search (from source)
    queue_fwd =
      PQ.new(fn {d1, _}, {d2, _} -> compare.(d1, d2) != :gt end)
      |> PQ.push({zero, from})

    dist_fwd = %{from => zero}
    pred_fwd = %{}

    queue_bwd =
      PQ.new(fn {d1, _}, {d2, _} -> compare.(d1, d2) != :gt end)
      |> PQ.push({zero, to})

    dist_bwd = %{to => zero}
    pred_bwd = %{}
    best_path = nil
    best_weight = nil

    do_bidirectional_dijkstra_step(
      graph,
      queue_fwd,
      queue_bwd,
      dist_fwd,
      dist_bwd,
      pred_fwd,
      pred_bwd,
      from,
      to,
      add,
      compare,
      best_path,
      best_weight
    )
  end

  defp do_bidirectional_dijkstra_step(
         graph,
         q_fwd,
         q_bwd,
         dist_fwd,
         dist_bwd,
         pred_fwd,
         pred_bwd,
         source,
         target,
         add,
         compare,
         best_path,
         best_weight
       ) do
    if should_continue?(q_fwd, q_bwd, best_weight, compare) do
      expansion_side = decide_expansion_side(q_fwd, q_bwd, compare)

      perform_expansion_step(
        expansion_side,
        graph,
        q_fwd,
        q_bwd,
        dist_fwd,
        dist_bwd,
        pred_fwd,
        pred_bwd,
        source,
        target,
        add,
        compare,
        best_path,
        best_weight
      )
    else
      finalize_result(best_path, best_weight)
    end
  end

  defp should_continue?(q_fwd, q_bwd, nil, _compare) do
    not PQ.empty?(q_fwd) and not PQ.empty?(q_bwd)
  end

  defp should_continue?(q_fwd, q_bwd, best_weight, compare) do
    fwd_possible =
      case PQ.peek(q_fwd) do
        {:ok, {d, _}} -> compare.(d, best_weight) == :lt
        :error -> false
      end

    bwd_possible =
      case PQ.peek(q_bwd) do
        {:ok, {d, _}} -> compare.(d, best_weight) == :lt
        :error -> false
      end

    fwd_possible or bwd_possible
  end

  defp decide_expansion_side(q_fwd, q_bwd, compare) do
    case {PQ.peek(q_fwd), PQ.peek(q_bwd)} do
      {{:ok, {d_fwd, _}}, {:ok, {d_bwd, _}}} ->
        if compare.(d_fwd, d_bwd) != :gt, do: :fwd, else: :bwd

      {{:ok, _}, :error} ->
        :fwd

      {:error, {:ok, _}} ->
        :bwd

      _ ->
        :none
    end
  end

  defp finalize_result(nil, _weight), do: :error
  defp finalize_result(path, weight), do: {:ok, Path.new(path, weight, :bidirectional_dijkstra)}

  defp perform_expansion_step(
         :fwd,
         graph,
         q_fwd,
         q_bwd,
         dist_fwd,
         dist_bwd,
         pred_fwd,
         pred_bwd,
         source,
         target,
         add,
         compare,
         best_path,
         best_weight
       ) do
    case PQ.pop(q_fwd) do
      :error ->
        finalize_result(best_path, best_weight)

      {:ok, {dist_u, u}, rest_q} ->
        if Map.get(dist_fwd, u) != dist_u do
          # Stale entry
          do_bidirectional_dijkstra_step(
            graph,
            rest_q,
            q_bwd,
            dist_fwd,
            dist_bwd,
            pred_fwd,
            pred_bwd,
            source,
            target,
            add,
            compare,
            best_path,
            best_weight
          )
        else
          successors = Map.get(graph.out_edges, u, %{}) |> Map.to_list()

          {new_q, new_dist, new_pred, new_path, new_weight} =
            process_neighbors(
              :fwd,
              successors,
              rest_q,
              dist_fwd,
              dist_bwd,
              pred_fwd,
              pred_bwd,
              u,
              dist_u,
              add,
              compare,
              best_path,
              best_weight
            )

          do_bidirectional_dijkstra_step(
            graph,
            new_q,
            q_bwd,
            new_dist,
            dist_bwd,
            new_pred,
            pred_bwd,
            source,
            target,
            add,
            compare,
            new_path,
            new_weight
          )
        end
    end
  end

  defp perform_expansion_step(
         :bwd,
         graph,
         q_fwd,
         q_bwd,
         dist_fwd,
         dist_bwd,
         pred_fwd,
         pred_bwd,
         source,
         target,
         add,
         compare,
         best_path,
         best_weight
       ) do
    case PQ.pop(q_bwd) do
      :error ->
        finalize_result(best_path, best_weight)

      {:ok, {dist_v, v}, rest_q} ->
        if Map.get(dist_bwd, v) != dist_v do
          # Stale entry
          do_bidirectional_dijkstra_step(
            graph,
            q_fwd,
            rest_q,
            dist_fwd,
            dist_bwd,
            pred_fwd,
            pred_bwd,
            source,
            target,
            add,
            compare,
            best_path,
            best_weight
          )
        else
          predecessors = Map.get(graph.in_edges, v, %{}) |> Map.to_list()

          {new_q, new_dist, new_pred, new_path, new_weight} =
            process_neighbors(
              :bwd,
              predecessors,
              rest_q,
              dist_bwd,
              dist_fwd,
              pred_bwd,
              pred_fwd,
              v,
              dist_v,
              add,
              compare,
              best_path,
              best_weight
            )

          do_bidirectional_dijkstra_step(
            graph,
            q_fwd,
            new_q,
            dist_fwd,
            new_dist,
            pred_fwd,
            new_pred,
            source,
            target,
            add,
            compare,
            new_path,
            new_weight
          )
        end
    end
  end

  defp perform_expansion_step(:none, _, _, _, _, _, _, _, _, _, _, _, path, weight) do
    finalize_result(path, weight)
  end

  # Unified neighbor processing for both directions
  defp process_neighbors(
         _side,
         [],
         queue,
         dist_own,
         _dist_other,
         pred_own,
         _pred_other,
         _u,
         _dist_u,
         _add,
         _compare,
         best_path,
         best_weight
       ) do
    {queue, dist_own, pred_own, best_path, best_weight}
  end

  defp process_neighbors(
         side,
         [{v, weight} | rest],
         queue,
         dist_own,
         dist_other,
         pred_own,
         pred_other,
         u,
         dist_u,
         add,
         compare,
         best_path,
         best_weight
       ) do
    new_dist_v = add.(dist_u, weight)
    current_best_v = Map.get(dist_own, v)

    if is_nil(current_best_v) or compare.(new_dist_v, current_best_v) == :lt do
      new_queue = PQ.push(queue, {new_dist_v, v})
      new_dist_own = Map.put(dist_own, v, new_dist_v)
      new_pred_own = Map.put(pred_own, v, u)

      # Determine pred_fwd and pred_bwd for path reconstruction
      {p_fwd, p_bwd} =
        if side == :fwd, do: {new_pred_own, pred_other}, else: {pred_other, new_pred_own}

      {updated_path, updated_weight} =
        check_meeting_point(
          v,
          new_dist_v,
          dist_other,
          p_fwd,
          p_bwd,
          add,
          compare,
          best_path,
          best_weight
        )

      process_neighbors(
        side,
        rest,
        new_queue,
        new_dist_own,
        dist_other,
        new_pred_own,
        pred_other,
        u,
        dist_u,
        add,
        compare,
        updated_path,
        updated_weight
      )
    else
      process_neighbors(
        side,
        rest,
        queue,
        dist_own,
        dist_other,
        pred_own,
        pred_other,
        u,
        dist_u,
        add,
        compare,
        best_path,
        best_weight
      )
    end
  end

  # Check if a node reached from one side has been reached by the other side
  defp check_meeting_point(
         node,
         dist_side,
         dist_other,
         pred_fwd,
         pred_bwd,
         add,
         compare,
         best_path,
         best_weight
       ) do
    case Map.fetch(dist_other, node) do
      {:ok, d_other} ->
        total_dist = add.(dist_side, d_other)

        if is_nil(best_weight) or compare.(total_dist, best_weight) == :lt do
          path = reconstruct_bidirectional_path(node, pred_fwd, pred_bwd)
          {path, total_dist}
        else
          {best_path, best_weight}
        end

      :error ->
        {best_path, best_weight}
    end
  end

  # Reconstruct path from meeting point
  defp reconstruct_bidirectional_path(meeting_point, pred_fwd, pred_bwd) do
    fwd_path = reconstruct_path_to_source(pred_fwd, meeting_point, [meeting_point])
    bwd_path = reconstruct_path_to_target(pred_bwd, meeting_point, [])
    fwd_path ++ bwd_path
  end

  # Walk backwards from meeting_point to source, building path in correct order
  defp reconstruct_path_to_source(pred, node, acc) do
    case Map.fetch(pred, node) do
      {:ok, parent} -> reconstruct_path_to_source(pred, parent, [parent | acc])
      :error -> acc
    end
  end

  # Walk backwards from meeting_point to target (following pred_bwd which goes toward target)
  defp reconstruct_path_to_target(pred, node, acc) do
    case Map.fetch(pred, node) do
      {:ok, next} -> reconstruct_path_to_target(pred, next, [next | acc])
      :error -> Enum.reverse(acc)
    end
  end
end
