defmodule Yog.Multi.Eulerian do
  @moduledoc """
  Eulerian path and circuit detection for multigraphs.

  An **Eulerian path** is a walk that traverses every edge exactly once.
  An **Eulerian circuit** is an Eulerian path that starts and ends at the same node.

  This module provides Hierholzer's algorithm adapted for multigraphs. In
  multigraphs, parallel edges between nodes are handled by using edge IDs rather
  than node pairs, ensuring unambiguous traversal.

  ## Conditions for Eulerian Paths/Circuits

  ### Undirected Graphs

  - **Circuit**: All nodes have even degree and the graph is connected
  - **Path**: Exactly 0 or 2 nodes have odd degree and the graph is connected

  ### Directed Graphs

  - **Circuit**: Every node has equal in-degree and out-degree, and the graph
    is (weakly) connected
  - **Path**: At most one node with (out − in = 1), at most one with
    (in − out = 1), all others balanced; graph must be connected

  ## Time Complexity

  - Detection functions (`has_eulerian_circuit?/1`, `has_eulerian_path?/1`): O(V + E)
  - Finding functions (`find_eulerian_circuit/1`, `find_eulerian_path/1`): O(E)

  ## Examples

      # Check if a graph has an Eulerian circuit
      if Yog.Multi.Eulerian.has_eulerian_circuit?(graph) do
        {:ok, edge_ids} = Yog.Multi.Eulerian.find_eulerian_circuit(graph)
        # Traverse the circuit using edge_ids...
      end

  """

  alias Yog.Multi.Model

  @doc """
  Returns `true` if the multigraph has an Eulerian circuit.

  An Eulerian circuit is a closed walk that traverses every edge exactly once.

  ## Conditions

  - **Undirected:** all nodes have even degree and the graph is connected
  - **Directed:** every node has equal in-degree and out-degree and the
    graph is (weakly) connected

  ## Time Complexity

  O(V + E)

  ## Examples

      # A directed cycle has an Eulerian circuit
      iex> graph = Yog.Multi.Model.directed()
      ...>   |> Yog.Multi.Model.add_node(:a, "A")
      ...>   |> Yog.Multi.Model.add_node(:b, "B")
      ...>   |> Yog.Multi.Model.add_node(:c, "C")
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :a, :b, 1), 0)
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :b, :c, 2), 0)
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :c, :a, 3), 0)
      ...> Yog.Multi.Eulerian.has_eulerian_circuit?(graph)
      true

      # A path does not have an Eulerian circuit
      iex> graph = Yog.Multi.Model.directed()
      ...>   |> Yog.Multi.Model.add_node(:a, "A")
      ...>   |> Yog.Multi.Model.add_node(:b, "B")
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :a, :b, 1), 0)
      ...> Yog.Multi.Eulerian.has_eulerian_circuit?(graph)
      false

      # Empty graph has no circuit
      iex> Yog.Multi.Eulerian.has_eulerian_circuit?(Yog.Multi.Model.directed())
      false
  """
  @spec has_eulerian_circuit?(Model.t()) :: boolean()
  def has_eulerian_circuit?(graph) do
    if map_size(graph.nodes) == 0 do
      false
    else
      check_eulerian_circuit(graph)
    end
  end

  defp check_eulerian_circuit(%{kind: :undirected} = graph) do
    all_even_degree?(graph) and connected?(graph)
  end

  defp check_eulerian_circuit(%{kind: :directed} = graph) do
    all_balanced_degree?(graph) and connected?(graph)
  end

  @doc """
  Returns `true` if the multigraph has an Eulerian path.

  An Eulerian path is an open walk that traverses every edge exactly once.
  Note that any graph with an Eulerian circuit also has an Eulerian path.

  ## Conditions

  - **Undirected:** exactly 0 or 2 nodes have odd degree and the graph is connected
  - **Directed:** at most one node with (out − in = 1), at most one with
    (in − out = 1), all others balanced; graph must be connected

  ## Time Complexity

  O(V + E)

  ## Examples

      # A simple path has an Eulerian path
      iex> graph = Yog.Multi.Model.directed()
      ...>   |> Yog.Multi.Model.add_node(:a, "A")
      ...>   |> Yog.Multi.Model.add_node(:b, "B")
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :a, :b, 1), 0)
      ...> Yog.Multi.Eulerian.has_eulerian_path?(graph)
      true

      # A cycle also has an Eulerian path
      iex> graph = Yog.Multi.Model.directed()
      ...>   |> Yog.Multi.Model.add_node(:a, "A")
      ...>   |> Yog.Multi.Model.add_node(:b, "B")
      ...>   |> Yog.Multi.Model.add_node(:c, "C")
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :a, :b, 1), 0)
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :b, :c, 2), 0)
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :c, :a, 3), 0)
      ...> Yog.Multi.Eulerian.has_eulerian_path?(graph)
      true

      # Empty graph has no path
      iex> Yog.Multi.Eulerian.has_eulerian_path?(Yog.Multi.Model.directed())
      false
  """
  @spec has_eulerian_path?(Model.t()) :: boolean()
  def has_eulerian_path?(graph) do
    if map_size(graph.nodes) == 0 do
      false
    else
      check_eulerian_path(graph)
    end
  end

  defp check_eulerian_path(%{kind: :undirected} = graph) do
    odd_count = count_odd_degree_nodes(graph)
    (odd_count == 0 or odd_count == 2) and connected?(graph)
  end

  defp check_eulerian_path(%{kind: :directed} = graph) do
    {starts, ends, balanced} = analyze_directed_degrees(graph)

    balanced and
      ((starts == 0 and ends == 0) or (starts == 1 and ends == 1)) and
      connected?(graph)
  end

  defp count_odd_degree_nodes(graph) do
    graph.nodes
    |> Map.keys()
    |> Enum.count(fn n -> rem(Model.out_degree(graph, n), 2) == 1 end)
  end

  defp analyze_directed_degrees(graph) do
    graph.nodes
    |> Map.keys()
    |> Enum.reduce({0, 0, true}, fn n, {s, e, ok} ->
      diff = Model.out_degree(graph, n) - Model.in_degree(graph, n)
      update_directed_stats(diff, s, e, ok)
    end)
  end

  defp update_directed_stats(1, s, e, ok), do: {s + 1, e, ok}
  defp update_directed_stats(-1, s, e, ok), do: {s, e + 1, ok}
  defp update_directed_stats(0, s, e, ok), do: {s, e, ok}
  defp update_directed_stats(_, s, e, _ok), do: {s, e, false}

  @doc """
  Finds an Eulerian circuit using Hierholzer's algorithm adapted for multigraphs.

  Returns the circuit as a list of `EdgeId`s, or `:error` if no circuit exists.

  ## Important Note on Multigraphs

  In multigraphs, parallel edges between the same pair of nodes cannot be
  distinguished by node IDs alone. This function returns a list of edge IDs,
  which unambiguously identify which specific edge to traverse at each step.

  ## Time Complexity

  O(E)

  ## Examples

      iex> graph = Yog.Multi.Model.directed()
      ...>   |> Yog.Multi.Model.add_node(:a, "A")
      ...>   |> Yog.Multi.Model.add_node(:b, "B")
      ...>   |> Yog.Multi.Model.add_node(:c, "C")
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :a, :b, 1), 0)
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :b, :c, 2), 0)
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :c, :a, 3), 0)
      ...> case Yog.Multi.Eulerian.find_eulerian_circuit(graph) do
      ...>   {:ok, edge_ids} -> length(edge_ids)
      ...>   :error -> 0
      ...> end
      3

      # No circuit exists
      iex> graph = Yog.Multi.Model.directed()
      ...>   |> Yog.Multi.Model.add_node(:a, "A")
      ...>   |> Yog.Multi.Model.add_node(:b, "B")
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :a, :b, 1), 0)
      ...> Yog.Multi.Eulerian.find_eulerian_circuit(graph)
      :error
  """
  @spec find_eulerian_circuit(Model.t()) :: {:ok, [Model.edge_id()]} | :error
  def find_eulerian_circuit(graph) do
    if has_eulerian_circuit?(graph) do
      case Model.all_nodes(graph) |> List.first() do
        nil -> :error
        start -> run_hierholzer(graph, start)
      end
    else
      :error
    end
  end

  @doc """
  Finds an Eulerian path using Hierholzer's algorithm adapted for multigraphs.

  Returns the path as a list of `EdgeId`s, or `:error` if no path exists.

  ## Important Note on Multigraphs

  In multigraphs, parallel edges between the same pair of nodes cannot be
  distinguished by node IDs alone. This function returns a list of edge IDs,
  which unambiguously identify which specific edge to traverse at each step.

  ## Time Complexity

  O(E)

  ## Examples

      iex> graph = Yog.Multi.Model.directed()
      ...>   |> Yog.Multi.Model.add_node(:a, "A")
      ...>   |> Yog.Multi.Model.add_node(:b, "B")
      ...>   |> Yog.Multi.Model.add_node(:c, "C")
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :a, :b, 1), 0)
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :b, :c, 2), 0)
      ...> case Yog.Multi.Eulerian.find_eulerian_path(graph) do
      ...>   {:ok, edge_ids} -> length(edge_ids)
      ...>   :error -> 0
      ...> end
      2

      # A circuit is also a valid path
      iex> graph = Yog.Multi.Model.directed()
      ...>   |> Yog.Multi.Model.add_node(:a, "A")
      ...>   |> Yog.Multi.Model.add_node(:b, "B")
      ...>   |> Yog.Multi.Model.add_node(:c, "C")
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :a, :b, 1), 0)
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :b, :c, 2), 0)
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :c, :a, 3), 0)
      ...> case Yog.Multi.Eulerian.find_eulerian_path(graph) do
      ...>   {:ok, edge_ids} -> length(edge_ids)
      ...>   :error -> 0
      ...> end
      3

      # No path exists
      iex> graph = Yog.Multi.Model.directed()
      ...>   |> Yog.Multi.Model.add_node(:a, "A")
      ...>   |> Yog.Multi.Model.add_node(:b, "B")
      ...>   |> Yog.Multi.Model.add_node(:c, "C")
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :a, :b, 1), 0)
      ...> graph = elem(Yog.Multi.Model.add_edge(graph, :a, :c, 2), 0)
      ...> Yog.Multi.Eulerian.find_eulerian_path(graph)
      :error
  """
  @spec find_eulerian_path(Model.t()) :: {:ok, [Model.edge_id()]} | :error
  def find_eulerian_path(graph) do
    if has_eulerian_path?(graph) do
      case find_path_start(graph) do
        nil -> :error
        start -> run_hierholzer(graph, start)
      end
    else
      :error
    end
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp all_even_degree?(graph) do
    graph.nodes
    |> Map.keys()
    |> Enum.all?(fn n -> rem(Model.out_degree(graph, n), 2) == 0 end)
  end

  defp all_balanced_degree?(graph) do
    graph.nodes
    |> Map.keys()
    |> Enum.all?(fn n ->
      Model.in_degree(graph, n) == Model.out_degree(graph, n)
    end)
  end

  defp connected?(graph) do
    nodes = Map.keys(graph.nodes)

    if nodes == [] do
      true
    else
      source = hd(nodes)
      visited = bfs_visited(graph, source)

      # All nodes should be reachable
      Enum.all?(nodes, fn n -> n in visited end)
    end
  end

  defp bfs_visited(graph, source) do
    do_bfs_visited(graph, [source], MapSet.new([source]))
  end

  defp do_bfs_visited(_graph, [], visited), do: MapSet.to_list(visited)

  defp do_bfs_visited(graph, [current | rest], visited) do
    successors =
      Model.successors(graph, current)
      |> Enum.map(fn {n, _, _} -> n end)

    predecessors =
      Model.predecessors(graph, current)
      |> Enum.map(fn {n, _, _} -> n end)

    new_neighbors =
      (successors ++ predecessors)
      |> Enum.uniq()
      |> Enum.reject(fn n -> MapSet.member?(visited, n) end)

    new_visited =
      Enum.reduce(new_neighbors, visited, fn n, acc -> MapSet.put(acc, n) end)

    do_bfs_visited(graph, rest ++ new_neighbors, new_visited)
  end

  defp find_path_start(graph) do
    if graph.kind == :undirected do
      find_undirected_path_start(graph)
    else
      find_directed_path_start(graph)
    end
  end

  defp find_undirected_path_start(graph) do
    nodes = Model.all_nodes(graph)

    case Enum.find(nodes, fn n ->
           rem(Model.out_degree(graph, n), 2) == 1
         end) do
      nil -> List.first(nodes)
      node -> node
    end
  end

  defp find_directed_path_start(graph) do
    nodes = Model.all_nodes(graph)

    case Enum.find(nodes, fn n ->
           Model.out_degree(graph, n) == Model.in_degree(graph, n) + 1
         end) do
      nil -> List.first(nodes)
      node -> node
    end
  end

  defp run_hierholzer(graph, start) do
    all_ids = Model.all_edge_ids(graph) |> MapSet.new()
    {_, path} = do_hierholzer(graph, start, all_ids, [])

    if path == [] do
      :error
    else
      # Hierholzer builds the path in post-order, so it's naturally reversed but we want the sequence
      # Wait, [eid | built] in post-order actually prepends, so it builds [e1, e2, ...] in forward order?
      # Let's check: in post-order, the LAST edge visited is the FIRST one returned.
      # So we need to reverse it to get the correct traversal order.
      {:ok, Enum.reverse(path)}
    end
  end

  defp do_hierholzer(graph, current, available, path) do
    case pick_edge(graph, current, available) do
      nil ->
        {available, path}

      {next_node, eid} ->
        {av2, p2} = do_hierholzer(graph, next_node, MapSet.delete(available, eid), path)

        do_hierholzer(graph, current, av2, [eid | p2])
    end
  end

  defp pick_edge(graph, current, available) do
    graph
    |> Model.successors(current)
    |> Enum.find(fn {_, eid, _} -> MapSet.member?(available, eid) end)
    |> case do
      nil -> nil
      {next, eid, _} -> {next, eid}
    end
  end
end
