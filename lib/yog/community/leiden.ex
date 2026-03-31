defmodule Yog.Community.Leiden do
  @moduledoc """
  Leiden algorithm for community detection.

  An improvement over the Louvain algorithm that guarantees well-connected
  communities. Adds a refinement step to ensure communities are properly
  connected internally.

  ## Algorithm

  The Leiden method works in three phases that repeat until convergence:

  1. **Local Optimization** (like Louvain): Nodes move to improve modularity
  2. **Refinement**: Partition communities into well-connected sub-communities
  3. **Aggregation**: Communities become super-nodes
  4. **Repeat** until convergence

  ## Key Differences from Louvain

  | Feature | Louvain | Leiden |
  |---------|---------|--------|
  | Speed | Faster | Slightly slower |
  | Well-connected communities | Not guaranteed | ✓ Guaranteed |
  | Hierarchical quality | Good | Better |
  | Disconnected communities | Possible | Prevented |

  ## When to Use

  - When **community quality** matters more than raw speed
  - When you need **meaningful multi-level structure**
  - When **disconnected communities** would be problematic
  - For **hierarchical analysis** requiring well-connected communities at each level

  ## Complexity

  - **Time**: Slightly slower than Louvain (refinement adds overhead)
  - **Space**: O(V + E) same as Louvain

  ## Example

      # Basic usage
      communities = Yog.Community.Leiden.detect(graph)
      IO.inspect(communities.num_communities)

      # With custom options
      options = [
        min_modularity_gain: 0.0001,
        max_iterations: 100,
        refinement_iterations: 5,
        seed: 42
      ]
      communities = Yog.Community.Leiden.detect_with_options(graph, options)

      # Hierarchical detection
      dendrogram = Yog.Community.Leiden.detect_hierarchical(graph)

  ## References

  - [Traag et al. 2019 - From Louvain to Leiden](https://doi.org/10.1038/s41598-019-41695-z)
  - [Wikipedia: Leiden Algorithm](https://en.wikipedia.org/wiki/Leiden_algorithm)

  """

  alias Yog.Community.{Dendrogram, Result}
  alias Yog.Model

  @typedoc "Options for the Leiden algorithm"
  @type leiden_options :: %{
          min_modularity_gain: float(),
          max_iterations: integer(),
          refinement_iterations: integer(),
          resolution: float(),
          seed: integer()
        }

  @doc """
  Returns default options for Leiden algorithm.

  ## Defaults

  - `min_modularity_gain`: 0.000001 - Stop when gain < threshold
  - `max_iterations`: 100 - Max iterations per phase
  - `refinement_iterations`: 5 - Refinement step iterations
  - `resolution`: 1.0 - Resolution parameter (gamma)
  - `seed`: 42 - Random seed for tie-breaking
  """
  @spec default_options() :: leiden_options()
  def default_options do
    %{
      min_modularity_gain: 0.000001,
      max_iterations: 100,
      refinement_iterations: 5,
      resolution: 1.0,
      seed: 42
    }
  end

  @doc """
  Detects communities using the Leiden algorithm with default options.

  ## Example

      communities = Yog.Community.Leiden.detect(graph)
      IO.inspect(communities.num_communities)
  """
  @spec detect(Yog.graph()) :: Result.t()
  def detect(graph) do
    detect_with_options(graph, [])
  end

  @doc """
  Detects communities using the Leiden algorithm with custom options.

  ## Options

  - `:min_modularity_gain` - Stop when gain < threshold (default: 0.000001)
  - `:max_iterations` - Max iterations per phase (default: 100)
  - `:refinement_iterations` - Refinement step iterations (default: 5)
  - `:resolution` - Resolution parameter (gamma) (default: 1.0)
  - `:seed` - Random seed for tie-breaking (default: 42)

  ## Example

      options = [min_modularity_gain: 0.0001, refinement_iterations: 10]
      communities = Yog.Community.Leiden.detect_with_options(graph, options)
  """
  @spec detect_with_options(Yog.graph(), keyword() | map()) :: Result.t()
  def detect_with_options(graph, opts) when is_list(opts) do
    detect_with_options(graph, Map.new(opts))
  end

  def detect_with_options(graph, opts) when is_map(opts) do
    options = Map.merge(default_options(), opts)
    nodes = Yog.all_nodes(graph)

    case length(nodes) do
      0 ->
        Result.new(%{})

      1 ->
        [node] = nodes
        Result.new(%{node => 0})

      _ ->
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

        {final_state, _improved} = do_leiden(graph, initial_state, 0, options)

        normalized_assignments = normalize_assignments(final_state.assignments)

        Result.new(normalized_assignments)
    end
  end

  @doc """
  Full hierarchical Leiden detection.

  Returns a dendrogram with all hierarchical levels.

  ## Example

      dendrogram = Yog.Community.Leiden.detect_hierarchical(graph)
      IO.inspect(length(dendrogram.levels))
  """
  @spec detect_hierarchical(Yog.graph()) :: Dendrogram.t()
  def detect_hierarchical(graph) do
    detect_hierarchical_with_options(graph, [])
  end

  @doc """
  Full hierarchical Leiden detection with custom options.

  ## Example

      options = [max_iterations: 50, seed: 123]
      dendrogram = Yog.Community.Leiden.detect_hierarchical_with_options(graph, options)
  """
  @spec detect_hierarchical_with_options(Yog.graph(), keyword() | map()) ::
          Dendrogram.t()
  def detect_hierarchical_with_options(graph, opts) when is_list(opts) do
    detect_hierarchical_with_options(graph, Map.new(opts))
  end

  def detect_hierarchical_with_options(graph, opts) when is_map(opts) do
    options = Map.merge(default_options(), opts)
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

    do_leiden_hierarchical(graph, initial_state, [], 0, options)
  end

  # =============================================================================
  # MAIN LEIDEN ALGORITHM
  # =============================================================================

  defp do_leiden(_graph, state, iteration, options) when iteration >= options.max_iterations do
    {state, false}
  end

  defp do_leiden(graph, state, iteration, options) do
    # Phase 1: Local optimization (same as Louvain)
    {improved_after_local, state_after_local} = phase1_local_optimize(graph, state, options)

    # Phase 1.5: Refinement (key difference from Louvain)
    state_after_refinement = phase15_refinement(graph, state_after_local)

    # Check for convergence
    new_num_comms = count_unique_communities(state_after_refinement.assignments)
    old_num_comms = count_unique_communities(state.assignments)

    converged = new_num_comms == old_num_comms and not improved_after_local

    if converged do
      {state_after_refinement, false}
    else
      # Phase 2: Aggregation
      aggregated = phase2_aggregate(graph, state_after_refinement.assignments)

      # Rebuild state for aggregated graph and continue
      new_state = rebuild_state(aggregated)
      {next_level_state, _} = do_leiden(aggregated, new_state, iteration + 1, options)

      # Compose: map current level nodes to next level communities
      composed_assignments =
        Map.new(state_after_refinement.assignments, fn {node, comm_id} ->
          {node, Map.get(next_level_state.assignments, comm_id, comm_id)}
        end)

      {%{state_after_refinement | assignments: composed_assignments}, true}
    end
  end

  defp do_leiden_hierarchical(_graph, _state, levels, iteration, options)
       when iteration >= options.max_iterations do
    Dendrogram.new(Enum.reverse(levels), [])
  end

  defp do_leiden_hierarchical(graph, state, levels, iteration, options) do
    # Phase 1: Local optimization
    {improved_after_local, state_after_local} = phase1_local_optimize(graph, state, options)

    # Phase 1.5: Refinement
    state_after_refinement = phase15_refinement(graph, state_after_local)

    # Save current level
    current_communities = Result.new(state_after_refinement.assignments)

    new_levels = [current_communities | levels]

    # Check for convergence
    new_num_comms = count_unique_communities(state_after_refinement.assignments)
    old_num_comms = count_unique_communities(state.assignments)

    converged =
      (new_num_comms == old_num_comms and not improved_after_local) or new_num_comms <= 1

    if converged do
      Dendrogram.new(Enum.reverse(new_levels), [])
    else
      # Phase 2: Aggregation
      aggregated = phase2_aggregate(graph, state_after_refinement.assignments)

      # Rebuild state and continue
      new_state = rebuild_state(aggregated)
      do_leiden_hierarchical(aggregated, new_state, new_levels, iteration + 1, options)
    end
  end

  # =============================================================================
  # PHASE 1: LOCAL OPTIMIZATION (same as Louvain)
  # =============================================================================

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
    # Shuffle nodes for randomization - use iteration-specific seed
    shuffled =
      Yog.Utils.fisher_yates(
        nodes,
        options.seed + map_size(state.assignments) + options.max_iterations
      )

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
        new_state = move_node(current_state, node, current_comm, best_comm, node_weight)
        {new_state, true}
      else
        {current_state, any_improved}
      end
    end)
  end

  # =============================================================================
  # PHASE 1.5: REFINEMENT (key difference from Louvain)
  # =============================================================================

  defp phase15_refinement(graph, state) do
    # Refinement: ensure communities are well-connected
    # For each community, check if it's connected and split if necessary
    # Uses memory-efficient adjacency map instead of subgraph extraction

    communities = get_community_nodes(state.assignments)

    Enum.reduce(communities, state, fn {_comm_id, nodes}, current_state ->
      if MapSet.size(nodes) <= 1 do
        current_state
      else
        # Build adjacency map for this community (memory efficient)
        adjacency = build_community_adjacency(graph, nodes)
        components = find_connected_components(adjacency, nodes)

        if length(components) > 1 do
          # Split into connected components
          split_community(current_state, components)
        else
          current_state
        end
      end
    end)
  end

  # Memory-efficient connectivity check without building subgraph
  # Returns adjacency map for nodes within the community
  defp build_community_adjacency(original, nodes) do
    node_list = MapSet.to_list(nodes)

    Enum.reduce(node_list, %{}, fn u, adj ->
      # Get neighbors that are also in the community
      neighbors_in_comm =
        original
        |> Model.successors(u)
        |> Enum.filter(fn {v, _weight} -> MapSet.member?(nodes, v) end)
        |> Enum.map(fn {v, _weight} -> v end)

      Map.put(adj, u, neighbors_in_comm)
    end)
  end

  defp find_connected_components(adjacency, nodes) do
    node_list = MapSet.to_list(nodes)
    visited = MapSet.new()

    {_final_visited, components} =
      Enum.reduce(node_list, {visited, []}, fn node, {visited_acc, comps} ->
        if MapSet.member?(visited_acc, node) do
          {visited_acc, comps}
        else
          component = bfs_component_adj(adjacency, node, visited_acc)
          new_visited = MapSet.union(visited_acc, component)
          {new_visited, [component | comps]}
        end
      end)

    components
  end

  # BFS using adjacency map instead of graph struct (memory efficient)
  defp bfs_component_adj(adjacency, start, initial_visited) do
    # Skip if start node already visited
    if MapSet.member?(initial_visited, start) do
      MapSet.new()
    else
      do_bfs_component_adj(
        adjacency,
        [start],
        MapSet.put(initial_visited, start),
        MapSet.new([start])
      )
    end
  end

  defp do_bfs_component_adj(_adjacency, [], _blocked, component), do: component

  defp do_bfs_component_adj(adjacency, [current | queue], blocked, component) do
    neighbors = Map.get(adjacency, current, [])

    {new_queue, new_blocked, new_component} =
      Enum.reduce(neighbors, {queue, blocked, component}, fn neighbor, {q, b, c} ->
        if MapSet.member?(b, neighbor) do
          # Already visited or blocked, skip
          {q, b, c}
        else
          # credo:disable-for-this-file Credo.Check.Refactor.AppendSingleItem
          {q ++ [neighbor], MapSet.put(b, neighbor), MapSet.put(c, neighbor)}
        end
      end)

    do_bfs_component_adj(adjacency, new_queue, new_blocked, new_component)
  end

  defp split_community(state, components) when length(components) <= 1 do
    state
  end

  defp split_community(state, components) do
    # Get max community ID
    max_comm_id =
      state.assignments
      |> Map.values()
      |> Enum.max()

    # Assign new IDs to all components except first
    {new_assignments, _next_id} =
      components
      |> Enum.with_index()
      |> Enum.reduce({state.assignments, max_comm_id + 1}, fn {component, idx},
                                                              {assigns, next_id} ->
        if idx == 0 do
          # First component keeps current assignments
          {assigns, next_id}
        else
          # Other components get new IDs
          new_assigns =
            Enum.reduce(component, assigns, fn node, a ->
              Map.put(a, node, next_id)
            end)

          {new_assigns, next_id + 1}
        end
      end)

    # Recalculate community totals
    new_totals = calculate_community_totals(new_assignments, state.node_weights)

    %{
      state
      | assignments: new_assignments,
        community_totals: new_totals
    }
  end

  # =============================================================================
  # HELPER FUNCTIONS (shared with Louvain)
  # =============================================================================

  defp get_neighbor_communities(graph, state, node) do
    neighbors = Model.successors(graph, node)

    Enum.reduce(neighbors, MapSet.new(), fn {neighbor_id, _}, acc ->
      comm = Map.get(state.assignments, neighbor_id, neighbor_id)
      MapSet.put(acc, comm)
    end)
    |> MapSet.to_list()
  end

  defp calculate_modularity_gain(
         _graph,
         _node,
         current_comm,
         target_comm,
         _node_weight,
         _state,
         _resolution
       )
       when current_comm == target_comm do
    0.0
  end

  defp calculate_modularity_gain(
         graph,
         node,
         current_comm,
         target_comm,
         node_weight,
         state,
         gamma
       ) do
    ki = node_weight
    m = state.total_weight

    if m == 0.0 do
      0.0
    else
      two_m_sq = 2.0 * m * m

      # Gain of adding to target community
      ki_in_target = calculate_ki_in(graph, state, node, target_comm)
      sigma_tot_target = Map.get(state.community_totals, target_comm, 0.0)
      delta_q_add = ki_in_target / m - gamma * (sigma_tot_target * ki / two_m_sq)

      # Gain of leaving current community
      ki_in_current = calculate_ki_in(graph, state, node, current_comm)
      sigma_tot_current = Map.get(state.community_totals, current_comm, 0.0)
      sigma_tot_c_minus_i = sigma_tot_current - ki
      delta_q_remove = ki_in_current / m - gamma * (sigma_tot_c_minus_i * ki / two_m_sq)

      delta_q_add - delta_q_remove
    end
  end

  defp calculate_ki_in(graph, state, node, target_comm) do
    successors = Model.successors(graph, node)

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
          Model.successors(graph, node)
          |> Enum.reduce(0, fn {_, weight}, sum -> sum + weight end)

        acc + weight_sum
      end)

    # Only divide by 2 for undirected graphs (each edge counted twice)
    case graph.kind do
      :undirected -> total / 2.0
      :directed -> total
    end
  end

  defp calculate_node_weights(graph) do
    nodes = Yog.all_nodes(graph)

    Map.new(nodes, fn node ->
      weight_sum =
        Model.successors(graph, node)
        |> Enum.reduce(0, fn {_, weight}, sum -> sum + weight end)

      {node, weight_sum / 1.0}
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

    # Step 1: Accumulate weights in a Map %{{u_comm, v_comm} => weight}
    # This avoids O(degree) search for each edge - uses O(1) Map operations instead
    edge_weights =
      Enum.reduce(nodes, %{}, fn u, acc ->
        comm_u = Map.get(assignments, u, u)

        Enum.reduce(Model.successors(original_graph, u), acc, fn {v, weight}, inner_acc ->
          comm_v = Map.get(assignments, v, v)

          # For undirected graphs, use stable key {min, max} to avoid double-counting
          # Self-loops naturally handled (comm_u == comm_v)
          edge_key =
            if original_graph.kind == :undirected and comm_u > comm_v do
              {comm_v, comm_u}
            else
              {comm_u, comm_v}
            end

          Map.update(inner_acc, edge_key, weight, &(&1 + weight))
        end)
      end)

    # Step 2: Bulk add all accumulated edges to the new graph
    Enum.reduce(edge_weights, new_graph, fn {{u, v}, weight}, g ->
      Model.add_edge_ensure(g, u, v, weight, default: nil)
    end)
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
end
