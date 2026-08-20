defmodule Yog.DAG.Algorithm do
  @moduledoc """
  Algorithms for Directed Acyclic Graphs (DAGs).

  These algorithms leverage the acyclic structure of DAGs to provide
  efficient, total functions for operations like topological sorting,
  longest path, transitive closure, and more.
  """

  alias Yog.DAG
  alias Yog.Pathfinding.Path

  @doc """
  Returns a topological ordering of all nodes in the DAG.

  In a topological ordering, every node appears before all nodes it has edges to.
  This is useful for scheduling tasks with dependencies, build systems, etc.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, nil)
      ...>   |> Yog.add_node(2, nil)
      ...>   |> Yog.add_node(3, nil)
      ...>   |> Yog.add_node(4, nil)
      ...>   |> Yog.add_edge_ensure(1, 2, 1)
      ...>   |> Yog.add_edge_ensure(1, 3, 1)
      ...>   |> Yog.add_edge_ensure(2, 4, 1)
      ...>   |> Yog.add_edge_ensure(3, 4, 1)
      ...> )
      iex> sorted = Yog.DAG.Algorithm.topological_sort(dag)
      iex> hd(sorted)
      1
      iex> List.last(sorted)
      4
  """
  @spec topological_sort(DAG.t()) :: [Yog.node_id()]
  def topological_sort(%DAG{graph: graph}) do
    case Yog.Traversal.topological_sort(graph) do
      {:ok, sorted} ->
        sorted

      {:error, :contains_cycle} ->
        raise RuntimeError, "DAG invariant violated: graph contains a cycle"
    end
  end

  def topological_sort(dag) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  @doc """
  Returns the topological generations of a DAG.

  Each generation is a list of nodes with the same longest-path distance
  from a source. Nodes within the same generation are independent and can
  be processed in parallel.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_node(:d, nil)
      ...>   |> Yog.add_edge_ensure(:a, :b, 1)
      ...>   |> Yog.add_edge_ensure(:a, :c, 1)
      ...>   |> Yog.add_edge_ensure(:b, :d, 1)
      ...>   |> Yog.add_edge_ensure(:c, :d, 1)
      ...> )
      iex> Yog.DAG.Algorithm.topological_generations(dag)
      [[:a], [:b, :c], [:d]]
  """
  @spec topological_generations(DAG.t()) :: [[Yog.node_id()]]
  def topological_generations(%DAG{graph: graph}) do
    {in_degrees, initial_zeros} =
      Enum.reduce(Yog.Model.all_nodes(graph), {%{}, []}, fn node, {deg_acc, zero_acc} ->
        deg = Yog.Model.in_degree(graph, node)

        {
          Map.put(deg_acc, node, deg),
          if(deg == 0, do: [node | zero_acc], else: zero_acc)
        }
      end)

    do_generations(graph, in_degrees, initial_zeros, [])
  end

  def topological_generations(dag) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  defp do_generations(_graph, _in_degrees, [], acc) do
    acc
    |> Enum.reverse()
    |> Enum.map(&Enum.sort/1)
  end

  defp do_generations(graph, in_degrees, current_generation, acc) do
    {next_in_degrees, next_generation} =
      List.foldl(current_generation, {in_degrees, []}, fn node, {degrees_acc, next_gen_acc} ->
        List.foldl(Yog.Model.successor_ids(graph, node), {degrees_acc, next_gen_acc}, fn succ,
                                                                                         {d, gen} ->
          new_deg = Map.fetch!(d, succ) - 1

          # Queue successors dynamically the moment all their prerequisites finish
          new_gen = if new_deg == 0, do: [succ | gen], else: gen

          {Map.put(d, succ, new_deg), new_gen}
        end)
      end)

    do_generations(graph, next_in_degrees, next_generation, [current_generation | acc])
  end

  @doc """
  Finds the longest path (critical path) in a weighted DAG.

  The longest path is the path with maximum total edge weight from any source
  node to any sink node.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_edge_ensure(:a, :b, 5)
      ...>   |> Yog.add_edge_ensure(:b, :c, 3)
      ...> )
      iex> path = Yog.DAG.Algorithm.longest_path(dag)
      iex> length(path)
      3
  """
  @spec longest_path(DAG.t()) :: [Yog.node_id()]
  def longest_path(%DAG{} = dag) do
    graph = dag.graph
    sorted_nodes = topological_sort(dag)

    {distances, predecessors} =
      Enum.reduce(sorted_nodes, {%{}, %{}}, fn node, {dist_acc, pred_acc} ->
        node_dist = Map.get(dist_acc, node, 0)
        out_edges = Yog.Model.successors(graph, node) |> Map.new()

        update_longest_distances(out_edges, node, node_dist, dist_acc, pred_acc)
      end)

    all_distances =
      Enum.reduce(sorted_nodes, distances, fn node, acc ->
        Map.put_new(acc, node, 0)
      end)

    {max_node, _max_dist} =
      all_distances
      |> Enum.max_by(fn {_node, dist} -> dist end, fn -> {nil, 0} end)

    if max_node do
      reconstruct_path_backward(max_node, nil, predecessors, [])
    else
      []
    end
  end

  def longest_path(dag) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  @doc """
  Finds the shortest path between two nodes in a weighted DAG.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_edge_ensure(:a, :b, 3)
      ...>   |> Yog.add_edge_ensure(:b, :c, 2)
      ...> )
      iex> {:ok, path} = Yog.DAG.Algorithm.shortest_path(dag, :a, :c)
      iex> path.nodes == [:a, :b, :c] and path.weight == 5
      true
  """
  @spec shortest_path(DAG.t(), Yog.node_id(), Yog.node_id()) ::
          {:ok, Path.t()} | :error
  def shortest_path(%DAG{graph: graph} = dag, from, to) do
    if Yog.Model.has_node?(graph, from) and Yog.Model.has_node?(graph, to) do
      sorted_nodes = topological_sort(dag)
      relevant_nodes = Enum.drop_while(sorted_nodes, fn node -> node != from end)

      if relevant_nodes == [] do
        :error
      else
        {distances, predecessors} = solve_shortest_path_dp(relevant_nodes, from, graph)

        case Map.fetch(distances, to) do
          {:ok, total_dist} ->
            path = reconstruct_path_backward(to, from, predecessors, [])
            {:ok, Path.new(path, total_dist)}

          _ ->
            :error
        end
      end
    else
      :error
    end
  end

  def shortest_path(dag, _from, _to) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  @doc """
  Finds the lowest common ancestors (LCAs) of two nodes.

  Time complexity: $\\mathcal{O}(V \\cdot (V + E))$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:x, nil)
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_edge_ensure(:x, :a, 1)
      ...>   |> Yog.add_edge_ensure(:x, :b, 1)
      ...> )
      iex> lcas = Yog.DAG.Algorithm.lowest_common_ancestors(dag, :a, :b)
      iex> :x in lcas
      true
  """
  @spec lowest_common_ancestors(DAG.t(), Yog.node_id(), Yog.node_id()) ::
          [Yog.node_id()]
  def lowest_common_ancestors(%DAG{graph: graph} = dag, node_a, node_b) do
    if Yog.Model.has_node?(graph, node_a) and Yog.Model.has_node?(graph, node_b) do
      ancestors_a = get_ancestors_set(dag, node_a)
      ancestors_b = get_ancestors_set(dag, node_b)

      common_ancestors =
        MapSet.intersection(ancestors_a, ancestors_b)
        |> MapSet.to_list()

      Enum.filter(common_ancestors, fn candidate ->
        is_ancestor_of_another =
          Enum.any?(common_ancestors, fn other ->
            candidate != other and Yog.Traversal.reachable?(graph, candidate, other)
          end)

        not is_ancestor_of_another
      end)
    else
      []
    end
  end

  def lowest_common_ancestors(dag, _node_a, _node_b) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  @doc """
  Returns all source nodes (nodes with in-degree 0).

  Time complexity: $\\mathcal{O}(V)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_edge_ensure(:a, :b, 1)
      ...>   |> Yog.add_edge_ensure(:a, :c, 1)
      ...> )
      iex> Yog.DAG.Algorithm.sources(dag)
      [:a]
  """
  @spec sources(DAG.t()) :: [Yog.node_id()]
  def sources(%DAG{graph: graph}) do
    graph.nodes
    |> Map.keys()
    |> Enum.filter(fn node -> Yog.Model.in_degree(graph, node) == 0 end)
    |> Enum.sort()
  end

  def sources(dag) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  @doc """
  Returns all sink nodes (nodes with out-degree 0).

  Time complexity: $\\mathcal{O}(V)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_edge_ensure(:a, :b, 1)
      ...>   |> Yog.add_edge_ensure(:a, :c, 1)
      ...> )
      iex> Yog.DAG.Algorithm.sinks(dag)
      [:b, :c]
  """
  @spec sinks(DAG.t()) :: [Yog.node_id()]
  def sinks(%DAG{graph: graph}) do
    graph.nodes
    |> Map.keys()
    |> Enum.filter(fn node -> Yog.Model.out_degree(graph, node) == 0 end)
    |> Enum.sort()
  end

  def sinks(dag) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  @doc """
  Returns all ancestors of a node (nodes that have a path to the given node).

  The result includes the node itself.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_edge_ensure(:a, :b, 1)
      ...>   |> Yog.add_edge_ensure(:b, :c, 1)
      ...> )
      iex> Yog.DAG.Algorithm.ancestors(dag, :c)
      [:a, :b, :c]
  """
  @spec ancestors(DAG.t(), Yog.node_id()) :: [Yog.node_id()]
  def ancestors(%DAG{graph: graph} = dag, node) do
    if Yog.Model.has_node?(graph, node) do
      dag |> get_ancestors_set(node) |> MapSet.to_list() |> Enum.sort()
    else
      []
    end
  end

  def ancestors(dag, _node) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  @doc """
  Returns all descendants of a node (nodes reachable from the given node).

  The result includes the node itself.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_edge_ensure(:a, :b, 1)
      ...>   |> Yog.add_edge_ensure(:b, :c, 1)
      ...> )
      iex> Yog.DAG.Algorithm.descendants(dag, :a)
      [:a, :b, :c]
  """
  @spec descendants(DAG.t(), Yog.node_id()) :: [Yog.node_id()]
  def descendants(%DAG{graph: graph}, node) do
    if Yog.Model.has_node?(graph, node) do
      collect_descendants(graph, [node], MapSet.new([node])) |> MapSet.to_list() |> Enum.sort()
    else
      []
    end
  end

  def descendants(dag, _node) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  @doc """
  Computes single-source shortest distances to all reachable nodes.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_edge_ensure(:a, :b, 3)
      ...>   |> Yog.add_edge_ensure(:b, :c, 2)
      ...>   |> Yog.add_edge_ensure(:a, :c, 10)
      ...> )
      iex> Yog.DAG.Algorithm.single_source_distances(dag, :a)
      %{a: 0, b: 3, c: 5}
  """
  @spec single_source_distances(DAG.t(), Yog.node_id()) :: %{Yog.node_id() => number()}
  def single_source_distances(%DAG{graph: graph} = dag, from) do
    if Yog.Model.has_node?(graph, from) do
      sorted_nodes = topological_sort(dag)

      relevant_nodes = Enum.drop_while(sorted_nodes, fn node -> node != from end)

      if relevant_nodes == [] do
        %{}
      else
        {distances, _predecessors} = solve_shortest_path_dp(relevant_nodes, from, graph)
        distances
      end
    else
      %{}
    end
  end

  def single_source_distances(dag, _from) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  @doc """
  Finds the longest path between two specific nodes in a weighted DAG.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_node(:d, nil)
      ...>   |> Yog.add_edge_ensure(:a, :b, 1)
      ...>   |> Yog.add_edge_ensure(:a, :c, 5)
      ...>   |> Yog.add_edge_ensure(:b, :d, 1)
      ...>   |> Yog.add_edge_ensure(:c, :d, 1)
      ...> )
      iex> {:ok, path} = Yog.DAG.Algorithm.longest_path(dag, :a, :d)
      iex> path.nodes
      [:a, :c, :d]
      iex> path.weight
      6
  """
  @spec longest_path(DAG.t(), Yog.node_id(), Yog.node_id()) ::
          {:ok, Path.t()} | :error
  def longest_path(%DAG{graph: graph} = dag, from, to) do
    if Yog.Model.has_node?(graph, from) and Yog.Model.has_node?(graph, to) do
      sorted_nodes = topological_sort(dag)

      relevant_nodes = Enum.drop_while(sorted_nodes, fn node -> node != from end)

      if relevant_nodes == [] do
        :error
      else
        {distances, predecessors} = solve_longest_path_dp(relevant_nodes, from, graph)

        case Map.fetch(distances, to) do
          {:ok, total_dist} ->
            path = reconstruct_path_backward(to, from, predecessors, [])
            {:ok, Path.new(path, total_dist)}

          _ ->
            :error
        end
      end
    else
      :error
    end
  end

  def longest_path(dag, _from, _to) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  @doc """
  Counts the number of distinct paths between two nodes in a DAG.

  Time complexity: $\\mathcal{O}(V + E)$

  ## Example

      iex> {:ok, dag} = Yog.DAG.Model.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(:a, nil)
      ...>   |> Yog.add_node(:b, nil)
      ...>   |> Yog.add_node(:c, nil)
      ...>   |> Yog.add_node(:d, nil)
      ...>   |> Yog.add_edge_ensure(:a, :b, 1)
      ...>   |> Yog.add_edge_ensure(:a, :c, 1)
      ...>   |> Yog.add_edge_ensure(:b, :d, 1)
      ...>   |> Yog.add_edge_ensure(:c, :d, 1)
      ...> )
      iex> Yog.DAG.Algorithm.path_count(dag, :a, :d)
      2
  """
  @spec path_count(DAG.t(), Yog.node_id(), Yog.node_id()) :: non_neg_integer()
  def path_count(%DAG{graph: graph} = dag, from, to) do
    if Yog.Model.has_node?(graph, from) and Yog.Model.has_node?(graph, to) do
      sorted_nodes = topological_sort(dag)

      relevant_nodes = Enum.drop_while(sorted_nodes, fn node -> node != from end)

      if relevant_nodes == [] do
        0
      else
        Enum.reduce(relevant_nodes, %{from => 1}, fn node, counts ->
          count = Map.get(counts, node, 0)

          successors = Yog.Model.successor_ids(graph, node)

          Enum.reduce(successors, counts, fn succ, acc ->
            Map.update(acc, succ, count, &(&1 + count))
          end)
        end)
        |> Map.get(to, 0)
      end
    else
      0
    end
  end

  def path_count(dag, _from, _to) do
    raise ArgumentError, "expected a Yog.DAG struct, got: #{inspect(dag)}"
  end

  # ============================================================
  # Private Helpers
  # ============================================================

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

  defp solve_longest_path_dp(nodes, from, graph) do
    Enum.reduce(nodes, {%{from => 0}, %{}}, fn node, {dist_acc, pred_acc} = acc ->
      node_dist = Map.get(dist_acc, node)

      if node_dist == nil do
        acc
      else
        out_edges = Yog.Model.successors(graph, node) |> Map.new()
        update_longest_distances(out_edges, node, node_dist, dist_acc, pred_acc)
      end
    end)
  end

  defp collect_descendants(_graph, [], visited), do: visited

  defp collect_descendants(graph, [current | rest], visited) do
    succs = Yog.Model.successor_ids(graph, current)

    {new_queue, new_visited} =
      Enum.reduce(succs, {rest, visited}, fn succ, {q_acc, v_acc} ->
        if MapSet.member?(v_acc, succ) do
          {q_acc, v_acc}
        else
          {[succ | q_acc], MapSet.put(v_acc, succ)}
        end
      end)

    collect_descendants(graph, new_queue, new_visited)
  end

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
    graph = dag.graph
    collect_ancestors(graph, [node], MapSet.new([node]))
  end

  defp collect_ancestors(_graph, [], visited), do: visited

  defp collect_ancestors(graph, [current | rest], visited) do
    preds = Yog.Model.predecessor_ids(graph, current)

    {new_queue, new_visited} =
      Enum.reduce(preds, {rest, visited}, fn pred, {q_acc, v_acc} ->
        if MapSet.member?(v_acc, pred) do
          {q_acc, v_acc}
        else
          {[pred | q_acc], MapSet.put(v_acc, pred)}
        end
      end)

    collect_ancestors(graph, new_queue, new_visited)
  end
end
