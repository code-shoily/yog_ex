defmodule Yog.Connectivity.Reachability do
  @moduledoc """
  Algorithms for analyzing node reachability in directed and undirected graphs.

  ## Memory Warning

  The `counts/2` function builds complete reachability sets which requires O(V²)
  memory in the worst case (dense graphs). For large graphs (>10,000 nodes),
  consider using `counts_estimate/2` which uses HyperLogLog for approximate
  counting with O(V) memory.

  ## Reachability Visualization

  Reachability analysis identifies the set of all nodes that can be visited starting from a specific source node (descendants) or that can visit a specific node (ancestors).

  <div class="graphviz">
  digraph G {
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];

    Source [label="Source", color="#6366f1", penwidth=2.5, style=bold];
    
    // Reachable set
    Source -> A [color="#6366f1"];
    A -> B [color="#6366f1"];
    Source -> C [color="#6366f1"];
    
    // Unreachable from Source
    X -> Y;
    X -> Source [style=dashed, label="ancestor"];
    
    subgraph cluster_reachable {
      label="Reachability Set (Descendants)"; color="#6366f1"; style=rounded;
      A; B; C;
    }
  }
  </div>

      iex> alias Yog.Connectivity.Reachability
      iex> graph = Yog.from_edges(:directed, [
      ...>   {"Source", "A", 1}, {"A", "B", 1}, {"Source", "C", 1},
      ...>   {"X", "Y", 1}, {"X", "Source", 1}
      ...> ])
      iex> Reachability.counts(graph, :descendants)["Source"]
      3
  """

  import Bitwise, only: [band: 2, bsr: 2, bsl: 2]

  @typedoc "Direction for reachability counting"
  @type direction :: :ancestors | :descendants

  # HyperLogLog parameters for cardinality estimation
  # Using 2^10 registers = 1024, standard error ~3.25%
  @hll_precision 10
  @hll_num_registers 1024
  @hll_alpha 0.7213 / (1 + 1.079 / 1024)

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

  ## Memory Warning

  This function builds complete reachability sets requiring O(V²) memory.
  For large graphs, use `counts_estimate/2` instead.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> counts = Yog.Connectivity.Reachability.counts(graph, :descendants)
      iex> counts[1]
      2
      iex> counts[3]
      0
  """
  @spec counts(Yog.graph(), direction()) :: %{Yog.node_id() => integer()}
  def counts(graph, direction) do
    case Yog.Traversal.topological_sort(graph) do
      {:ok, sorted} ->
        solve_acyclic_counts(graph, sorted, direction)

      {:error, :contains_cycle} ->
        solve_cyclic_counts(graph, direction)
    end
  end

  # ============================================================
  # Internal Algorithms - Exact Counts
  # ============================================================

  defp solve_acyclic_counts(graph, sorted, direction) do
    nodes_to_process =
      case direction do
        :descendants -> Enum.reverse(sorted)
        :ancestors -> sorted
      end

    get_related = build_get_related_fn(graph, direction)

    reachability_sets =
      List.foldl(nodes_to_process, %{}, fn node, acc ->
        related = get_related.(node)
        related_set = MapSet.new(related)

        all_reachable =
          List.foldl(related, related_set, fn neighbor, set_acc ->
            neighbor_set = Map.get(acc, neighbor, MapSet.new())
            MapSet.union(set_acc, neighbor_set)
          end)

        Map.put(acc, node, all_reachable)
      end)

    Map.new(reachability_sets, fn {node, set} -> {node, MapSet.size(set)} end)
  end

  defp solve_cyclic_counts(graph, direction) do
    sccs = Yog.Connectivity.strongly_connected_components(graph)
    node_to_scc = build_node_to_scc_map(sccs)

    condensation = build_condensation_graph(graph, sccs, node_to_scc)
    {:ok, sorted_sccs} = Yog.Traversal.topological_sort(condensation)

    scc_direction = if direction == :descendants, do: :descendants, else: :ancestors

    scc_reachability_sets =
      solve_acyclic_reachability_sets(condensation, sorted_sccs, scc_direction)

    cond_nodes = condensation.nodes

    Map.new(Map.keys(graph.nodes), fn node_id ->
      scc_id = Map.fetch!(node_to_scc, node_id)
      reachable_scc_ids = Map.get(scc_reachability_sets, scc_id, MapSet.new())

      node_count =
        List.foldl(MapSet.to_list(reachable_scc_ids), 0, fn id, acc ->
          scc_data = Map.fetch!(cond_nodes, id)
          acc + scc_data.size
        end)

      my_scc_data = Map.fetch!(cond_nodes, scc_id)
      my_scc_size = my_scc_data.size
      {node_id, node_count + (my_scc_size - 1)}
    end)
  end

  @doc """
  Estimates the number of ancestors or descendants using HyperLogLog.

  This is a memory-efficient alternative to `counts/2` that uses approximately
  O(V) memory instead of O(V²). The trade-off is approximate results with
  ~3.25% standard error.

  ## When to Use

  - Large graphs (>10,000 nodes) where memory is constrained
  - When approximate counts are acceptable
  - Streaming or online analysis scenarios

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> counts = Yog.Connectivity.Reachability.counts_estimate(graph, :descendants)
      iex> counts[1]  # Approximate count (likely 1 or 2, may vary slightly)
      _
  """
  @spec counts_estimate(Yog.graph(), direction()) :: %{Yog.node_id() => integer()}
  def counts_estimate(graph, direction) do
    case Yog.Traversal.topological_sort(graph) do
      {:ok, sorted} ->
        solve_acyclic_hll(graph, sorted, direction)

      {:error, :contains_cycle} ->
        solve_cyclic_hll(graph, direction)
    end
  end

  # HyperLogLog-based counting for acyclic graphs
  defp solve_acyclic_hll(graph, sorted, direction) do
    nodes_to_process =
      case direction do
        :descendants -> Enum.reverse(sorted)
        :ancestors -> sorted
      end

    get_related = build_get_related_fn(graph, direction)

    hll_registers =
      List.foldl(nodes_to_process, %{}, fn node, acc ->
        related = get_related.(node)
        base_hll = List.foldl(related, init_hll(), &hll_add(&2, &1))

        merged =
          List.foldl(related, base_hll, fn neighbor, hll_acc ->
            neighbor_hll = Map.get(acc, neighbor, init_hll())
            hll_union(hll_acc, neighbor_hll)
          end)

        Map.put(acc, node, merged)
      end)

    Map.new(hll_registers, fn {node, hll} -> {node, hll_count(hll)} end)
  end

  # HyperLogLog-based counting for cyclic graphs (via condensation)
  defp solve_cyclic_hll(graph, direction) do
    sccs = Yog.Connectivity.strongly_connected_components(graph)
    node_to_scc = build_node_to_scc_map(sccs)
    condensation = build_condensation_graph(graph, sccs, node_to_scc)
    {:ok, sorted_sccs} = Yog.Traversal.topological_sort(condensation)

    scc_base_hlls =
      List.foldl(Enum.with_index(sccs), %{}, fn {nodes, scc_id}, acc ->
        hll = List.foldl(nodes, init_hll(), &hll_add(&2, &1))
        Map.put(acc, scc_id, hll)
      end)

    sccs_to_process =
      case direction do
        :descendants -> Enum.reverse(sorted_sccs)
        :ancestors -> sorted_sccs
      end

    cond_edges = condensation.out_edges
    cond_in_edges = condensation.in_edges

    get_scc_related =
      case direction do
        :descendants ->
          fn scc_id ->
            case Map.fetch(cond_edges, scc_id) do
              {:ok, nbrs} -> Map.keys(nbrs)
              :error -> []
            end
          end

        :ancestors ->
          fn scc_id ->
            case Map.fetch(cond_in_edges, scc_id) do
              {:ok, nbrs} -> Map.keys(nbrs)
              :error -> []
            end
          end
      end

    scc_final_hlls =
      List.foldl(sccs_to_process, %{}, fn scc_id, acc ->
        my_base = Map.fetch!(scc_base_hlls, scc_id)

        children = get_scc_related.(scc_id)

        merged_children =
          List.foldl(children, my_base, fn child_id, hll_acc ->
            child_hll = Map.get(acc, child_id, init_hll())
            hll_union(hll_acc, child_hll)
          end)

        Map.put(acc, scc_id, merged_children)
      end)

    all_nodes = Map.keys(graph.nodes)

    Map.new(all_nodes, fn node_id ->
      scc_id = Map.fetch!(node_to_scc, node_id)
      total_count = hll_count(Map.get(scc_final_hlls, scc_id, init_hll()))
      {node_id, max(0, total_count - 1)}
    end)
  end

  # ============================================================
  # HyperLogLog Implementation (Binary-based for efficiency)
  # ============================================================

  defp init_hll, do: :binary.copy(<<0>>, @hll_num_registers)

  defp hll_add(hll_bin, value) when is_binary(hll_bin) do
    # Retain full 32-bit spread
    hash = :erlang.phash2(value)
    index = band(hash, @hll_num_registers - 1)
    remaining = bsr(hash, @hll_precision)
    zeros = count_leading_zeros(remaining, 32 - @hll_precision)
    val = zeros + 1
    current = :binary.at(hll_bin, index)

    if val > current do
      prefix = binary_part(hll_bin, 0, index)
      suffix = binary_part(hll_bin, index + 1, byte_size(hll_bin) - index - 1)
      <<prefix::binary, val::8, suffix::binary>>
    else
      hll_bin
    end
  end

  defp hll_union(bin1, bin2) when is_binary(bin1) and is_binary(bin2) do
    do_hll_union(bin1, bin2, <<>>)
  end

  defp do_hll_union(<<b1::8, r1::binary>>, <<b2::8, r2::binary>>, acc) do
    do_hll_union(r1, r2, <<acc::binary, max(b1, b2)::8>>)
  end

  defp do_hll_union(<<>>, <<>>, acc), do: acc

  defp hll_count(<<>>), do: 0

  defp hll_count(hll_bin) when is_binary(hll_bin) do
    sum_inverse =
      Enum.reduce(0..(@hll_num_registers - 1), 0.0, fn i, acc ->
        max_zeros = :binary.at(hll_bin, i)
        acc + :math.pow(2.0, -max_zeros)
      end)

    raw_estimate = @hll_alpha * @hll_num_registers * @hll_num_registers / sum_inverse

    if raw_estimate <= 2.5 * @hll_num_registers do
      v = count_empty_registers(hll_bin)

      if v != 0 do
        @hll_num_registers * :math.log(@hll_num_registers / v)
      else
        raw_estimate
      end
    else
      raw_estimate
    end
    |> round()
    |> max(0)
  end

  defp count_empty_registers(hll_bin) do
    do_count_empty(hll_bin, 0)
  end

  defp do_count_empty(<<>>, count), do: count
  defp do_count_empty(<<0::8, rest::binary>>, count), do: do_count_empty(rest, count + 1)
  defp do_count_empty(<<_::8, rest::binary>>, count), do: do_count_empty(rest, count)

  defp count_leading_zeros(0, bits), do: bits

  defp count_leading_zeros(value, bits) when value > 0 do
    do_clz(value, bits, 0)
  end

  defp do_clz(value, bits, count) when value > 0 do
    if band(value, bsl(1, bits - 1)) == 0 do
      do_clz(value, bits - 1, count + 1)
    else
      count
    end
  end

  # ============================================================
  # Helpers
  # ============================================================

  defp build_get_related_fn(graph, :descendants) do
    out = graph.out_edges

    fn node ->
      case Map.fetch(out, node) do
        {:ok, nbrs} -> Map.keys(nbrs)
        :error -> []
      end
    end
  end

  defp build_get_related_fn(graph, :ancestors) do
    in_edges = graph.in_edges

    fn node ->
      case Map.fetch(in_edges, node) do
        {:ok, nbrs} -> Map.keys(nbrs)
        :error -> []
      end
    end
  end

  defp build_node_to_scc_map(sccs) do
    List.foldl(Enum.with_index(sccs), %{}, fn {nodes, id}, acc ->
      List.foldl(nodes, acc, fn node, inner_acc ->
        Map.put(inner_acc, node, id)
      end)
    end)
  end

  defp build_condensation_graph(graph, sccs, node_to_scc) do
    init = Yog.directed()
    out_edges = graph.out_edges

    graph_with_nodes =
      List.foldl(Enum.with_index(sccs), init, fn {nodes, id}, g ->
        Yog.add_node(g, id, %{size: length(nodes)})
      end)

    all_nodes = Map.keys(graph.nodes)

    List.foldl(all_nodes, graph_with_nodes, fn src, g ->
      src_scc = Map.fetch!(node_to_scc, src)

      successors =
        case Map.fetch(out_edges, src) do
          {:ok, nbrs} -> Map.keys(nbrs)
          :error -> []
        end

      List.foldl(successors, g, fn dst, acc_g ->
        dst_scc = Map.fetch!(node_to_scc, dst)

        if src_scc != dst_scc do
          case Yog.add_edge(acc_g, src_scc, dst_scc, 1) do
            {:ok, new_g} -> new_g
            {:error, _} -> acc_g
          end
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

    get_related = build_get_related_fn(dag, direction)

    List.foldl(nodes_to_process, %{}, fn node, acc ->
      related = get_related.(node)
      related_set = MapSet.new(related)

      all_reachable =
        List.foldl(related, related_set, fn neighbor, set_acc ->
          neighbor_set = Map.get(acc, neighbor, MapSet.new())
          MapSet.union(set_acc, neighbor_set)
        end)

      Map.put(acc, node, all_reachable)
    end)
  end
end
