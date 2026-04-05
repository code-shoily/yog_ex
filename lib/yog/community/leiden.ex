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
    order = Yog.Model.order(graph)

    case order do
      0 ->
        Result.new(%{})

      1 ->
        Result.new(%{(Yog.Model.all_nodes(graph) |> hd()) => 0})

      _ ->
        total_weight = calculate_total_weight(graph)

        initial_assignments =
          :maps.fold(
            fn node, _, {acc, i} ->
              {Map.put(acc, node, i), i + 1}
            end,
            {%{}, 0},
            graph.nodes
          )
          |> elem(0)

        node_weights = calculate_node_weights(graph)

        inv_m = if total_weight > 0.0, do: 1.0 / total_weight, else: 0.0

        inv_two_m_sq =
          if total_weight > 0.0, do: 1.0 / (2.0 * total_weight * total_weight), else: 0.0

        initial_state = %{
          assignments: initial_assignments,
          node_weights: node_weights,
          community_totals: calculate_community_totals(initial_assignments, node_weights),
          total_weight: total_weight,
          inv_m: inv_m,
          inv_two_m_sq: inv_two_m_sq
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
    total_weight = calculate_total_weight(graph)

    initial_assignments =
      :maps.fold(
        fn node, _, {acc, i} ->
          {Map.put(acc, node, i), i + 1}
        end,
        {%{}, 0},
        graph.nodes
      )
      |> elem(0)

    node_weights = calculate_node_weights(graph)

    inv_m = if total_weight > 0.0, do: 1.0 / total_weight, else: 0.0
    inv_two_m_sq = if total_weight > 0.0, do: 1.0 / (2.0 * total_weight * total_weight), else: 0.0

    initial_state = %{
      assignments: initial_assignments,
      node_weights: node_weights,
      community_totals: calculate_community_totals(initial_assignments, node_weights),
      total_weight: total_weight,
      inv_m: inv_m,
      inv_two_m_sq: inv_two_m_sq
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
    {improved_after_local, state_after_local} = phase1_local_optimize(graph, state, options)

    state_after_refinement = phase15_refinement(graph, state_after_local)
    new_num_comms = count_unique_communities(state_after_refinement.assignments)
    old_num_comms = count_unique_communities(state.assignments)

    converged = new_num_comms == old_num_comms and not improved_after_local

    if converged do
      {state_after_refinement, false}
    else
      aggregated = phase2_aggregate(graph, state_after_refinement.assignments)

      new_state = rebuild_state(aggregated)
      {next_level_state, _} = do_leiden(aggregated, new_state, iteration + 1, options)

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
    {improved_after_local, state_after_local} = phase1_local_optimize(graph, state, options)

    state_after_refinement = phase15_refinement(graph, state_after_local)
    current_communities = Result.new(state_after_refinement.assignments)
    new_levels = [current_communities | levels]

    new_num_comms = count_unique_communities(state_after_refinement.assignments)
    old_num_comms = count_unique_communities(state.assignments)

    converged =
      (new_num_comms == old_num_comms and not improved_after_local) or new_num_comms <= 1

    if converged do
      Dendrogram.new(Enum.reverse(new_levels), [])
    else
      aggregated = phase2_aggregate(graph, state_after_refinement.assignments)
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
    shuffled =
      Yog.Utils.fisher_yates(
        nodes,
        options.seed + map_size(state.assignments) + options.max_iterations
      )

    Enum.reduce(shuffled, {state, false}, fn node, {current_state, any_improved} ->
      current_comm = Map.get(current_state.assignments, node, node)
      node_weight = Map.get(current_state.node_weights, node, 0.0)

      neighbor_weights = calculate_neighbor_weights_by_comm(graph, current_state, node)

      {best_comm, best_gain} =
        :maps.fold(
          fn neighbor_comm, ki_in_comm, {best_c, best_g} ->
            gain =
              calculate_modularity_gain_fast(
                node_weight,
                ki_in_comm,
                current_comm,
                neighbor_comm,
                current_state,
                options.resolution
              )

            if gain > best_g do
              {neighbor_comm, gain}
            else
              {best_c, best_g}
            end
          end,
          {current_comm, 0.0},
          neighbor_weights
        )

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

    :maps.fold(
      fn _comm_id, nodes, current_state ->
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
      end,
      state,
      communities
    )
  end

  # Memory-efficient connectivity check without building subgraph
  # Returns adjacency map for nodes within the community
  defp build_community_adjacency(%Yog.Graph{out_edges: out_edges}, nodes) do
    # Optimization: Iterate directly on node set and avoid intermediate list creation
    Enum.reduce(nodes, %{}, fn u, adj ->
      neighbors_in_comm =
        case Map.fetch(out_edges, u) do
          {:ok, edges} ->
            :maps.fold(
              fn v, _, acc ->
                if MapSet.member?(nodes, v), do: [v | acc], else: acc
              end,
              [],
              edges
            )

          :error ->
            []
        end

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

  defp bfs_component_adj(adjacency, start, initial_visited) do
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
    max_comm_id =
      :maps.fold(
        fn _, comm, acc -> if comm > acc, do: comm, else: acc end,
        0,
        state.assignments
      )

    {new_assignments, _next_id} =
      components
      |> Enum.with_index()
      |> Enum.reduce({state.assignments, max_comm_id + 1}, fn {component, idx},
                                                              {assigns, next_id} ->
        if idx == 0 do
          {assigns, next_id}
        else
          new_assigns =
            Enum.reduce(component, assigns, fn node, a ->
              Map.put(a, node, next_id)
            end)

          {new_assigns, next_id + 1}
        end
      end)

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

  # Pre-calculate total edge weight from node to each neighbor community
  # Returns %{community_id => total_weight} in O(degree) time
  defp calculate_neighbor_weights_by_comm(%Yog.Graph{out_edges: out_edges}, state, node) do
    case Map.fetch(out_edges, node) do
      {:ok, edges} ->
        # Use Enum.reduce on map to avoid list allocation
        :maps.fold(
          fn neighbor_id, weight, acc ->
            comm = Map.get(state.assignments, neighbor_id, neighbor_id)
            Map.update(acc, comm, weight, &(&1 + weight))
          end,
          %{},
          edges
        )

      :error ->
        %{}
    end
  end

  defp calculate_modularity_gain_fast(
         _node_weight,
         _ki_in_target,
         current_comm,
         target_comm,
         _state,
         _gamma
       )
       when current_comm == target_comm do
    0.0
  end

  defp calculate_modularity_gain_fast(
         ki,
         ki_in_target,
         current_comm,
         target_comm,
         state,
         gamma
       ) do
    sigma_tot_target = Map.get(state.community_totals, target_comm, 0.0)
    sigma_tot_current = Map.get(state.community_totals, current_comm, 0.0)

    # Optimization: Use pre-calculated inv_m and inv_two_m_sq
    ki_in_target * state.inv_m -
      gamma * sigma_tot_target * ki * state.inv_two_m_sq -
      gamma * (sigma_tot_current - ki) * ki * state.inv_two_m_sq
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

  defp calculate_total_weight(%Yog.Graph{out_edges: out_edges, kind: kind}) do
    # Optimization: Enum.reduce on map directly
    total =
      :maps.fold(
        fn _node, inner, acc ->
          weight_sum =
            :maps.fold(
              fn _dst, weight, sum -> sum + weight end,
              0.0,
              inner
            )

          acc + weight_sum
        end,
        0.0,
        out_edges
      )

    case kind do
      :undirected -> total / 2.0
      :directed -> total
    end
  end

  defp calculate_node_weights(%Yog.Graph{out_edges: out_edges}) do
    :maps.fold(
      fn node, inner, acc ->
        weight_sum =
          :maps.fold(
            fn _dst, weight, sum -> sum + weight end,
            0,
            inner
          )

        Map.put(acc, node, weight_sum / 1.0)
      end,
      %{},
      out_edges
    )
  end

  defp calculate_community_totals(assignments, node_weights) do
    :maps.fold(
      fn node, comm, acc ->
        weight = Map.get(node_weights, node, 0.0)
        Map.update(acc, comm, weight, fn v -> v + weight end)
      end,
      %{},
      assignments
    )
  end

  defp count_unique_communities(assignments) do
    :maps.fold(
      fn _, comm, acc -> MapSet.put(acc, comm) end,
      MapSet.new(),
      assignments
    )
    |> MapSet.size()
  end

  defp normalize_assignments(assignments) do
    unique_communities =
      :maps.fold(
        fn _, comm, acc -> MapSet.put(acc, comm) end,
        MapSet.new(),
        assignments
      )
      |> MapSet.to_list()
      |> Enum.sort()

    id_mapping =
      unique_communities
      |> Enum.with_index()
      |> Map.new(fn {old_id, new_id} -> {old_id, new_id} end)

    Map.new(assignments, fn {node, old_community_id} ->
      {node, Map.get(id_mapping, old_community_id, 0)}
    end)
  end

  defp phase2_aggregate(graph, assignments) do
    communities = get_community_nodes(assignments)

    new_graph = Yog.undirected()

    new_graph_with_nodes =
      :maps.fold(
        fn comm_id, _, g ->
          Yog.add_node(g, comm_id, nil)
        end,
        new_graph,
        communities
      )

    aggregate_edges(graph, new_graph_with_nodes, assignments)
  end

  defp get_community_nodes(assignments) do
    :maps.fold(
      fn node, comm, acc ->
        current_set = Map.get(acc, comm, MapSet.new())
        Map.put(acc, comm, MapSet.put(current_set, node))
      end,
      %{},
      assignments
    )
  end

  defp aggregate_edges(
         %Yog.Graph{out_edges: out_edges, kind: kind},
         new_graph,
         assignments
       ) do
    edge_weights =
      :maps.fold(
        fn u, inner, acc ->
          comm_u = Map.get(assignments, u, u)

          :maps.fold(
            fn v, weight, inner_acc ->
              comm_v = Map.get(assignments, v, v)

              edge_key =
                if kind == :undirected and comm_u > comm_v do
                  {comm_v, comm_u}
                else
                  {comm_u, comm_v}
                end

              Map.update(inner_acc, edge_key, weight, &(&1 + weight))
            end,
            acc,
            inner
          )
        end,
        %{},
        out_edges
      )

    :maps.fold(
      fn {u, v}, weight, g ->
        {:ok, new_g} = Yog.add_edge(g, u, v, weight)
        new_g
      end,
      new_graph,
      edge_weights
    )
  end

  defp rebuild_state(aggregated_graph) do
    total_weight = calculate_total_weight(aggregated_graph)

    new_assignments =
      :maps.fold(
        fn node, _, {acc, i} ->
          {Map.put(acc, node, i), i + 1}
        end,
        {%{}, 0},
        aggregated_graph.nodes
      )
      |> elem(0)

    node_weights = calculate_node_weights(aggregated_graph)

    inv_m = if total_weight > 0.0, do: 1.0 / total_weight, else: 0.0
    inv_two_m_sq = if total_weight > 0.0, do: 1.0 / (2.0 * total_weight * total_weight), else: 0.0

    %{
      assignments: new_assignments,
      node_weights: node_weights,
      community_totals: calculate_community_totals(new_assignments, node_weights),
      total_weight: total_weight,
      inv_m: inv_m,
      inv_two_m_sq: inv_two_m_sq
    }
  end
end
