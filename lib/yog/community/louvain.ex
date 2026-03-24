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
    options = %{
      min_modularity_gain: Keyword.get(opts, :min_modularity_gain, 0.000001),
      max_iterations: Keyword.get(opts, :max_iterations, 100),
      seed: Keyword.get(opts, :seed, 42)
    }

    nodes = Yog.all_nodes(graph)
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
    options = %{
      min_modularity_gain: Keyword.get(opts, :min_modularity_gain, 0.000001),
      max_iterations: Keyword.get(opts, :max_iterations, 100),
      seed: Keyword.get(opts, :seed, 42)
    }

    nodes = Yog.all_nodes(graph)
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

      # Rebuild state and continue
      aggregated_state = rebuild_state(aggregated)

      do_louvain_hierarchical_recursive(
        aggregated,
        aggregated_state,
        new_levels,
        phase + 1,
        options
      )
    end
  end

  defp do_louvain_hierarchical_recursive(graph, state, levels, phase, options) do
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

      # Rebuild state and continue
      aggregated_state = rebuild_state(aggregated)

      do_louvain_hierarchical_recursive(
        aggregated,
        aggregated_state,
        new_levels,
        phase + 1,
        options
      )
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
    # Shuffle nodes for randomization
    shuffled = shuffle(nodes, options.seed + map_size(state.assignments))

    Enum.reduce(shuffled, {state, false}, fn node, {current_state, any_improved} ->
      current_comm = Map.get(current_state.assignments, node, node)
      node_weight = Map.get(current_state.node_weights, node, 0.0)

      # Get neighbor communities
      neighbor_comms = get_neighbor_communities(graph, current_state, node)

      # Find best community
      {best_comm, best_gain} =
        Enum.reduce(neighbor_comms, {current_comm, 0.0}, fn neighbor_comm, {best_c, best_g} ->
          gain =
            calculate_modularity_gain(
              graph,
              node,
              current_comm,
              neighbor_comm,
              node_weight,
              current_state
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

  defp get_neighbor_communities(graph, state, node) do
    neighbors = Yog.Model.successors(graph, node)

    Enum.reduce(neighbors, MapSet.new(), fn {neighbor_id, _}, acc ->
      comm = Map.get(state.assignments, neighbor_id, neighbor_id)
      MapSet.put(acc, comm)
    end)
    |> MapSet.to_list()
  end

  defp calculate_modularity_gain(_graph, _node, current_comm, target_comm, _node_weight, _state)
       when current_comm == target_comm do
    0.0
  end

  defp calculate_modularity_gain(graph, node, current_comm, target_comm, node_weight, state) do
    ki = node_weight
    m = state.total_weight

    if m == 0.0 do
      0.0
    else
      two_m_sq = 2.0 * m * m

      # Gain of adding to target community
      ki_in_target = calculate_ki_in(graph, state, node, target_comm)
      sigma_tot_target = Map.get(state.community_totals, target_comm, 0.0)
      delta_q_add = ki_in_target / m - sigma_tot_target * ki / two_m_sq

      # Gain of leaving current community
      ki_in_current = calculate_ki_in(graph, state, node, current_comm)
      sigma_tot_current = Map.get(state.community_totals, current_comm, 0.0)
      sigma_tot_c_minus_i = sigma_tot_current - ki
      delta_q_remove = ki_in_current / m - sigma_tot_c_minus_i * ki / two_m_sq

      delta_q_add - delta_q_remove
    end
  end

  defp calculate_ki_in(graph, state, node, target_comm) do
    successors = Yog.Model.successors(graph, node)

    Enum.reduce(successors, 0.0, fn {neighbor, weight}, acc ->
      neighbor_comm = Map.get(state.assignments, neighbor, neighbor)

      if neighbor_comm == target_comm do
        acc + weight
      else
        acc
      end
    end)
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

  defp calculate_total_weight(graph) do
    nodes = Yog.all_nodes(graph)

    total =
      Enum.reduce(nodes, 0.0, fn node, acc ->
        weight_sum =
          Yog.Model.successors(graph, node)
          |> Enum.reduce(0, fn {_, weight}, sum -> sum + weight end)

        acc + weight_sum
      end)

    # Divide by 2 for undirected graphs (each edge counted twice)
    total / 2.0
  end

  defp calculate_node_weights(graph) do
    nodes = Yog.all_nodes(graph)

    Map.new(nodes, fn node ->
      weight_sum =
        Yog.Model.successors(graph, node)
        |> Enum.reduce(0, fn {_, weight}, sum -> sum + weight end)

      {node, weight_sum * 1.0}
    end)
  end

  defp calculate_community_totals(assignments, node_weights) do
    Enum.reduce(assignments, %{}, fn {node, comm}, acc ->
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
    Enum.reduce(assignments, %{}, fn {node, comm}, acc ->
      current_set = Map.get(acc, comm, MapSet.new())
      Map.put(acc, comm, MapSet.put(current_set, node))
    end)
  end

  defp aggregate_edges(original_graph, new_graph, assignments) do
    nodes = Yog.all_nodes(original_graph)

    Enum.reduce(nodes, new_graph, fn u, g ->
      comm_u = Map.get(assignments, u, u)
      successors = Yog.Model.successors(original_graph, u)

      Enum.reduce(successors, g, fn {v, weight}, g2 ->
        comm_v = Map.get(assignments, v, v)

        # For undirected graphs, only process each edge once (comm_u <= comm_v)
        # For self-loops (comm_u == comm_v), always add
        if comm_u == comm_v or comm_u < comm_v do
          add_or_update_edge(g2, comm_u, comm_v, weight)
        else
          g2
        end
      end)
    end)
  end

  defp add_or_update_edge(graph, u, v, weight) do
    # Use combine function to handle both new and existing edges in one operation
    case Yog.Model.add_edge_with_combine(graph, u, v, weight, &Kernel.+/2) do
      {:ok, new_graph} -> new_graph
      {:error, _} -> graph
    end
  end

  defp rebuild_state(aggregated_graph) do
    nodes = Yog.all_nodes(aggregated_graph)
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

  defp shuffle(items, seed) do
    # Deterministic shuffle using LCG parameters (same as glibc)
    a = 1_103_515_245
    c = 12_345
    m = 2_147_483_648

    items
    |> Enum.with_index()
    |> Enum.map(fn {item, i} ->
      rand = rem(a * (seed + i) + c, m)
      {rand, item}
    end)
    |> Enum.sort_by(fn {rand, _} -> rand end)
    |> Enum.map(fn {_, item} -> item end)
  end
end
