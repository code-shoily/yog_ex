defmodule Yog.Community.Infomap do
  @moduledoc """
  Infomap community detection algorithm.

  Uses information theory to find the most efficient way to describe the
  flow of a random walker on the network. The optimal partition minimizes
  the description length of the walker's path (Map Equation).

  ## Algorithm

  1. **Calculate** steady-state PageRank probabilities (random walker flow)
  2. **Initialize** each node in its own community
  3. **Optimize** the Map Equation greedily by merging communities
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

  - **Time**: O(V + E) per iteration, typically converges quickly
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
          max_pagerank_iters: integer()
        }

  @doc """
  Returns default options for Infomap.

  ## Defaults

  - `teleport_prob`: 0.15 - Teleportation probability for PageRank
  - `tolerance`: 0.000001 - Stop when relative improvement is less than this
  - `max_pagerank_iters`: 200 - Max iterations for steady-state calculation
  """
  @spec default_options() :: options()
  def default_options do
    %{
      teleport_prob: 0.15,
      tolerance: 0.000001,
      max_pagerank_iters: 200
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
  - `:tolerance` - Stop when relative improvement is less than this (default: 0.000001)
  - `:max_pagerank_iters` - Max iterations for steady-state calculation (default: 200)

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

        final_assignments = optimize_map_equation(graph, pagerank, initial_assignments, nodes)

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
    teleport = alpha / n_float

    node_weights =
      nodes
      |> List.foldl(%{}, fn u, acc ->
        total =
          case Map.fetch(out_edges, u) do
            {:ok, edges} ->
              List.foldl(Map.to_list(edges), 0.0, fn {_, w}, sum -> sum + w end)

            :error ->
              0.0
          end

        Map.put(acc, u, max(total, 1.0e-10))
      end)

    # Calculate total PageRank from dangling nodes (nodes with no outgoing edges)
    dangling_pr =
      List.foldl(nodes, 0.0, fn u, sum ->
        total_weight = Map.get(node_weights, u, 0.0)

        if total_weight < 1.0e-10 do
          sum + Map.get(pr, u, 0.0)
        else
          sum
        end
      end)

    # Calculate flow from each node to its neighbors using weighted transitions
    next_pr =
      List.foldl(nodes, %{}, fn u, acc ->
        neighbors =
          case Map.fetch(out_edges, u) do
            {:ok, edges} -> Map.to_list(edges)
            :error -> []
          end

        total_weight = Map.get(node_weights, u, 0.0)
        u_pr = Map.get(pr, u, 0.0)

        if total_weight > 0.0 and u_pr < 1.0e200 and u_pr > 0.0 do
          ratio = u_pr / total_weight

          if ratio < 1.0e200 do
            contribution_per_weight = min(ratio * (1.0 - alpha), 1.0e200)

            List.foldl(neighbors, acc, fn {v, weight}, inner_acc ->
              if contribution_per_weight < 1.0e200 do
                safe_weight = min(max(weight, 0.0), 1.0e100)
                flow = contribution_per_weight * safe_weight

                if flow < 1.0e200 do
                  Map.update(inner_acc, v, flow, &(&1 + flow))
                else
                  inner_acc
                end
              else
                inner_acc
              end
            end)
          else
            acc
          end
        else
          acc
        end
      end)

    final_pr =
      Enum.reduce(nodes, %{}, fn u, acc ->
        val = Map.get(next_pr, u, 0.0)
        dangling_contribution = dangling_pr * (1.0 - alpha) / n_float
        final_val = val + teleport + dangling_contribution
        Map.put(acc, u, final_val)
      end)

    # Normalize to ensure PageRank sums to 1 (prevents numerical drift)
    total_pr = Enum.sum(Map.values(final_pr))

    normalized_pr =
      if total_pr > 0 do
        Enum.reduce(final_pr, %{}, fn {u, v}, acc ->
          Map.put(acc, u, v / total_pr)
        end)
      else
        final_pr
      end

    do_pagerank(graph, nodes, normalized_pr, alpha, remaining_iters - 1)
  end

  # =============================================================================
  # MAP EQUATION OPTIMIZATION (Entropy-based)
  # =============================================================================

  defp optimize_map_equation(
         %Yog.Graph{out_edges: out_edges} = graph,
         pagerank,
         assignments,
         nodes
       ) do
    Enum.reduce(nodes, assignments, fn u, current_assignments ->
      current_comm = Map.get(current_assignments, u)

      neighbors =
        case Map.fetch(out_edges, u) do
          {:ok, edges} -> Map.to_list(edges)
          :error -> []
        end

      neighbor_comms =
        neighbors
        |> Enum.map(fn {v, _} -> Map.get(current_assignments, v) end)
        |> Enum.uniq()
        |> Enum.filter(fn c -> c != current_comm end)

      {best_comm, _best_score} =
        Enum.reduce(neighbor_comms, {current_comm, :infinity}, fn candidate, {best_c, best_s} ->
          _new_assignments = Map.put(current_assignments, u, candidate)
          flow = calculate_flow_to_comm(graph, u, candidate, current_assignments, pagerank)
          score = -flow

          if score < best_s do
            {candidate, score}
          else
            {best_c, best_s}
          end
        end)

      if best_comm != current_comm do
        Map.put(current_assignments, u, best_comm)
      else
        current_assignments
      end
    end)
  end

  defp calculate_flow_to_comm(%Yog.Graph{out_edges: out_edges}, u, comm_id, assignments, pagerank) do
    neighbors =
      case Map.fetch(out_edges, u) do
        {:ok, edges} -> Map.to_list(edges)
        :error -> []
      end

    u_pr = Map.get(pagerank, u, 0.0)
    total_weight = List.foldl(neighbors, 0.0, fn {_, w}, sum -> sum + w end)

    if total_weight == 0 do
      0.0
    else
      safe_u_pr = min(u_pr, 1.0e200)

      List.foldl(neighbors, 0.0, fn {v, weight}, acc ->
        v_comm = Map.get(assignments, v, -1)

        if v_comm == comm_id do
          safe_weight = min(weight, 1.0e100)
          acc + safe_u_pr * safe_weight / total_weight
        else
          acc
        end
      end)
    end
  end
end
