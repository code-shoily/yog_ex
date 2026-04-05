defmodule Yog.Traversal.Walk do
  @moduledoc """
  Graph walking algorithms — BFS, DFS, Best-First, and Random traversals.

  This module provides a unified API for exploring graphs starting from a given node.
  It supports both standard discovery (BFS, DFS) and informed discovery where the
  next nodes are prioritized based on weights, heuristics, or randomness.
  """

  @type order :: :breadth_first | :depth_first | :best_first | :random
  @type walk_control :: :continue | :stop | :halt
  @type walk_metadata :: %{depth: integer(), parent: Yog.node_id() | nil}
  @type priority_fn :: (Yog.node_id(), number(), walk_metadata() -> number())

  @doc """
  Walks the graph starting from the given node, visiting all reachable nodes.

  ## Options

  - `:from` - Starting node ID
  - `:in` - The graph to traverse
  - `:using` - Traversal order. Options:
    - `:breadth_first` (BFS)
    - `:depth_first` (DFS)
    - `:best_first` - Prioritizes discovery based on a `:priority` function.
    - `:random` - Randomizes discovery order.
  - `:priority` - Required if `:using` is `:best_first`. A function taking `(node_id, weight, meta)`.

  ## Examples

      # Simple BFS walk
      iex> graph = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil)
      iex> Yog.Traversal.Walk.walk(in: graph, from: 1, using: :breadth_first)
      [1, 2]

      # Greedy walk using edge weights (lowest weight first)
      iex> graph = Yog.directed() |> Yog.add_edge_ensure(1, 2, 10, nil) |> Yog.add_edge_ensure(1, 3, 5, nil)
      iex> Yog.Traversal.Walk.walk(in: graph, from: 1, using: :best_first, priority: fn _, w, _ -> w end)
      [1, 3, 2]
  """
  @spec walk(keyword()) :: [Yog.node_id()]
  def walk(opts) do
    from = Keyword.fetch!(opts, :from)
    graph = Keyword.fetch!(opts, :in)
    order = Keyword.fetch!(opts, :using)

    fold_walk(
      over: graph,
      from: from,
      using: order,
      priority: Keyword.get(opts, :priority, fn _id, _weight, _meta -> 0 end),
      initial: [],
      with: fn acc, node_id, _meta -> {:continue, [node_id | acc]} end
    )
    |> Enum.reverse()
  end

  @spec walk(Yog.graph(), Yog.node_id(), order()) :: [Yog.node_id()]
  def walk(graph, from, order) do
    walk(in: graph, from: from, using: order)
  end

  @doc """
  Walks the graph but stops early when a condition is met.
  """
  @spec walk_until(keyword()) :: [Yog.node_id()]
  def walk_until(opts) do
    from = Keyword.fetch!(opts, :from)
    graph = Keyword.fetch!(opts, :in)
    order = Keyword.fetch!(opts, :using)
    should_stop = Keyword.fetch!(opts, :until)

    fold_walk(
      over: graph,
      from: from,
      using: order,
      priority: Keyword.get(opts, :priority, fn _id, _weight, _meta -> 0 end),
      initial: [],
      with: fn acc, node_id, _meta ->
        new_acc = [node_id | acc]

        if should_stop.(node_id) do
          {:halt, new_acc}
        else
          {:continue, new_acc}
        end
      end
    )
    |> Enum.reverse()
  end

  @spec walk_until(Yog.graph(), Yog.node_id(), order(), (Yog.node_id() -> boolean())) ::
          [Yog.node_id()]
  def walk_until(graph, from, order, should_stop) do
    walk_until(in: graph, from: from, using: order, until: should_stop)
  end

  @doc """
  Folds over nodes during graph traversal, accumulating state with metadata.

  The folder function receives `(accumulator, node_id, metadata)` and should
  return `{control, new_accumulator}`.

  ## Metadata
  The metadata map contains:
  - `:depth` - Distance from the starting node.
  - `:parent` - The node ID that led to this node.

  ## Control Signals
  - `:continue` - Continue traversal normally.
  - `:stop` - Do not explore successors of the current node, but continue with the rest of the frontier.
  - `:halt` - Stop the entire traversal immediately.
  """
  @spec fold_walk(keyword()) :: any()
  def fold_walk(opts) do
    graph = Keyword.fetch!(opts, :over)
    from = Keyword.fetch!(opts, :from)
    order = Keyword.fetch!(opts, :using)
    initial = Keyword.fetch!(opts, :initial)
    folder = Keyword.fetch!(opts, :with)

    start_metadata = %{depth: 0, parent: nil}
    out_edges = graph.out_edges

    case order do
      :breadth_first ->
        do_fold_walk_bfs(
          out_edges,
          :queue.in({from, start_metadata}, :queue.new()),
          MapSet.new(),
          initial,
          folder
        )

      :depth_first ->
        do_fold_walk_dfs(
          out_edges,
          [{from, start_metadata}],
          MapSet.new(),
          initial,
          folder
        )

      :best_first ->
        priority_fn = Keyword.fetch!(opts, :priority)

        do_fold_walk_best_first(
          out_edges,
          Yog.PriorityQueue.new(fn {p1, _}, {p2, _} -> p1 <= p2 end)
          |> Yog.PriorityQueue.push({0, {from, start_metadata}}),
          MapSet.new(),
          initial,
          folder,
          priority_fn
        )

      :random ->
        do_fold_walk_best_first(
          out_edges,
          Yog.PriorityQueue.new(fn {p1, _}, {p2, _} -> p1 <= p2 end)
          |> Yog.PriorityQueue.push({0, {from, start_metadata}}),
          MapSet.new(),
          initial,
          folder,
          fn _id, _weight, _meta -> :rand.uniform() end
        )
    end
  end

  @spec fold_walk(
          Yog.graph(),
          Yog.node_id(),
          order(),
          acc,
          (acc, Yog.node_id(), walk_metadata() -> {walk_control(), acc})
        ) :: acc
        when acc: var
  def fold_walk(graph, from, order, initial, folder) do
    fold_walk(over: graph, from: from, using: order, initial: initial, with: folder)
  end

  @doc """
  Finds the shortest path between two nodes using BFS.
  """
  @spec find_path(Yog.graph(), Yog.node_id(), Yog.node_id()) :: [Yog.node_id()] | nil
  def find_path(graph, from, to) do
    parents =
      fold_walk(
        over: graph,
        from: from,
        using: :breadth_first,
        initial: %{},
        with: fn acc, node_id, meta ->
          new_acc =
            if meta.parent && !Map.has_key?(acc, node_id) do
              Map.put(acc, node_id, meta.parent)
            else
              acc
            end

          if node_id == to do
            {:halt, new_acc}
          else
            {:continue, new_acc}
          end
        end
      )

    cond do
      from == to ->
        [from]

      !Map.has_key?(parents, to) ->
        nil

      true ->
        reconstruct_path(parents, to, [to])
    end
  end

  defp reconstruct_path(_parents, node, acc) when node == nil, do: acc

  defp reconstruct_path(parents, node, acc) do
    case Map.get(parents, node) do
      nil -> acc
      parent -> reconstruct_path(parents, parent, [parent | acc])
    end
  end

  @doc """
  Performs a random walk of fixed length from the given starting node.

  Unlike discovery traversals (BFS/DFS), a random walk does not keep track
  of visited nodes and may cross the same node or edge multiple times.

  ## Parameters
  - `graph`: The graph to walk.
  - `from`: The starting node ID.
  - `steps`: The number of jumps/edges to transition (path length in edges).

  ## Examples

      iex> graph = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil) |> Yog.add_edge_ensure(2, 1, 1, nil)
      iex> path = Yog.Traversal.Walk.random_walk(graph, 1, 3)
      iex> length(path)
      4
  """
  @spec random_walk(Yog.graph(), Yog.node_id(), integer()) :: [Yog.node_id()]
  def random_walk(graph, from, steps) do
    do_random_walk(graph.out_edges, from, steps, [from])
  end

  defp do_random_walk(_out_edges, _current, 0, acc), do: Enum.reverse(acc)

  defp do_random_walk(out_edges, current, steps, acc) do
    case Map.fetch(out_edges, current) do
      {:ok, edges} when map_size(edges) > 0 ->
        {next, _} = Enum.random(edges)
        do_random_walk(out_edges, next, steps - 1, [next | acc])

      _ ->
        Enum.reverse(acc)
    end
  end

  @doc """
  Checks if there is a path between two nodes.
  """
  @spec reachable?(Yog.graph(), Yog.node_id(), Yog.node_id()) :: boolean()
  def reachable?(graph, from, to) do
    find_path(graph, from, to) != nil
  end

  # BFS with fold and metadata
  # Uses direct out_edges access for performance
  defp do_fold_walk_bfs(out_edges, q, visited, acc, folder) do
    case :queue.out(q) do
      {:empty, _} ->
        acc

      {{:value, {node_id, metadata}}, rest} ->
        if MapSet.member?(visited, node_id) do
          do_fold_walk_bfs(out_edges, rest, visited, acc, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_id)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_fold_walk_bfs(out_edges, rest, new_visited, new_acc, folder)

            :continue ->
              next_queue =
                case Map.fetch(out_edges, node_id) do
                  {:ok, edges} ->
                    :maps.fold(
                      fn next_id, _weight, current_queue ->
                        next_meta = %{
                          depth: metadata.depth + 1,
                          parent: node_id
                        }

                        :queue.in({next_id, next_meta}, current_queue)
                      end,
                      rest,
                      edges
                    )

                  :error ->
                    rest
                end

              do_fold_walk_bfs(out_edges, next_queue, new_visited, new_acc, folder)
          end
        end
    end
  end

  # DFS with fold and metadata
  # Uses direct out_edges access for performance
  defp do_fold_walk_dfs(out_edges, stack, visited, acc, folder) do
    case stack do
      [] ->
        acc

      [{node_id, metadata} | tail] ->
        if MapSet.member?(visited, node_id) do
          do_fold_walk_dfs(out_edges, tail, visited, acc, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_id)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_fold_walk_dfs(out_edges, tail, new_visited, new_acc, folder)

            :continue ->
              next_stack =
                case Map.fetch(out_edges, node_id) do
                  {:ok, edges} ->
                    :maps.fold(
                      fn next_id, _weight, current_stack ->
                        next_meta = %{
                          depth: metadata.depth + 1,
                          parent: node_id
                        }

                        [{next_id, next_meta} | current_stack]
                      end,
                      tail,
                      edges
                    )

                  :error ->
                    tail
                end

              do_fold_walk_dfs(out_edges, next_stack, new_visited, new_acc, folder)
          end
        end
    end
  end

  # Best-first with fold and metadata
  # Uses direct out_edges access for performance
  defp do_fold_walk_best_first(out_edges, pq, visited, acc, folder, priority_fn) do
    case Yog.PriorityQueue.pop(pq) do
      :error ->
        acc

      {:ok, {_priority, {node_id, metadata}}, rest_pq} ->
        if MapSet.member?(visited, node_id) do
          do_fold_walk_best_first(out_edges, rest_pq, visited, acc, folder, priority_fn)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_id)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_fold_walk_best_first(
                out_edges,
                rest_pq,
                new_visited,
                new_acc,
                folder,
                priority_fn
              )

            :continue ->
              next_pq =
                case Map.fetch(out_edges, node_id) do
                  {:ok, edges} ->
                    :maps.fold(
                      fn next_id, weight, current_pq ->
                        next_meta = %{
                          depth: metadata.depth + 1,
                          parent: node_id
                        }

                        p = priority_fn.(next_id, weight, next_meta)
                        Yog.PriorityQueue.push(current_pq, {p, {next_id, next_meta}})
                      end,
                      rest_pq,
                      edges
                    )

                  :error ->
                    rest_pq
                end

              do_fold_walk_best_first(
                out_edges,
                next_pq,
                new_visited,
                new_acc,
                folder,
                priority_fn
              )
          end
        end
    end
  end
end
