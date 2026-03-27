defmodule Yog.Connectivity.Reachability do
  @moduledoc """
  Algorithms for analyzing node reachability in directed and undirected graphs.
  """

  alias Yog.Model

  @typedoc "Direction for reachability counting"
  @type direction :: :ancestors | :descendants

  @doc """
  Counts the number of ancestors or descendants for every node in the graph.

  For each node, returns how many other nodes are reachable from it
  (`:descendants`) or can reach it (`:ancestors`).

  In a directed graph, this counts nodes in the reachability set.
  In an undirected graph, this is equivalent to the size of the connected component
  minus the node itself.

  ## Algorithm

  - If the graph is acyclic, it uses an optimized dynamic programming approach
    on the topological order (O(V * E)).
  - If the graph contains cycles, it simplifies the graph into its condensation
    (the DAG of strongly connected components) to maintain efficiency.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> counts = Yog.Connectivity.Reachability.counts(graph, :descendants)
      iex> counts[1]
      2
      iex> counts[3]
      0
  """
  @spec counts(Yog.graph(), direction()) :: %{Yog.node_id() => integer()}
  def counts(graph, direction) do
    # Check if the graph is a DAG to use the faster DP approach directly
    case Yog.Traversal.topological_sort(graph) do
      {:ok, sorted} ->
        solve_acyclic_counts(graph, sorted, direction)

      {:error, :contains_cycle} ->
        solve_cyclic_counts(graph, direction)
    end
  end

  # ============================================================
  # Internal Algorithms
  # ============================================================

  defp solve_acyclic_counts(graph, sorted, direction) do
    # Determine processing order (reverse for descendants, forward for ancestors)
    nodes_to_process =
      case direction do
        :descendants -> Enum.reverse(sorted)
        :ancestors -> sorted
      end

    get_related = build_related_fn(graph, direction)

    # DP: Map of node -> Set of all reachable nodes
    reachability_sets =
      Enum.reduce(nodes_to_process, %{}, fn node, acc ->
        related = get_related.(node)
        related_set = MapSet.new(related)

        all_reachable =
          Enum.reduce(related, related_set, fn neighbor, set_acc ->
            neighbor_set = Map.get(acc, neighbor, MapSet.new())
            MapSet.union(set_acc, neighbor_set)
          end)

        Map.put(acc, node, all_reachable)
      end)

    Map.new(reachability_sets, fn {node, set} -> {node, MapSet.size(set)} end)
  end

  defp solve_cyclic_counts(graph, direction) do
    # 1. Component analysis
    sccs = Yog.Connectivity.strongly_connected_components(graph)
    node_to_scc = build_node_to_scc_map(sccs)

    # 2. Build condensation graph
    # (Each node in the condensation graph represents an SCC)
    # We store the size of the SCC to count nodes correctly later
    condensation = build_condensation_graph(graph, sccs, node_to_scc)

    # 3. Solve on the condensation DAG
    # Since it's a DAG, topological sort is guaranteed to succeed
    {:ok, sorted_sccs} = Yog.Traversal.topological_sort(condensation)

    scc_direction = if direction == :descendants, do: :descendants, else: :ancestors

    scc_reachability_sets =
      solve_acyclic_reachability_sets(condensation, sorted_sccs, scc_direction)

    # 4. Map results back to original nodes
    Map.new(Yog.all_nodes(graph), fn node_id ->
      scc_id = Map.get(node_to_scc, node_id)
      # Total reachable = (nodes in all reachable SCCs) + (other nodes in my own SCC)
      # Note: set contains SCC IDs including successors
      reachable_scc_ids = Map.get(scc_reachability_sets, scc_id, MapSet.new())

      node_count =
        Enum.reduce(reachable_scc_ids, 0, fn id, acc ->
          acc + Map.get(condensation.nodes, id).size
        end)

      # Plus nodes in my own SCC minus myself
      my_scc_size = Map.get(condensation.nodes, scc_id).size
      {node_id, node_count + (my_scc_size - 1)}
    end)
  end

  # ============================================================
  # Helpers
  # ============================================================

  defp build_related_fn(graph, :descendants), do: fn node -> Model.successor_ids(graph, node) end
  defp build_related_fn(graph, :ancestors), do: fn node -> Model.predecessor_ids(graph, node) end

  defp build_node_to_scc_map(sccs) do
    Enum.with_index(sccs)
    |> Enum.reduce(%{}, fn {nodes, id}, acc ->
      Enum.reduce(nodes, acc, fn node, inner_acc -> Map.put(inner_acc, node, id) end)
    end)
  end

  defp build_condensation_graph(graph, sccs, node_to_scc) do
    init = Yog.directed()

    # Add SCC nodes with their size as metadata
    graph_with_nodes =
      Enum.with_index(sccs)
      |> Enum.reduce(init, fn {nodes, id}, g ->
        Model.add_node(g, id, %{size: length(nodes)})
      end)

    # Add edges between SCCs
    Enum.reduce(Yog.all_nodes(graph), graph_with_nodes, fn src, g ->
      src_scc = Map.get(node_to_scc, src)

      Enum.reduce(Model.successor_ids(graph, src), g, fn dst, acc_g ->
        dst_scc = Map.get(node_to_scc, dst)

        if src_scc != dst_scc do
          # Add edge between components if not already present
          Model.add_edge_ensure(acc_g, src_scc, dst_scc, 1, nil)
        else
          acc_g
        end
      end)
    end)
  end

  defp solve_acyclic_reachability_sets(dag, sorted, direction) do
    nodes_to_process =
      case direction do
        :descendants -> Enum.reverse(sorted)
        :ancestors -> sorted
      end

    get_related = build_related_fn(dag, direction)

    Enum.reduce(nodes_to_process, %{}, fn node, acc ->
      related = get_related.(node)
      related_set = MapSet.new(related)

      all_reachable =
        Enum.reduce(related, related_set, fn neighbor, set_acc ->
          neighbor_set = Map.get(acc, neighbor, MapSet.new())
          MapSet.union(set_acc, neighbor_set)
        end)

      Map.put(acc, node, all_reachable)
    end)
  end
end
