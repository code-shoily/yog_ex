defmodule Yog.Community.Infomap do
  @moduledoc """
  Infomap community detection algorithm.

  Uses information theory to find the most efficient way to describe the
  flow of a random walker on the network. The optimal partition minimizes
  the description length of the walker's path (Map Equation).

  ## Algorithm

  1. **Calculate** steady-state PageRank probabilities (random walker flow)
  2. **Initialize** each node in its own community
  3. **Optimize** the Map Equation greedily by moving nodes to communities
     that reduce the description length L(M)
  4. **Repeat** until no improvement in description length

  ## Map Equation

  The Map Equation L(M) = q_↷ H(Q) + Σ p_↻^i H(P^i)

  where:
  - q_↷ is the probability of entering any community (exit rate)
  - H(Q) is the entropy of community transitions
  - p_↻^i is the probability of being in community i and exiting
  - H(P^i) is the entropy of node transitions within community i

  ## When to Use

  | Use Case | Recommendation |
  |----------|----------------|
  | Flow-based communities | ✓ Excellent |
  | Random walk structure | ✓ Designed for this |
  | Directed graphs | ✓ Good (uses PageRank flow) |
  | Information-theoretic interpretation | ✓ Provides description length |

  ## Complexity

  - **Time**: O(iterations × V × d × (V + E)) where d is average degree
  - **Space**: O(V + E)

  ## Example

      graph =
        Yog.directed()
        |> Yog.add_node(1, "Home")
        |> Yog.add_node(2, "About")
        |> Yog.add_node(3, "Contact")
        |> Yog.add_edges!([{1, 2, 1}, {2, 1, 1}, {2, 3, 1}])

      # Basic usage
      communities = Yog.Community.Infomap.detect(graph)
      IO.inspect(communities.num_communities)

      # With custom options
      options = %{
        teleport_prob: 0.15,
        tolerance: 0.000001,
        max_pagerank_iters: 200
      }
      communities = Yog.Community.Infomap.detect_with_options(graph, options)

  ## References

  - [Rosvall & Bergstrom 2008 - Maps of information flow](https://doi.org/10.1073/pnas.0706851105)
  - [MapEquation.org](https://www.mapequation.org/)

  """

  alias Yog.Community.Result

  @typedoc "Options for Infomap algorithm"
  @type options :: %{
          teleport_prob: float(),
          tolerance: float(),
          max_pagerank_iters: integer(),
          seed: integer()
        }

  @doc """
  Returns default options for Infomap.

  ## Defaults

  - `teleport_prob`: 0.15 - Teleportation probability for PageRank
  - `tolerance`: 0.000001 - Minimum improvement in L(M) to accept a move
  - `max_pagerank_iters`: 200 - Max iterations for PageRank and optimization
  - `seed`: 42 - Random seed for node shuffling
  """
  @spec default_options() :: options()
  def default_options do
    %{
      teleport_prob: 0.15,
      tolerance: 0.000001,
      max_pagerank_iters: 200,
      seed: 42
    }
  end

  @doc """
  Detects communities using the Infomap algorithm with default options.

  ## Example

      communities = Yog.Community.Infomap.detect(graph)
      IO.inspect(communities.num_communities)
  """
  @spec detect(Yog.graph()) :: Result.t()
  def detect(graph) do
    detect_with_options(graph, default_options())
  end

  @doc """
  Detects communities using Infomap with custom options.

  ## Options

  - `:teleport_prob` - Teleportation probability for PageRank (default: 0.15)
  - `:tolerance` - Minimum improvement in L(M) to accept a move (default: 0.000001)
  - `:max_pagerank_iters` - Max iterations for PageRank and optimization (default: 200)
  - `:seed` - Random seed for node shuffling (default: 42)

  ## Example

      options = %{teleport_prob: 0.1, max_pagerank_iters: 300}
      communities = Yog.Community.Infomap.detect_with_options(graph, options)
  """
  @spec detect_with_options(Yog.graph(), options() | keyword()) :: Result.t()
  def detect_with_options(graph, opts) when is_list(opts) do
    detect_with_options(graph, Map.new(opts))
  end

  def detect_with_options(graph, opts) when is_map(opts) do
    options = Map.merge(default_options(), opts)
    nodes = Map.keys(graph.nodes)
    n = length(nodes)

    case n do
      0 ->
        Result.new(%{})

      1 ->
        [node] = nodes
        Result.new(%{node => 0})

      _ ->
        pagerank = calculate_pagerank(graph, nodes, options)

        initial_assignments =
          nodes
          |> Enum.with_index()
          |> Map.new()

        final_assignments =
          optimize_map_equation(graph, pagerank, initial_assignments, nodes, options)

        Result.new(final_assignments)
    end
  end

  # =============================================================================
  # PAGERANK CALCULATION (with weighted transitions)
  # =============================================================================

  defp calculate_pagerank(graph, nodes, options) do
    n = length(nodes)
    n_float = n / 1.0

    initial_pr =
      nodes
      |> Enum.reduce(%{}, fn u, acc -> Map.put(acc, u, 1.0 / n_float) end)

    do_pagerank(
      graph,
      nodes,
      initial_pr,
      options.teleport_prob,
      options.max_pagerank_iters
    )
  end

  defp do_pagerank(_graph, _nodes, pr, _alpha, 0), do: pr

  defp do_pagerank(%Yog.Graph{out_edges: out_edges} = graph, nodes, pr, alpha, remaining_iters) do
    n_float = length(nodes) / 1.0

    node_weights = calculate_node_weights(nodes, out_edges)
    dangling_pr = calculate_dangling_pr(nodes, pr, node_weights)
    next_pr = calculate_node_flows(nodes, out_edges, node_weights, pr, alpha)

    final_pr = finalize_pr(nodes, next_pr, dangling_pr, alpha, n_float)
    normalized_pr = normalize_pr(final_pr)

    do_pagerank(graph, nodes, normalized_pr, alpha, remaining_iters - 1)
  end

  defp calculate_node_weights(nodes, out_edges) do
    Enum.reduce(nodes, %{}, fn u, acc ->
      total =
        case Map.get(out_edges, u) do
          nil -> 0.0
          edges -> edges |> Map.values() |> Enum.sum()
        end

      Map.put(acc, u, max(total, 1.0e-10))
    end)
  end

  defp calculate_dangling_pr(nodes, pr, node_weights) do
    Enum.reduce(nodes, 0.0, fn u, sum ->
      if Map.get(node_weights, u, 0.0) < 1.0e-10 do
        sum + Map.get(pr, u, 0.0)
      else
        sum
      end
    end)
  end

  defp calculate_node_flows(nodes, out_edges, node_weights, pr, alpha) do
    Enum.reduce(nodes, %{}, fn u, acc ->
      total_weight = Map.get(node_weights, u, 0.0)
      u_pr = Map.get(pr, u, 0.0)

      if total_weight > 0.0 and u_pr > 0.0 and u_pr < 1.0e200 do
        add_node_flow(acc, u, u_pr, total_weight, out_edges, alpha)
      else
        acc
      end
    end)
  end

  defp add_node_flow(acc, u, u_pr, total_weight, out_edges, alpha) do
    ratio = u_pr / total_weight

    if ratio < 1.0e200 do
      contribution = min(ratio * (1.0 - alpha), 1.0e200)
      neighbors = Map.get(out_edges, u, %{})

      Enum.reduce(neighbors, acc, fn {v, weight}, inner_acc ->
        update_flow(inner_acc, v, weight, contribution)
      end)
    else
      acc
    end
  end

  defp update_flow(acc, v, weight, contribution) do
    if contribution < 1.0e200 do
      safe_weight = min(max(weight, 0.0), 1.0e100)
      flow = contribution * safe_weight

      if flow < 1.0e200 do
        Map.update(acc, v, flow, &(&1 + flow))
      else
        acc
      end
    else
      acc
    end
  end

  defp finalize_pr(nodes, next_pr, dangling_pr, alpha, n_float) do
    teleport = alpha / n_float
    dangling_contribution = dangling_pr * (1.0 - alpha) / n_float

    Map.new(nodes, fn u ->
      val = Map.get(next_pr, u, 0.0)
      {u, val + teleport + dangling_contribution}
    end)
  end

  defp normalize_pr(pr_map) do
    total = pr_map |> Map.values() |> Enum.sum()

    if total > 0 do
      Map.new(pr_map, fn {u, v} -> {u, v / total} end)
    else
      pr_map
    end
  end

  # =============================================================================
  # MAP EQUATION OPTIMIZATION
  # =============================================================================

  defp optimize_map_equation(graph, pagerank, assignments, nodes, options) do
    shuffled = Yog.Utils.fisher_yates(nodes, options.seed)
    do_optimize_passes(graph, pagerank, assignments, shuffled, true, 0, options)
  end

  defp do_optimize_passes(_graph, _pagerank, assignments, _nodes, false, _iteration, _options) do
    assignments
  end

  defp do_optimize_passes(graph, pagerank, assignments, nodes, _changed, iteration, options) do
    if iteration >= options.max_pagerank_iters do
      assignments
    else
      {new_assignments, improved} = do_optimize_pass(graph, pagerank, assignments, nodes, options)

      if improved do
        do_optimize_passes(graph, pagerank, new_assignments, nodes, true, iteration + 1, options)
      else
        new_assignments
      end
    end
  end

  defp do_optimize_pass(graph, pagerank, assignments, nodes, options) do
    Enum.reduce(nodes, {assignments, false}, fn u, {current_assignments, changed} ->
      current_comm = Map.get(current_assignments, u)

      candidate_comms =
        get_neighbor_communities(graph, u, current_assignments)
        |> Enum.concat([current_comm])
        |> Enum.uniq()

      current_lm = compute_map_equation(graph, current_assignments, pagerank)

      {best_comm, best_delta} =
        Enum.reduce(candidate_comms, {current_comm, 0.0}, fn candidate, {best_c, best_delta} ->
          if candidate == current_comm do
            {best_c, best_delta}
          else
            new_assignments = Map.put(current_assignments, u, candidate)
            new_lm = compute_map_equation(graph, new_assignments, pagerank)
            delta = new_lm - current_lm

            if delta < best_delta do
              {candidate, delta}
            else
              {best_c, best_delta}
            end
          end
        end)

      if best_comm != current_comm and best_delta < -options.tolerance do
        {Map.put(current_assignments, u, best_comm), true}
      else
        {current_assignments, changed}
      end
    end)
  end

  defp get_neighbor_communities(%Yog.Graph{out_edges: out_edges}, u, assignments) do
    neighbors =
      case Map.fetch(out_edges, u) do
        {:ok, edges} -> Map.keys(edges)
        :error -> []
      end

    neighbors
    |> Enum.map(fn v -> Map.get(assignments, v) end)
    |> Enum.uniq()
  end

  # =============================================================================
  # MAP EQUATION COMPUTATION
  # =============================================================================

  defp compute_map_equation(graph, assignments, pagerank) do
    communities = group_nodes_by_community(assignments)

    comm_stats =
      Map.new(communities, fn {comm_id, nodes_in_comm} ->
        p_alpha = Enum.sum(Enum.map(nodes_in_comm, fn u -> Map.get(pagerank, u, 0.0) end))
        q_exit = compute_exit_rate(graph, nodes_in_comm, assignments, pagerank)
        p_loop = p_alpha + q_exit

        {comm_id,
         %{
           p: p_alpha,
           q_exit: q_exit,
           p_loop: p_loop,
           nodes: nodes_in_comm
         }}
      end)

    q_total = Enum.sum(Enum.map(comm_stats, fn {_, stats} -> stats.q_exit end))

    h_q =
      if q_total > 0 do
        -Enum.sum(
          Enum.map(comm_stats, fn {_, stats} ->
            q = stats.q_exit

            if q > 0 do
              ratio = q / q_total
              ratio * :math.log2(ratio)
            else
              0.0
            end
          end)
        )
      else
        0.0
      end

    inner_terms =
      Enum.map(comm_stats, fn {_comm_id, stats} ->
        p_loop = stats.p_loop

        if p_loop > 0 do
          h_p =
            -Enum.sum(
              Enum.map(stats.nodes, fn u ->
                p_u = Map.get(pagerank, u, 0.0)

                if p_u > 0 do
                  ratio = p_u / p_loop
                  ratio * :math.log2(ratio)
                else
                  0.0
                end
              end)
            )

          -if stats.q_exit > 0 do
            ratio = stats.q_exit / p_loop
            ratio * :math.log2(ratio)
          else
            0.0
          end

          p_loop * h_p
        else
          0.0
        end
      end)

    q_total * h_q + Enum.sum(inner_terms)
  end

  defp compute_exit_rate(%Yog.Graph{out_edges: out_edges}, nodes_in_comm, _assignments, pagerank) do
    node_set = MapSet.new(nodes_in_comm)

    Enum.sum(
      Enum.map(nodes_in_comm, fn u ->
        p_u = Map.get(pagerank, u, 0.0)

        neighbors = Map.get(out_edges, u, %{})
        total_weight = Enum.sum(Map.values(neighbors))

        if total_weight > 0 and p_u > 0 do
          Enum.sum(
            Enum.map(neighbors, fn {v, weight} ->
              if MapSet.member?(node_set, v) do
                0.0
              else
                p_u * weight / total_weight
              end
            end)
          )
        else
          0.0
        end
      end)
    )
  end

  defp group_nodes_by_community(assignments) do
    Enum.reduce(assignments, %{}, fn {node, comm}, acc ->
      Map.update(acc, comm, [node], &[node | &1])
    end)
  end
end
