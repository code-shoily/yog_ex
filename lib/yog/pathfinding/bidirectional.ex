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
  # Uses :queue for efficient O(1) queue operations and tracks sizes to avoid O(n) length checks
  defp do_bidirectional_bfs(graph, from, to) do
    queue_fwd = :queue.in({from, [from]}, :queue.new())
    queue_bwd = :queue.in({to, [to]}, :queue.new())
    visited_fwd = %{from => [from]}
    visited_bwd = %{to => [to]}

    do_bfs_step(graph, queue_fwd, queue_bwd, visited_fwd, visited_bwd, 1, 1)
  end

  defp do_bfs_step(graph, queue_fwd, queue_bwd, visited_fwd, visited_bwd, size_fwd, size_bwd) do
    case {:queue.peek(queue_fwd), :queue.peek(queue_bwd)} do
      {:empty, _} ->
        :error

      {_, :empty} ->
        :error

      _ ->
        do_bfs_step_expand(
          graph,
          queue_fwd,
          queue_bwd,
          visited_fwd,
          visited_bwd,
          size_fwd,
          size_bwd
        )
    end
  end

  defp do_bfs_step_expand(
         graph,
         queue_fwd,
         queue_bwd,
         visited_fwd,
         visited_bwd,
         size_fwd,
         size_bwd
       ) do
    if size_fwd <= size_bwd do
      case expand_bfs_level(graph, queue_fwd, visited_fwd, visited_bwd) do
        {:found, new_path, other_path} ->
          full_path = Enum.reverse(new_path) ++ tl(other_path)
          weight = length(new_path) + length(other_path) - 2
          {:ok, Path.new(full_path, weight, :bidirectional_bfs)}

        {:continue, new_queue_fwd, new_visited_fwd, added_count} ->
          do_bfs_step(
            graph,
            new_queue_fwd,
            queue_bwd,
            new_visited_fwd,
            visited_bwd,
            size_fwd - 1 + added_count,
            size_bwd
          )
      end
    else
      case expand_bfs_level(graph, queue_bwd, visited_bwd, visited_fwd) do
        {:found, new_path, other_path} ->
          full_path = Enum.reverse(other_path) ++ tl(new_path)
          weight = length(new_path) + length(other_path) - 2
          {:ok, Path.new(full_path, weight, :bidirectional_bfs)}

        {:continue, new_queue_bwd, new_visited_bwd, added_count} ->
          do_bfs_step(
            graph,
            queue_fwd,
            new_queue_bwd,
            visited_fwd,
            new_visited_bwd,
            size_fwd,
            size_bwd - 1 + added_count
          )
      end
    end
  end

  # Expands one BFS level, checking for intersection with the opposite visited set
  # as soon as each new node is discovered.
  # Returns {:found, path, other_path} | {:continue, new_queue, new_visited, added_count}
  defp expand_bfs_level(graph, queue, visited, other_visited) do
    out_edges = graph.out_edges

    case :queue.out(queue) do
      {{:value, {node, path}}, rest_queue} ->
        successors =
          case Map.fetch(out_edges, node) do
            {:ok, edges} -> Map.keys(edges)
            :error -> []
          end

        expand_neighbors(successors, rest_queue, visited, other_visited, path, 0)

      {:empty, _} ->
        {:continue, queue, visited, 0}
    end
  end

  defp expand_neighbors([], queue, visited, _other_visited, _path, added_count) do
    {:continue, queue, visited, added_count}
  end

  defp expand_neighbors([neighbor | rest], queue, visited, other_visited, path, added_count) do
    if Map.has_key?(visited, neighbor) do
      expand_neighbors(rest, queue, visited, other_visited, path, added_count)
    else
      new_path = [neighbor | path]
      new_visited = Map.put(visited, neighbor, new_path)

      case Map.fetch(other_visited, neighbor) do
        {:ok, other_path} ->
          {:found, new_path, other_path}

        :error ->
          new_queue = :queue.in({neighbor, new_path}, queue)
          expand_neighbors(rest, new_queue, new_visited, other_visited, path, added_count + 1)
      end
    end
  end

  # Bidirectional Dijkstra implementation
  # Runs two Dijkstra searches simultaneously (forward from source, backward from target)
  # and stops when they meet. This is significantly faster than single-direction Dijkstra
  # for point-to-point queries.
  defp do_bidirectional_dijkstra(graph, from, to, zero, add, compare) do
    alias Yog.PairingHeap, as: PQ

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
         _graph,
         q_fwd,
         q_bwd,
         _df,
         _db,
         _pf,
         _pb,
         _from,
         _to,
         _add,
         _compare,
         path,
         weight
       )
       when path != nil and (q_fwd == :empty or q_bwd == :empty) do
    case weight do
      nil -> :error
      _ -> {:ok, Path.new(path, weight, :bidirectional_dijkstra)}
    end
  end

  @dialyzer :no_match
  defp do_bidirectional_dijkstra_step(
         _graph,
         :empty,
         :empty,
         _df,
         _db,
         _pf,
         _pb,
         _from,
         _to,
         _add,
         _compare,
         nil,
         nil
       ) do
    :error
  end

  defp do_bidirectional_dijkstra_step(
         graph,
         q_fwd,
         q_bwd,
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
       ) do
    continue? =
      case best_weight do
        nil ->
          true

        _ ->
          fwd_min =
            case PQ.peek(q_fwd) do
              {:ok, {d, _}} -> compare.(d, best_weight) == :lt
              :error -> false
            end

          bwd_min =
            case PQ.peek(q_bwd) do
              {:ok, {d, _}} -> compare.(d, best_weight) == :lt
              :error -> false
            end

          fwd_min or bwd_min
      end

    # credo:disable-for-next-line Credo.Check.Refactor.NegatedConditionsWithElse
    if not continue? do
      {:ok, Path.new(best_path, best_weight, :bidirectional_dijkstra)}
    else
      expand_fwd? =
        case {PQ.peek(q_fwd), PQ.peek(q_bwd)} do
          {{:ok, {d_fwd, _}}, {:ok, {d_bwd, _}}} -> compare.(d_fwd, d_bwd) != :gt
          {{:ok, _}, :error} -> true
          _ -> false
        end

      if expand_fwd? do
        case PQ.pop(q_fwd) do
          :error ->
            if best_path,
              do: {:ok, Path.new(best_path, best_weight, :bidirectional_dijkstra)},
              else: :error

          {:ok, {dist_u, u}, rest_q_fwd} ->
            case Map.fetch(dist_fwd, u) do
              {:ok, best_dist} when best_dist != dist_u ->
                do_bidirectional_dijkstra_step(
                  graph,
                  rest_q_fwd,
                  q_bwd,
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

              _ ->
                successors =
                  case Map.fetch(graph.out_edges, u) do
                    {:ok, edges} -> Map.to_list(edges)
                    :error -> []
                  end

                {new_q_fwd, new_dist_fwd, new_pred_fwd, new_best_path, new_best_weight} =
                  process_neighbors_fwd(
                    successors,
                    rest_q_fwd,
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
                  new_q_fwd,
                  q_bwd,
                  new_dist_fwd,
                  dist_bwd,
                  new_pred_fwd,
                  pred_bwd,
                  from,
                  to,
                  add,
                  compare,
                  new_best_path,
                  new_best_weight
                )
            end
        end
      else
        case PQ.pop(q_bwd) do
          :error ->
            if best_path,
              do: {:ok, Path.new(best_path, best_weight, :bidirectional_dijkstra)},
              else: :error

          {:ok, {dist_v, v}, rest_q_bwd} ->
            # Check if this node has been settled with a better distance
            case Map.fetch(dist_bwd, v) do
              {:ok, best_dist} when best_dist != dist_v ->
                # Stale entry, skip
                do_bidirectional_dijkstra_step(
                  graph,
                  q_fwd,
                  rest_q_bwd,
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

              _ ->
                predecessors =
                  case Map.fetch(graph.in_edges, v) do
                    {:ok, edges} -> Map.to_list(edges)
                    :error -> []
                  end

                {new_q_bwd, new_dist_bwd, new_pred_bwd, new_best_path, new_best_weight} =
                  process_neighbors_bwd(
                    predecessors,
                    rest_q_bwd,
                    dist_fwd,
                    dist_bwd,
                    pred_fwd,
                    pred_bwd,
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
                  new_q_bwd,
                  dist_fwd,
                  new_dist_bwd,
                  pred_fwd,
                  new_pred_bwd,
                  from,
                  to,
                  add,
                  compare,
                  new_best_path,
                  new_best_weight
                )
            end
        end
      end
    end
  end

  # Process forward neighbors
  defp process_neighbors_fwd(
         [],
         queue,
         dist_fwd,
         _dist_bwd,
         pred_fwd,
         _pred_bwd,
         _u,
         _dist_u,
         _add,
         _compare,
         best_path,
         best_weight
       ) do
    {queue, dist_fwd, pred_fwd, best_path, best_weight}
  end

  defp process_neighbors_fwd(
         [{v, weight} | rest],
         queue,
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
       ) do
    new_dist_v = add.(dist_u, weight)

    case Map.fetch(dist_fwd, v) do
      {:ok, current_dist} ->
        if compare.(new_dist_v, current_dist) == :lt do
          new_queue = PQ.push(queue, {new_dist_v, v})
          new_dist = Map.put(dist_fwd, v, new_dist_v)
          new_pred = Map.put(pred_fwd, v, u)

          {updated_path, updated_weight} =
            check_meeting_point(
              v,
              new_dist_v,
              dist_bwd,
              pred_bwd,
              pred_fwd,
              compare,
              best_path,
              best_weight
            )

          process_neighbors_fwd(
            rest,
            new_queue,
            new_dist,
            dist_bwd,
            new_pred,
            pred_bwd,
            u,
            dist_u,
            add,
            compare,
            updated_path,
            updated_weight
          )
        else
          process_neighbors_fwd(
            rest,
            queue,
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
        end

      :error ->
        new_queue = PQ.push(queue, {new_dist_v, v})
        new_dist = Map.put(dist_fwd, v, new_dist_v)
        new_pred = Map.put(pred_fwd, v, u)

        {updated_path, updated_weight} =
          check_meeting_point(
            v,
            new_dist_v,
            dist_bwd,
            pred_bwd,
            new_pred,
            compare,
            best_path,
            best_weight
          )

        process_neighbors_fwd(
          rest,
          new_queue,
          new_dist,
          dist_bwd,
          new_pred,
          pred_bwd,
          u,
          dist_u,
          add,
          compare,
          updated_path,
          updated_weight
        )
    end
  end

  # Process backward neighbors (predecessors in reverse direction)
  defp process_neighbors_bwd(
         [],
         queue,
         _dist_fwd,
         dist_bwd,
         _pred_fwd,
         pred_bwd,
         _v,
         _dist_v,
         _add,
         _compare,
         best_path,
         best_weight
       ) do
    {queue, dist_bwd, pred_bwd, best_path, best_weight}
  end

  defp process_neighbors_bwd(
         [{u, weight} | rest],
         queue,
         dist_fwd,
         dist_bwd,
         pred_fwd,
         pred_bwd,
         v,
         dist_v,
         add,
         compare,
         best_path,
         best_weight
       ) do
    new_dist_u = add.(dist_v, weight)

    case Map.fetch(dist_bwd, u) do
      {:ok, current_dist} ->
        if compare.(new_dist_u, current_dist) == :lt do
          new_queue = PQ.push(queue, {new_dist_u, u})
          new_dist = Map.put(dist_bwd, u, new_dist_u)
          new_pred = Map.put(pred_bwd, u, v)

          {updated_path, updated_weight} =
            check_meeting_point_bwd(
              u,
              new_dist_u,
              dist_fwd,
              pred_fwd,
              new_pred,
              compare,
              best_path,
              best_weight
            )

          process_neighbors_bwd(
            rest,
            new_queue,
            dist_fwd,
            new_dist,
            pred_fwd,
            new_pred,
            v,
            dist_v,
            add,
            compare,
            updated_path,
            updated_weight
          )
        else
          process_neighbors_bwd(
            rest,
            queue,
            dist_fwd,
            dist_bwd,
            pred_fwd,
            pred_bwd,
            v,
            dist_v,
            add,
            compare,
            best_path,
            best_weight
          )
        end

      :error ->
        new_queue = PQ.push(queue, {new_dist_u, u})
        new_dist = Map.put(dist_bwd, u, new_dist_u)
        new_pred = Map.put(pred_bwd, u, v)

        {updated_path, updated_weight} =
          check_meeting_point_bwd(
            u,
            new_dist_u,
            dist_fwd,
            pred_fwd,
            new_pred,
            compare,
            best_path,
            best_weight
          )

        process_neighbors_bwd(
          rest,
          new_queue,
          dist_fwd,
          new_dist,
          pred_fwd,
          new_pred,
          v,
          dist_v,
          add,
          compare,
          updated_path,
          updated_weight
        )
    end
  end

  # Check if a node from forward search has been reached by backward search
  defp check_meeting_point(
         node,
         dist_fwd_node,
         dist_bwd,
         pred_bwd,
         pred_fwd,
         compare,
         best_path,
         best_weight
       ) do
    case Map.fetch(dist_bwd, node) do
      {:ok, dist_bwd_node} ->
        total_dist = dist_fwd_node + dist_bwd_node

        if best_weight == nil or compare.(total_dist, best_weight) == :lt do
          path = reconstruct_bidirectional_path(node, pred_fwd, pred_bwd)
          {path, total_dist}
        else
          {best_path, best_weight}
        end

      :error ->
        {best_path, best_weight}
    end
  end

  # Check if a node from backward search has been reached by forward search
  defp check_meeting_point_bwd(
         node,
         dist_bwd_node,
         dist_fwd,
         pred_fwd,
         pred_bwd,
         compare,
         best_path,
         best_weight
       ) do
    case Map.fetch(dist_fwd, node) do
      {:ok, dist_fwd_node} ->
        total_dist = dist_fwd_node + dist_bwd_node

        if best_weight == nil or compare.(total_dist, best_weight) == :lt do
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
