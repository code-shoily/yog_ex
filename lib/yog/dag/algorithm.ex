defmodule Yog.DAG.Algorithm do
  @moduledoc """
  Algorithms for Directed Acyclic Graphs (DAGs).

  These algorithms leverage the acyclic structure of DAGs to provide
  efficient, total functions for operations like topological sorting,
  longest path, transitive closure, and more.
  """

  alias Yog.DAG.Model
  alias Yog.Pathfinding.Utils, as: PathUtils

  @doc """
  Returns a topological ordering of all nodes in the DAG.

  Unlike `Yog.traversal.topological_sort/1` which returns `{:ok, sorted}` or
  `{:error, :cycle_detected}` (since general graphs may contain cycles), this
  version is **total** - it always returns a valid ordering because the `DAG`
  type guarantees acyclicity.

  In a topological ordering, every node appears before all nodes it has edges to.
  This is useful for scheduling tasks with dependencies, build systems, etc.

  ## Time Complexity

  O(V + E)

  ## Examples

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, nil)
      ...>   |> Yog.add_node(2, nil)
      ...>   |> Yog.add_node(3, nil)
      ...>   |> Yog.add_node(4, nil)
      ...>   |> Yog.add_edge!(1, 2, 1)
      ...>   |> Yog.add_edge!(1, 3, 1)
      ...>   |> Yog.add_edge!(2, 4, 1)
      ...>   |> Yog.add_edge!(3, 4, 1)
      ...> )
      iex> sorted = Yog.DAG.Algorithm.topological_sort(dag)
      iex> hd(sorted)
      1
      iex> List.last(sorted)
      4
  """
  @spec topological_sort(Yog.DAG.t()) :: [Yog.node_id()]
  def topological_sort(dag) do
    graph = Model.to_graph(dag)

    # We can safely unwrap because the graph is proven to be acyclic
    case Yog.Traversal.topological_sort(graph) do
      {:ok, sorted} -> sorted
      # This should never happen since DAG guarantees acyclicity
      {:error, :contains_cycle} -> []
    end
  end

  @doc """
  Finds the longest path (critical path) in a weighted DAG.

  The longest path is the path with maximum total edge weight from any source
  node to any sink node. This is the dual of shortest path and is useful for:
  - Project scheduling (finding the critical path)
  - Dependency chains with durations
  - Determining minimum time to complete all tasks

  ## Time Complexity

  O(V + E) - linear via dynamic programming on the topologically sorted DAG.

  ## Note

  For unweighted graphs, this finds the path with most edges.
  Weights must be non-negative for meaningful results.

  ## Examples

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_edge!(:a, :b, 5)
      ...>   |> Yog.add_edge!(:b, :c, 3)
      ...> )
      iex> path = Yog.DAG.Algorithm.longest_path(dag)
      iex> length(path)
      3
  """
  @spec longest_path(Yog.DAG.t()) :: [Yog.node_id()]
  def longest_path(dag) do
    graph = Model.to_graph(dag)
    sorted_nodes = topological_sort(dag)

    {distances, predecessors} =
      Enum.reduce(sorted_nodes, {%{}, %{}}, fn node, {dist_acc, pred_acc} ->
        node_dist = Map.get(dist_acc, node, 0)
        out_edges = Yog.Model.successors(graph, node) |> Map.new()

        update_longest_distances(out_edges, node, node_dist, dist_acc, pred_acc)
      end)

    # Find the node with maximum distance
    {max_node, _max_dist} =
      distances
      |> Enum.max_by(fn {_node, dist} -> dist end, fn -> {nil, 0} end)

    # Reconstruct path by following predecessors backward
    if max_node do
      reconstruct_path_backward(max_node, nil, predecessors, [])
    else
      []
    end
  end

  defp update_longest_distances(edges, node, node_dist, dist_acc, pred_acc) do
    Enum.reduce(edges, {dist_acc, pred_acc}, fn {target, weight}, {d_acc, p_acc} = acc ->
      current_target_dist = Map.get(d_acc, target)
      new_dist = node_dist + weight

      if should_update_longest?(current_target_dist, new_dist) do
        {Map.put(d_acc, target, new_dist), Map.put(p_acc, target, node)}
      else
        acc
      end
    end)
  end

  defp should_update_longest?(nil, _), do: true
  defp should_update_longest?(curr, next), do: next > curr

  @doc """
  Finds the shortest path between two nodes in a weighted DAG.

  Uses dynamic programming on the topologically sorted DAG.

  ## Time Complexity

  O(V + E)

  ## Examples

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_edge!(:a, :b, 3)
      ...>   |> Yog.add_edge!(:b, :c, 2)
      ...> )
      iex> {:some, path} = Yog.DAG.Algorithm.shortest_path(dag, :a, :c)
      iex> {:path, [:a, :b, :c], 5} = path
  """
  @spec shortest_path(Yog.DAG.t(), Yog.node_id(), Yog.node_id()) ::
          {:some, PathUtils.path(any())} | :none
  def shortest_path(dag, from, to) do
    graph = Model.to_graph(dag)
    sorted_nodes = topological_sort(dag)

    # Only consider nodes from 'from' onwards in topological order
    relevant_nodes = Enum.drop_while(sorted_nodes, fn node -> node != from end)

    if relevant_nodes == [] do
      :none
    else
      {distances, predecessors} = solve_shortest_path_dp(relevant_nodes, from, graph)

      case Map.fetch(distances, to) do
        {:ok, total_dist} ->
          path = reconstruct_path_backward(to, from, predecessors, [])
          {:some, PathUtils.path(path, total_dist)}

        :error ->
          :none
      end
    end
  end

  defp solve_shortest_path_dp(nodes, from, graph) do
    Enum.reduce(nodes, {%{from => 0}, %{}}, fn node, {dist_acc, pred_acc} = acc ->
      node_dist = Map.get(dist_acc, node)

      if node_dist == nil do
        acc
      else
        out_edges = Yog.Model.successors(graph, node) |> Map.new()
        relax_edges(out_edges, node, node_dist, dist_acc, pred_acc)
      end
    end)
  end

  defp relax_edges(edges, node, node_dist, dist_acc, pred_acc) do
    Enum.reduce(edges, {dist_acc, pred_acc}, fn {target, weight}, {d_acc, p_acc} = inner_acc ->
      current_target_dist = Map.get(d_acc, target)
      new_dist = node_dist + weight

      if should_update_shortest?(current_target_dist, new_dist) do
        {Map.put(d_acc, target, new_dist), Map.put(p_acc, target, node)}
      else
        inner_acc
      end
    end)
  end

  defp should_update_shortest?(nil, _), do: true
  defp should_update_shortest?(current, new), do: new < current

  @doc """
  Finds the lowest common ancestors (LCAs) of two nodes.

  A common ancestor of nodes A and B is any node that has paths to both A and B.
  The "lowest" common ancestors are those that are not ancestors of any other
  common ancestor - they are the "closest" shared dependencies.

  This is useful for:
  - Finding merge bases in version control
  - Identifying shared dependencies
  - Computing dominators in control flow graphs

  ## Time Complexity

  O(V × (V + E))

  ## Examples

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:x, nil)
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_edge!(:x, :a, 1)
      ...>   |> Yog.add_edge!(:x, :b, 1)
      ...> )
      iex> lcas = Yog.DAG.Algorithm.lowest_common_ancestors(dag, :a, :b)
      iex> :x in lcas
      true
  """
  @spec lowest_common_ancestors(Yog.DAG.t(), Yog.node_id(), Yog.node_id()) ::
          [Yog.node_id()]
  def lowest_common_ancestors(dag, node_a, node_b) do
    graph = Model.to_graph(dag)
    ancestors_a = get_ancestors_set(dag, node_a)
    ancestors_b = get_ancestors_set(dag, node_b)

    # Find intersection
    common_ancestors =
      Enum.filter(ancestors_a, fn a -> a in ancestors_b end)

    # Find "lowest" common ancestors (not ancestors of another common ancestor)
    Enum.filter(common_ancestors, fn candidate ->
      is_ancestor_of_another =
        Enum.any?(common_ancestors, fn other ->
          candidate != other and Yog.Traversal.reachable?(graph, candidate, other)
        end)

      not is_ancestor_of_another
    end)
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp reconstruct_path_backward(current, start, predecessors, path) do
    new_path = [current | path]

    if current == start do
      new_path
    else
      case Map.fetch(predecessors, current) do
        {:ok, prev} ->
          reconstruct_path_backward(prev, start, predecessors, new_path)

        :error ->
          new_path
      end
    end
  end

  defp get_ancestors_set(dag, node) do
    graph = Model.to_graph(dag)
    all_nodes = Yog.all_nodes(graph)

    # Ancestors of X are all nodes Y where X is reachable from Y
    Enum.filter(all_nodes, fn n -> Yog.Traversal.reachable?(graph, n, node) end)
  end
end
