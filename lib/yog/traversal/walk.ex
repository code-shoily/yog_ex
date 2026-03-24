defmodule Yog.Traversal.Walk do
  @moduledoc """
  Graph walking algorithms — BFS and DFS traversals with fold support and path finding.
  """

  alias Yog.Model

  @type order :: :breadth_first | :depth_first
  @type walk_control :: :continue | :stop | :halt
  @type walk_metadata :: %{depth: integer(), parent: Yog.node_id() | nil}

  @doc """
  Walks the graph starting from the given node, visiting all reachable nodes.

  ## Options

  - `:from` - Starting node ID
  - `:in` - The graph to traverse
  - `:using` - Traversal order (`:breadth_first` or `:depth_first`)
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
  """
  @spec fold_walk(keyword()) :: any()
  def fold_walk(opts) do
    graph = Keyword.fetch!(opts, :over)
    from = Keyword.fetch!(opts, :from)
    order = Keyword.fetch!(opts, :using)
    initial = Keyword.fetch!(opts, :initial)
    folder = Keyword.fetch!(opts, :with)

    start_metadata = %{depth: 0, parent: nil}

    case order do
      :breadth_first ->
        do_fold_walk_bfs(
          graph,
          :queue.in({from, start_metadata}, :queue.new()),
          MapSet.new(),
          initial,
          folder
        )

      :depth_first ->
        do_fold_walk_dfs(
          graph,
          [{from, start_metadata}],
          MapSet.new(),
          initial,
          folder
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

  # BFS with fold and metadata
  defp do_fold_walk_bfs(graph, q, visited, acc, folder) do
    case :queue.out(q) do
      {:empty, _} ->
        acc

      {{:value, {node_id, metadata}}, rest} ->
        if MapSet.member?(visited, node_id) do
          do_fold_walk_bfs(graph, rest, visited, acc, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_id)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_fold_walk_bfs(graph, rest, new_visited, new_acc, folder)

            :continue ->
              next_nodes = Model.successor_ids(graph, node_id)

              next_queue =
                Enum.reduce(next_nodes, rest, fn next_id, current_queue ->
                  next_meta = %{
                    depth: metadata.depth + 1,
                    parent: node_id
                  }

                  :queue.in({next_id, next_meta}, current_queue)
                end)

              do_fold_walk_bfs(graph, next_queue, new_visited, new_acc, folder)
          end
        end
    end
  end

  # DFS with fold and metadata
  defp do_fold_walk_dfs(graph, stack, visited, acc, folder) do
    case stack do
      [] ->
        acc

      [{node_id, metadata} | tail] ->
        if MapSet.member?(visited, node_id) do
          do_fold_walk_dfs(graph, tail, visited, acc, folder)
        else
          {control, new_acc} = folder.(acc, node_id, metadata)
          new_visited = MapSet.put(visited, node_id)

          case control do
            :halt ->
              new_acc

            :stop ->
              do_fold_walk_dfs(graph, tail, new_visited, new_acc, folder)

            :continue ->
              next_nodes = Model.successor_ids(graph, node_id)

              next_stack =
                Enum.reduce(Enum.reverse(next_nodes), tail, fn next_id, current_stack ->
                  next_meta = %{
                    depth: metadata.depth + 1,
                    parent: node_id
                  }

                  [{next_id, next_meta} | current_stack]
                end)

              do_fold_walk_dfs(graph, next_stack, new_visited, new_acc, folder)
          end
        end
    end
  end
end
