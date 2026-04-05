defmodule Yog.Community.Louvain do
  @moduledoc """
  Louvain method for community detection.

  A fast, hierarchical algorithm that optimizes modularity. One of the most
  widely used community detection algorithms due to its excellent balance
  of speed and quality.

  ## Algorithm

  The Louvain method works in two phases that repeat until convergence:

  1. **Local Optimization**: Each node moves to the neighbor community that
     maximizes modularity gain
  2. **Aggregation**: Communities become super-nodes in a new aggregated graph
  3. **Repeat** until no improvement in modularity

  ## When to Use

  | Use Case | Recommendation |
  |----------|----------------|
  | Large graphs (millions of nodes) | ✓ Excellent |
  | Hierarchical structure needed | ✓ Yes |
  | General purpose | ✓ Works well on most networks |
  | Quality over speed | Consider Leiden |

  ## Complexity

  - **Time**: O(E × iterations), typically O(E log V) in practice
  - **Space**: O(V + E)

  ## Example

      # Basic usage
      communities = Yog.Community.Louvain.detect(graph)
      communities.num_communities  # => number of communities found

      # With custom options
      options = [
        min_modularity_gain: 0.0001,
        max_iterations: 100,
        seed: 42
      ]
      communities = Yog.Community.Louvain.detect_with_options(graph, options)

  ## References

  - [Blondel et al. 2008 - Fast unfolding of communities](https://arxiv.org/abs/0803.0476)
  - [Wikipedia: Louvain Method](https://en.wikipedia.org/wiki/Louvain_method)
  """

  alias Yog.Community.{Dendrogram, Metrics, Result}

  @typedoc "Options for the Louvain algorithm"
  @type louvain_options :: %{
          min_modularity_gain: float(),
          max_iterations: integer(),
          resolution: float(),
          seed: integer()
        }

  @typedoc "Statistics from the Louvain algorithm run"
  @type louvain_stats :: %{
          num_phases: integer(),
          final_modularity: float(),
          iteration_modularity: [float()]
        }

  @doc """
  Returns default options for Louvain algorithm.
  """
  @spec default_options() :: louvain_options()
  def default_options do
    %{
      min_modularity_gain: 0.000001,
      max_iterations: 100,
      resolution: 1.0,
      seed: 42
    }
  end

  @doc """
  Detects communities using the Louvain algorithm with default options.
  """
  @spec detect(Yog.graph()) :: Result.t()
  def detect(graph) do
    detect_with_options(graph, [])
  end

  @doc """
  Detects communities using the Louvain algorithm with custom options.

  ## Options

    * `:min_modularity_gain` - Stop when gain < threshold (default: 0.000001)
    * `:max_iterations` - Maximum iterations per phase (default: 100)
    * `:resolution` - Resolution parameter (gamma) (default: 1.0)
    * `:seed` - Random seed for tie-breaking (default: 42)
  """
  @spec detect_with_options(Yog.graph(), keyword()) :: Result.t()
  def detect_with_options(graph, opts) do
    {communities, _stats} = detect_with_stats(graph, opts)
    communities
  end

  @doc """
  Detects communities and returns statistics for debugging/analysis.
  """
  @spec detect_with_stats(Yog.graph(), keyword()) :: {Result.t(), louvain_stats()}
  def detect_with_stats(graph, opts) do
    options = Map.merge(default_options(), Map.new(opts))

    nodes = Map.keys(graph.nodes)
    total_weight = calculate_total_weight(graph)

    # Initialize: each node in its own community
    initial_assignments = Map.new(Enum.with_index(nodes), fn {node, i} -> {node, i} end)

    node_weights = calculate_node_weights(graph)

    initial_state = %{
      assignments: initial_assignments,
      node_weights: node_weights,
      community_totals: calculate_community_totals(initial_assignments, node_weights),
      total_weight: total_weight
    }

    do_louvain(graph, initial_state, [], 0, options)
  end

  @doc """
  Full hierarchical Louvain detection.
  """
  @spec detect_hierarchical(Yog.graph()) :: Dendrogram.t()
  def detect_hierarchical(graph) do
    detect_hierarchical_with_options(graph, [])
  end

  @doc """
  Full hierarchical Louvain detection with custom options.
  """
  @spec detect_hierarchical_with_options(Yog.graph(), keyword()) :: Dendrogram.t()
  def detect_hierarchical_with_options(graph, opts) do
    options = Map.merge(default_options(), Map.new(opts))

    nodes = Map.keys(graph.nodes)
    total_weight = calculate_total_weight(graph)

    initial_assignments = Map.new(Enum.with_index(nodes), fn {node, i} -> {node, i} end)
    node_weights = calculate_node_weights(graph)

    initial_state = %{
      assignments: initial_assignments,
      node_weights: node_weights,
      community_totals: calculate_community_totals(initial_assignments, node_weights),
      total_weight: total_weight
    }

    do_louvain_hierarchical(graph, initial_state, [], 0, options)
  end

  # ============================================================
  # Private Functions
  # ============================================================

  defp do_louvain(graph, state, mod_history, phase, options) do
    # Run local optimization until convergence
    {improved, new_state} = phase1_local_optimize(graph, state, options)

    # Calculate modularity
    normalized_assignments = normalize_assignments(new_state.assignments)
    communities = Result.new(normalized_assignments)

    # Note: Metrics.modularity/2 is O(E). For large graphs, this could be optimized
    # to O(C) by calculating directly from state.community_totals
    q = Metrics.modularity(graph, Result.to_map(communities))
    new_history = [q | mod_history]

    if not improved or phase >= options.max_iterations do
      # Converged - return final result
      stats = %{
        num_phases: phase + 1,
        final_modularity: q,
        iteration_modularity: Enum.reverse(new_history)
      }

      {communities, stats}
    else
      # Continue with another phase
      do_louvain(graph, new_state, new_history, phase + 1, options)
    end
  end

  # Single recursive function for hierarchical Louvain (consolidates duplicate logic)
  defp do_louvain_hierarchical(graph, state, levels, phase, options) do
    # Phase 1: Local optimization
    {improved, new_state} = phase1_local_optimize(graph, state, options)

    # Save current level
    normalized_assignments = normalize_assignments(new_state.assignments)
    current_communities = Result.new(normalized_assignments)
    new_levels = [current_communities | levels]

    # Check for convergence
    num_comms = count_unique_communities(new_state.assignments)

    if not improved or phase >= options.max_iterations or num_comms <= 1 do
      # Converged
      Dendrogram.new(Enum.reverse(new_levels), [])
    else
      # Phase 2: Aggregation
      aggregated = phase2_aggregate(graph, new_state.assignments)
      aggregated_state = rebuild_state(aggregated)

      # Recurse with aggregated graph (same function, no duplication)
      do_louvain_hierarchical(aggregated, aggregated_state, new_levels, phase + 1, options)
    end
  end

  defp phase1_local_optimize(graph, state, options) do
    nodes = Map.keys(state.assignments)
    do_phase1_iterations(graph, state, nodes, false, 0, options)
  end

  defp do_phase1_iterations(_graph, state, _nodes, improved, iteration, options)
       when iteration >= options.max_iterations do
    {improved, state}
  end

  defp do_phase1_iterations(graph, state, nodes, improved, iteration, options) do
    {new_state, local_improved} = do_phase1_pass(graph, state, nodes, options)

    if local_improved do
      do_phase1_iterations(graph, new_state, nodes, true, iteration + 1, options)
    else
      {improved, new_state}
    end
  end

  defp do_phase1_pass(graph, state, nodes, options) do
    # Shuffle nodes for randomization - O(V) Fisher-Yates
    shuffled = Yog.Utils.fisher_yates(nodes, options.seed + map_size(state.assignments))

    List.foldl(shuffled, {state, false}, fn node, {current_state, any_improved} ->
      current_comm = Map.get(current_state.assignments, node, node)
      node_weight = Map.get(current_state.node_weights, node, 0.0)

      # Pre-calculate neighbor weights per community in O(deg(node))
      # This avoids O(k^2) scan when evaluating each neighbor community
      neighbor_weights = calculate_neighbor_weights_by_comm(graph, current_state, node)
      neighbor_comms = Map.keys(neighbor_weights)

      # Find best community using pre-calculated weights
      {best_comm, best_gain} =
        Enum.reduce(neighbor_comms, {current_comm, 0.0}, fn neighbor_comm, {best_c, best_g} ->
          ki_in_comm = Map.get(neighbor_weights, neighbor_comm, 0.0)

          gain =
            calculate_modularity_gain_fast(
              node,
              current_comm,
              neighbor_comm,
              node_weight,
              ki_in_comm,
              current_state,
              options.resolution
            )

          if gain > best_g do
            {neighbor_comm, gain}
          else
            {best_c, best_g}
          end
        end)

      if best_gain > options.min_modularity_gain and best_comm != current_comm do
        # Move node to best community
        new_state = move_node(current_state, node, current_comm, best_comm, node_weight)
        {new_state, true}
      else
        {current_state, any_improved}
      end
    end)
  end

  # Pre-calculate total edge weight from node to each neighbor community
  # Returns %{community_id => total_weight} in O(degree) time
  defp calculate_neighbor_weights_by_comm(%Yog.Graph{out_edges: out_edges}, state, node) do
    neighbors =
      case Map.fetch(out_edges, node) do
        {:ok, edges} -> Map.to_list(edges)
        :error -> []
      end

    List.foldl(neighbors, %{}, fn {neighbor_id, weight}, acc ->
      comm = Map.get(state.assignments, neighbor_id, neighbor_id)
      Map.update(acc, comm, weight, &(&1 + weight))
    end)
  end

  # Fast modularity gain using pre-calculated ki_in_community
  defp calculate_modularity_gain_fast(
         _node,
         current_comm,
         target_comm,
         _node_weight,
         _ki_in_target,
         _state,
         _gamma
       )
       when current_comm == target_comm do
    0.0
  end

  defp calculate_modularity_gain_fast(
         _node,
         current_comm,
         target_comm,
         node_weight,
         ki_in_target,
         state,
         gamma
       ) do
    ki = node_weight
    m = state.total_weight

    if m == 0.0 do
      0.0
    else
      two_m_sq = 2.0 * m * m

      # Gain of adding to target community (use pre-calculated ki_in_target)
      sigma_tot_target = Map.get(state.community_totals, target_comm, 0.0)

      # Gain of leaving current community side-effects
      sigma_tot_current = Map.get(state.community_totals, current_comm, 0.0)

      # Delta Q = ki_in_target/m - gamma * sigma_tot_target * ki / (2m^2)
      #         - gamma * (sigma_tot_current - ki) * ki / (2m^2)
      ki_in_target / m - gamma * sigma_tot_target * ki / two_m_sq -
        gamma * (sigma_tot_current - ki) * ki / two_m_sq
    end
  end

  defp move_node(state, node, from_comm, to_comm, node_weight) do
    new_assignments = Map.put(state.assignments, node, to_comm)

    new_totals =
      state.community_totals
      |> Map.update(from_comm, 0.0, fn v -> v - node_weight end)
      |> Map.update(to_comm, node_weight, fn v -> v + node_weight end)

    %{
      state
      | assignments: new_assignments,
        community_totals: new_totals
    }
  end

  defp calculate_total_weight(%Yog.Graph{out_edges: out_edges, kind: kind, nodes: nodes}) do
    node_list = Map.keys(nodes)

    total =
      List.foldl(node_list, 0.0, fn node, acc ->
        weight_sum =
          case Map.fetch(out_edges, node) do
            {:ok, edges} ->
              List.foldl(Map.to_list(edges), 0, fn {_, weight}, sum -> sum + weight end)

            :error ->
              0
          end

        acc + weight_sum
      end)

    # Only divide by 2 for undirected graphs (each edge counted twice)
    case kind do
      :undirected -> total / 2.0
      :directed -> total
    end
  end

  defp calculate_node_weights(%Yog.Graph{out_edges: out_edges, nodes: nodes}) do
    node_list = Map.keys(nodes)

    Map.new(node_list, fn node ->
      weight_sum =
        case Map.fetch(out_edges, node) do
          {:ok, edges} ->
            List.foldl(Map.to_list(edges), 0, fn {_, weight}, sum -> sum + weight end)

          :error ->
            0
        end

      {node, weight_sum * 1.0}
    end)
  end

  defp calculate_community_totals(assignments, node_weights) do
    List.foldl(Map.to_list(assignments), %{}, fn {node, comm}, acc ->
      weight = Map.get(node_weights, node, 0.0)
      Map.update(acc, comm, weight, fn v -> v + weight end)
    end)
  end

  defp count_unique_communities(assignments) do
    assignments
    |> Map.values()
    |> Enum.uniq()
    |> length()
  end

  defp normalize_assignments(assignments) do
    # Get all unique community IDs and sort them
    unique_communities =
      assignments
      |> Map.values()
      |> Enum.uniq()
      |> Enum.sort()

    # Create mapping from old ID to new contiguous ID
    id_mapping =
      unique_communities
      |> Enum.with_index()
      |> Map.new(fn {old_id, new_id} -> {old_id, new_id} end)

    # Remap all assignments
    Map.new(assignments, fn {node, old_community_id} ->
      {node, Map.get(id_mapping, old_community_id, 0)}
    end)
  end

  defp phase2_aggregate(graph, assignments) do
    communities = get_community_nodes(assignments)

    # Start with empty undirected graph
    new_graph = Yog.undirected()

    # Add super-nodes
    new_graph_with_nodes =
      Enum.reduce(communities, new_graph, fn {comm_id, _nodes}, g ->
        Yog.add_node(g, comm_id, nil)
      end)

    # Aggregate edges
    aggregate_edges(graph, new_graph_with_nodes, assignments)
  end

  defp get_community_nodes(assignments) do
    List.foldl(Map.to_list(assignments), %{}, fn {node, comm}, acc ->
      current_set = Map.get(acc, comm, MapSet.new())
      Map.put(acc, comm, MapSet.put(current_set, node))
    end)
  end

  defp aggregate_edges(
         %Yog.Graph{out_edges: out_edges, kind: kind} = original_graph,
         new_graph,
         assignments
       ) do
    nodes = Map.keys(original_graph.nodes)

    # Step 1: Accumulate weights in a Map %{{u_comm, v_comm} => weight}
    # This avoids per-edge graph operations - uses O(1) Map operations instead
    edge_weights =
      List.foldl(nodes, %{}, fn u, acc ->
        comm_u = Map.get(assignments, u, u)

        successors =
          case Map.fetch(out_edges, u) do
            {:ok, edges} -> Map.to_list(edges)
            :error -> []
          end

        List.foldl(successors, acc, fn {v, weight}, inner_acc ->
          comm_v = Map.get(assignments, v, v)

          # For undirected graphs, use stable key {min, max} to avoid double-counting
          # Self-loops naturally handled (comm_u == comm_v)
          edge_key =
            if kind == :undirected and comm_u > comm_v do
              {comm_v, comm_u}
            else
              {comm_u, comm_v}
            end

          Map.update(inner_acc, edge_key, weight, &(&1 + weight))
        end)
      end)

    # Step 2: Bulk add all accumulated edges to the new graph
    List.foldl(Map.to_list(edge_weights), new_graph, fn {{u, v}, weight}, g ->
      {:ok, new_g} = Yog.add_edge(g, u, v, weight)
      new_g
    end)
  end

  defp rebuild_state(aggregated_graph) do
    nodes = Map.keys(aggregated_graph.nodes)
    total_weight = calculate_total_weight(aggregated_graph)

    new_assignments = Map.new(Enum.with_index(nodes), fn {node, i} -> {node, i} end)
    node_weights = calculate_node_weights(aggregated_graph)

    %{
      assignments: new_assignments,
      node_weights: node_weights,
      community_totals: calculate_community_totals(new_assignments, node_weights),
      total_weight: total_weight
    }
  end
end
