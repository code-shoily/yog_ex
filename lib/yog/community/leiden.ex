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

  > #### Note on well-separated inputs
  >
  > On graphs where Louvain already produces connected communities
  > (e.g. well-separated SBMs or dense clusters), Leiden's refinement
  > step has no effect and both algorithms return equivalent partitions.
  > The refinement guarantee matters most near the resolution limit,
  > where Louvain may merge weakly-connected components into a single
  > disconnected community.

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
    nodes = Yog.all_nodes(graph)

    case length(nodes) do
      0 ->
        Result.new(%{})

      1 ->
        [node] = nodes
        Result.new(%{node => 0})

      _ ->
        total_weight = calculate_total_weight(graph)

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

  Returns a dendrogram with all hierarchical levels. Each level stores
  assignments over the contracted graph at that aggregation depth — see
  `Yog.Community.Dendrogram` for the per-level semantics.

  To obtain the final partition over original-graph nodes, use
  `Yog.Community.Dendrogram.flatten_to_original/1`:

      dend = Yog.Community.Leiden.detect_hierarchical(graph)
      final = Yog.Community.Dendrogram.flatten_to_original(dend)
      # final.assignments is now keyed by original node ids

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

  Returns a dendrogram with all hierarchical levels. Each level stores
  assignments over the contracted graph at that aggregation depth — see
  `Yog.Community.Dendrogram` for the per-level semantics.

  To obtain the final partition over original-graph nodes, use
  `Yog.Community.Dendrogram.flatten_to_original/1`:

      dend = Yog.Community.Leiden.detect_hierarchical_with_options(graph, options)
      final = Yog.Community.Dendrogram.flatten_to_original(dend)
      # final.assignments is now keyed by original node ids

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
    {improved_after_local, state_after_local} = phase1_local_optimize(graph, state, options)

    state_after_refinement = phase15_refinement(graph, state_after_local, options)
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

    state_after_refinement = phase15_refinement(graph, state_after_local, options)
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

      neighbor_comms = get_neighbor_communities(graph, current_state, node)

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
  defp phase15_refinement(graph, state, options) do
    nodes = Map.keys(state.assignments)
    refined_assignments = Map.new(nodes, fn node -> {node, node} end)
    refined_comm_totals = Map.new(state.node_weights)
    refined_comm_sizes = Map.new(nodes, fn node -> {node, 1} end)

    coarse_communities = get_community_nodes(state.assignments)

    {final_assignments, _final_totals, _final_sizes} =
      Enum.reduce(
        coarse_communities,
        {refined_assignments, refined_comm_totals, refined_comm_sizes},
        fn {_comm_id, nodes_in_c}, acc_state ->
          refine_coarse_community(graph, nodes_in_c, state, acc_state, options)
        end
      )

    final_totals = calculate_community_totals(final_assignments, state.node_weights)

    %{
      state
      | assignments: final_assignments,
        community_totals: final_totals
    }
  end

  defp refine_coarse_community(
         graph,
         nodes_in_c,
         state,
         {refined_assignments, refined_totals, refined_sizes},
         options
       ) do
    if MapSet.size(nodes_in_c) <= 1 do
      {refined_assignments, refined_totals, refined_sizes}
    else
      m = state.total_weight
      node_list = MapSet.to_list(nodes_in_c)

      well_connected_nodes =
        Enum.filter(node_list, fn u ->
          k_u = Map.get(state.node_weights, u, 0.0)
          w_u_c = calculate_w_u_c(graph, u, nodes_in_c)

          comm_u = Map.get(state.assignments, u)
          sigma_tot_c = Map.get(state.community_totals, comm_u, 0.0)

          if m == 0.0 do
            false
          else
            w_u_c >= options.resolution * k_u * (sigma_tot_c - k_u) / (2.0 * m)
          end
        end)

      shuffled_nodes = Yog.Utils.fisher_yates(well_connected_nodes, options.seed)

      Enum.reduce(
        shuffled_nodes,
        {refined_assignments, refined_totals, refined_sizes},
        fn u, {r_assigns, r_tots, r_sizes} ->
          comm_u = Map.get(r_assigns, u)

          if Map.get(r_sizes, comm_u, 0) == 1 do
            k_u = Map.get(state.node_weights, u, 0.0)
            neighbor_weights = calculate_neighbor_weights_in_c(graph, u, nodes_in_c, r_assigns)

            candidates =
              Enum.filter(neighbor_weights, fn {c_ref, w_u_cref} ->
                c_ref != comm_u and
                  (
                    k_cref = Map.get(r_tots, c_ref, 0.0)
                    m > 0.0 and w_u_cref >= options.resolution * k_u * k_cref / (2.0 * m)
                  )
              end)

            theta = 1.0

            weights =
              Enum.map(candidates, fn {c_ref, w_u_cref} ->
                k_cref = Map.get(r_tots, c_ref, 0.0)
                gain = w_u_cref - options.resolution * k_u * k_cref / (2.0 * m)
                weight = :math.exp(gain / theta)
                {c_ref, weight}
              end)

            total_weight = 1.0 + Enum.sum(Enum.map(weights, &elem(&1, 1)))

            # Seed the random number generator deterministically for this node
            seed_val = options.seed + :erlang.phash2(u)
            _ = :rand.seed(:exsss, {seed_val, 0, 0})
            r = :rand.uniform() * total_weight

            target_comm = select_target(weights, r, 1.0)

            if target_comm != nil do
              new_assigns = Map.put(r_assigns, u, target_comm)

              new_tots =
                r_tots
                |> Map.update!(comm_u, &(&1 - k_u))
                |> Map.update!(target_comm, &(&1 + k_u))

              new_sizes =
                r_sizes
                |> Map.put(comm_u, 0)
                |> Map.update!(target_comm, &(&1 + 1))

              {new_assigns, new_tots, new_sizes}
            else
              {r_assigns, r_tots, r_sizes}
            end
          else
            {r_assigns, r_tots, r_sizes}
          end
        end
      )
    end
  end

  defp calculate_w_u_c(%Yog.Graph{out_edges: out_edges}, u, nodes_in_c) do
    case Map.fetch(out_edges, u) do
      {:ok, edges} ->
        List.foldl(Map.to_list(edges), 0.0, fn {v, w}, acc ->
          if MapSet.member?(nodes_in_c, v) do
            acc + w
          else
            acc
          end
        end)

      :error ->
        0.0
    end
  end

  defp calculate_neighbor_weights_in_c(
         %Yog.Graph{out_edges: out_edges},
         u,
         nodes_in_c,
         refined_assignments
       ) do
    case Map.fetch(out_edges, u) do
      {:ok, edges} ->
        List.foldl(Map.to_list(edges), %{}, fn {v, w}, acc ->
          if MapSet.member?(nodes_in_c, v) do
            comm_v = Map.get(refined_assignments, v)
            Map.update(acc, comm_v, w, &(&1 + w))
          else
            acc
          end
        end)

      :error ->
        %{}
    end
  end

  defp select_target([], _r, _acc_weight), do: nil

  defp select_target([{c_ref, w} | rest], r, acc_weight) do
    new_acc = acc_weight + w

    if r <= new_acc do
      c_ref
    else
      select_target(rest, r, new_acc)
    end
  end

  # =============================================================================
  # HELPER FUNCTIONS (shared with Louvain)
  # =============================================================================

  defp get_neighbor_communities(%Yog.Graph{out_edges: out_edges}, state, node) do
    neighbors =
      case Map.fetch(out_edges, node) do
        {:ok, edges} -> Map.to_list(edges)
        :error -> []
      end

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

      ki_in_target = calculate_ki_in(graph, state, node, target_comm)
      sigma_tot_target = Map.get(state.community_totals, target_comm, 0.0)
      delta_q_add = ki_in_target / m - gamma * (sigma_tot_target * ki / two_m_sq)
      ki_in_current = calculate_ki_in(graph, state, node, current_comm)
      sigma_tot_current = Map.get(state.community_totals, current_comm, 0.0)
      sigma_tot_c_minus_i = sigma_tot_current - ki
      delta_q_remove = ki_in_current / m - gamma * (sigma_tot_c_minus_i * ki / two_m_sq)

      delta_q_add - delta_q_remove
    end
  end

  defp calculate_ki_in(%Yog.Graph{out_edges: out_edges}, state, node, target_comm) do
    successors =
      case Map.fetch(out_edges, node) do
        {:ok, edges} -> Map.to_list(edges)
        :error -> []
      end

    List.foldl(successors, 0.0, fn {neighbor, weight}, acc ->
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

      {node, weight_sum / 1.0}
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
    unique_communities =
      assignments
      |> Map.values()
      |> Enum.uniq()
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
      Enum.reduce(communities, new_graph, fn {comm_id, _nodes}, g ->
        Yog.add_node(g, comm_id, nil)
      end)

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

          edge_key =
            if kind == :undirected and comm_u > comm_v do
              {comm_v, comm_u}
            else
              {comm_u, comm_v}
            end

          Map.update(inner_acc, edge_key, weight, &(&1 + weight))
        end)
      end)

    List.foldl(Map.to_list(edge_weights), new_graph, fn {{u, v}, weight}, g ->
      weight_to_add = if kind == :undirected and u != v, do: weight / 2.0, else: weight
      {:ok, new_g} = Yog.add_edge(g, u, v, weight_to_add)
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
