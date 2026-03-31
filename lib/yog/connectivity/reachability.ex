defmodule Yog.Connectivity.Reachability do
  @moduledoc """
  Algorithms for analyzing node reachability in directed and undirected graphs.

  ## Memory Warning

  The `counts/2` function builds complete reachability sets which requires O(V²)
  memory in the worst case (dense graphs). For large graphs (>10,000 nodes),
  consider using `counts_estimate/2` which uses HyperLogLog for approximate
  counting with O(V) memory.
  """

  alias Yog.Model
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
    # Check if the graph is a DAG to use the faster DP approach directly
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
  # Each node's HLL contains actual node IDs (not SCC IDs)
  defp solve_acyclic_hll(graph, sorted, direction) do
    nodes_to_process =
      case direction do
        :descendants -> Enum.reverse(sorted)
        :ancestors -> sorted
      end

    get_related = build_related_fn(graph, direction)

    # DP: Map of node -> HLL registers
    hll_registers =
      Enum.reduce(nodes_to_process, %{}, fn node, acc ->
        related = get_related.(node)

        # Start with HLL containing related nodes
        base_hll = Enum.reduce(related, init_hll(), &hll_add(&2, &1))

        # Merge HLL registers from all related nodes
        merged =
          Enum.reduce(related, base_hll, fn neighbor, hll_acc ->
            neighbor_hll = Map.get(acc, neighbor, init_hll())
            hll_union(hll_acc, neighbor_hll)
          end)

        Map.put(acc, node, merged)
      end)

    Map.new(hll_registers, fn {node, hll} -> {node, hll_count(hll)} end)
  end

  # HyperLogLog-based counting for cyclic graphs (via condensation)
  # Critical: HLLs contain actual node IDs, not SCC IDs
  defp solve_cyclic_hll(graph, direction) do
    sccs = Yog.Connectivity.strongly_connected_components(graph)
    node_to_scc = build_node_to_scc_map(sccs)
    condensation = build_condensation_graph(graph, sccs, node_to_scc)
    {:ok, sorted_sccs} = Yog.Traversal.topological_sort(condensation)

    # Step 1: Create base HLL for each SCC containing its actual node IDs
    scc_base_hlls =
      Enum.with_index(sccs)
      |> Enum.reduce(%{}, fn {nodes, scc_id}, acc ->
        hll = Enum.reduce(nodes, init_hll(), &hll_add(&2, &1))
        Map.put(acc, scc_id, hll)
      end)

    # Step 2: Propagate HLLs up the condensation DAG
    # Process in reverse topological order for descendants, or forward for ancestors
    sccs_to_process =
      case direction do
        :descendants -> Enum.reverse(sorted_sccs)
        :ancestors -> sorted_sccs
      end

    get_scc_related = build_related_fn(condensation, direction)

    scc_final_hlls =
      Enum.reduce(sccs_to_process, %{}, fn scc_id, acc ->
        # Start with this SCC's own nodes
        my_base = Map.get(scc_base_hlls, scc_id)

        # Union with the final HLLs of all reachable child SCCs
        children = get_scc_related.(scc_id)

        merged_children =
          Enum.reduce(children, my_base, fn child_id, hll_acc ->
            child_hll = Map.get(acc, child_id, init_hll())
            hll_union(hll_acc, child_hll)
          end)

        Map.put(acc, scc_id, merged_children)
      end)

    # Step 3: Map results back to original nodes
    # Subtract 1 to exclude the node itself
    Map.new(Yog.all_nodes(graph), fn node_id ->
      scc_id = Map.get(node_to_scc, node_id)
      total_count = hll_count(Map.get(scc_final_hlls, scc_id, init_hll()))
      # Subtract 1 for the node itself
      {node_id, max(0, total_count - 1)}
    end)
  end

  # ============================================================
  # HyperLogLog Implementation (Binary-based for efficiency)
  # ============================================================

  # Use a binary for HLL registers - 1024 bytes, much faster than maps
  # Each byte stores the max run of leading zeros for that register
  defp init_hll, do: :binary.copy(<<0>>, @hll_num_registers)

  defp hll_add(hll_bin, value) when is_binary(hll_bin) do
    # Use native hash (faster than custom hash for this use case)
    hash = :erlang.phash2(value, 2_147_483_647)

    # First @hll_precision bits determine the register
    index = band(hash, @hll_num_registers - 1)

    # Remaining bits for leading zero count
    remaining = bsr(hash, @hll_precision)
    zeros = count_leading_zeros(remaining, 32 - @hll_precision)
    val = zeros + 1

    # Update binary only if new value is higher (O(1) access)
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
    # Harmonic mean of register values
    sum_inverse =
      Enum.reduce(0..(@hll_num_registers - 1), 0.0, fn i, acc ->
        max_zeros = :binary.at(hll_bin, i)
        acc + :math.pow(2.0, -max_zeros)
      end)

    raw_estimate = @hll_alpha * @hll_num_registers * @hll_num_registers / sum_inverse

    # Small range correction
    if raw_estimate <= 2.5 * @hll_num_registers do
      # Count non-empty registers by counting zeros in binary
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

  # Count leading zeros using bit-shifting
  defp count_leading_zeros(0, bits), do: bits

  defp count_leading_zeros(value, _bits) when value > 0 do
    do_clz(value, 32, 0)
  end

  defp do_clz(0, _bits, count), do: count

  defp do_clz(value, bits, count) when value > 0 do
    # Check top bit
    if band(value, bsl(1, bits - 1)) == 0 do
      do_clz(value, bits - 1, count + 1)
    else
      count
    end
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
