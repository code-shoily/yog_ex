defmodule Yog.Multi.Traversal do
  @moduledoc """
  Traversal operations for multigraphs.

  Unlike simple graphs, multigraph traversals use edge IDs to correctly
  handle parallel edges — each **edge** is traversed at most once, but a
  node may be reached via multiple edges.
  """

  alias Yog.Multi.Model

  @typedoc "Control flow for fold_walk traversal"
  @type walk_control :: :continue | :stop | :halt

  @typedoc "Metadata provided during fold_walk traversal"
  @type walk_metadata :: %{
          depth: integer(),
          parent: {Yog.node_id(), Model.edge_id()} | nil
        }

  @doc """
  Performs a Breadth-First Search from `source`, returning visited node IDs
  in BFS order.

  Unlike simple-graph BFS, this traversal uses edge IDs to correctly handle
  parallel edges — each **edge** is traversed at most once, but a node may be
  reached via multiple edges (the first visit wins for ordering purposes).

  ## Time Complexity

  O(V + E)

  ## Examples

      nodes = Yog.Multi.Traversal.bfs(multi, :a)
      #=> [:a, :b, :c, :d]
  """
  @spec bfs(Model.t(), Yog.node_id()) :: [Yog.node_id()]
  def bfs(graph, source) do
    do_bfs(graph, [source], MapSet.new([source]), MapSet.new(), [])
  end

  defp do_bfs(_graph, [], _visited_nodes, _visited_edges, result) do
    Enum.reverse(result)
  end

  defp do_bfs(graph, [current | rest], visited_nodes, visited_edges, result) do
    # Add current node to result (we're processing it now)
    new_result = [current | result]

    successors = Model.successors(graph, current)

    {new_queue, new_visited_nodes, new_visited_edges} =
      Enum.reduce(successors, {rest, visited_nodes, visited_edges}, &bfs_fold/2)

    do_bfs(graph, new_queue, new_visited_nodes, new_visited_edges, new_result)
  end

  defp bfs_fold({neighbor, edge_id, _data}, {q, vn, ve}) do
    if MapSet.member?(ve, edge_id) do
      {q, vn, ve}
    else
      new_ve = MapSet.put(ve, edge_id)
      handle_neighbor_visit(neighbor, q, vn, new_ve)
    end
  end

  defp handle_neighbor_visit(neighbor, q, vn, ve) do
    if MapSet.member?(vn, neighbor) do
      {q, vn, ve}
    else
      new_vn = MapSet.put(vn, neighbor)
      {q ++ [neighbor], new_vn, ve}
    end
  end

  @doc """
  Performs a Depth-First Search from `source`, returning visited node IDs
  in DFS pre-order.

  ## Time Complexity

  O(V + E)

  ## Examples

      nodes = Yog.Multi.Traversal.dfs(multi, :a)
      #=> [:a, :b, :d, :c]
  """
  @spec dfs(Model.t(), Yog.node_id()) :: [Yog.node_id()]
  def dfs(graph, source) do
    {_, result} = do_dfs(graph, source, MapSet.new(), MapSet.new(), [])
    Enum.reverse(result)
  end

  defp do_dfs(graph, current, visited_nodes, visited_edges, result) do
    {_, ve, r} = do_dfs_with_nodes(graph, current, visited_nodes, visited_edges, result)
    {ve, r}
  end

  defp do_dfs_successors([], _graph, visited_nodes, visited_edges, result) do
    {visited_nodes, visited_edges, result}
  end

  defp do_dfs_successors(
         [{neighbor, edge_id, _} | rest],
         graph,
         visited_nodes,
         visited_edges,
         result
       ) do
    if MapSet.member?(visited_edges, edge_id) do
      do_dfs_successors(rest, graph, visited_nodes, visited_edges, result)
    else
      new_ve = MapSet.put(visited_edges, edge_id)
      {vn2, ve2, r2} = do_dfs_with_nodes(graph, neighbor, visited_nodes, new_ve, result)
      do_dfs_successors(rest, graph, vn2, ve2, r2)
    end
  end

  # Helper that returns {visited_nodes, visited_edges, result}
  defp do_dfs_with_nodes(graph, current, visited_nodes, visited_edges, result) do
    if MapSet.member?(visited_nodes, current) do
      {visited_nodes, visited_edges, result}
    else
      new_vn = MapSet.put(visited_nodes, current)
      new_result = [current | result]

      successors = Model.successors(graph, current)
      do_dfs_successors(successors, graph, new_vn, visited_edges, new_result)
    end
  end

  @doc """
  Folds over nodes during multigraph traversal, accumulating state with metadata.

  This function combines traversal with state accumulation, providing metadata
  about each visited node including which specific edge was used to reach it.
  The folder function controls the traversal flow:

  - `:continue` - Explore successors of the current node normally
  - `:stop` - Skip successors of this node, but continue with other queued nodes
  - `:halt` - Stop the entire traversal immediately and return the accumulator

  For multigraphs, the metadata includes the specific `EdgeId` used to reach
  each node, which is important when parallel edges exist.

  ## Time Complexity

  O(V + E)

  ## Examples

      # Build a parent map tracking which edge led to each node
      parents = Yog.Multi.Traversal.fold_walk(multi, :a, %{}, fn acc, node_id, meta ->
        new_acc = case meta.parent do
          {parent_node, edge_id} -> Map.put(acc, node_id, {parent_node, edge_id})
          nil -> acc
        end
        {:continue, new_acc}
      end)

      # Find all nodes within distance 3
      nearby = Yog.Multi.Traversal.fold_walk(multi, :a, [], fn acc, node_id, meta ->
        if meta.depth <= 3 do
          {:continue, [node_id | acc]}
        else
          {:stop, acc}
        end
      end)
  """
  @spec fold_walk(
          Model.t(),
          Yog.node_id(),
          acc,
          (acc, Yog.node_id(), walk_metadata() -> {walk_control(), acc})
        ) :: acc
        when acc: var
  def fold_walk(graph, from, initial, folder) do
    do_fold_walk(
      graph,
      # Queue: {node, parent_node, edge_id}
      [{from, nil, nil}],
      # Depth map
      %{from => 0},
      # Visited edges
      MapSet.new(),
      initial,
      folder
    )
  end

  defp do_fold_walk(_graph, [], _depths, _visited_edges, acc, _folder) do
    acc
  end

  defp do_fold_walk(
         graph,
         [{current, parent, edge_id} | rest],
         depths,
         visited_edges,
         acc,
         folder
       ) do
    depth = Map.fetch!(depths, current)

    meta = %{
      depth: depth,
      parent: if(parent, do: {parent, edge_id}, else: nil)
    }

    case folder.(acc, current, meta) do
      {:halt, new_acc} ->
        new_acc

      {:stop, new_acc} ->
        do_fold_walk(graph, rest, depths, visited_edges, new_acc, folder)

      {:continue, new_acc} ->
        successors = Model.successors(graph, current)

        {new_queue, new_depths, new_visited} =
          Enum.reduce(successors, {rest, depths, visited_edges}, fn succ, acc2 ->
            fold_walk_reducer(succ, current, depth, acc2)
          end)

        do_fold_walk(graph, new_queue, new_depths, new_visited, new_acc, folder)
    end
  end

  defp fold_walk_reducer({neighbor, succ_edge_id, _data}, current, depth, acc2 = {q, d, ve}) do
    if MapSet.member?(ve, succ_edge_id) do
      acc2
    else
      new_ve = MapSet.put(ve, succ_edge_id)
      new_d = Map.put_new(d, neighbor, depth + 1)
      {q ++ [{neighbor, current, succ_edge_id}], new_d, new_ve}
    end
  end
end
