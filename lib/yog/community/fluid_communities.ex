defmodule Yog.Community.FluidCommunities do
  @moduledoc """
  Asynchronous Fluid Communities detection algorithm.

  This algorithm is based on the simple idea of fluids interacting and expanding
  in a graph environment. It is unique in that it allows specifying exactly
  the number of communities `k` to find.

  The algorithm starts with `k` randomly placed fluids (seeds). Each fluid
  has a density that decreases as the community grows. Nodes iteratively
  update their community to match the fluid with the highest density in their
  neighborhood. The process completes when no node changes its community.

  ## Algorithm

  1. **Initialize** k random seed nodes as community centers
  2. **Iterate** until convergence or max iterations:
     - Shuffle nodes randomly
     - For each node: join the community with highest fluid density in neighborhood
     - Density decreases as community size increases (density = weight / size)
  3. **Normalize** community IDs to be contiguous

  ## When to Use

  | Use Case | Recommendation |
  |----------|----------------|
  | Known number of communities (k) | ✓ Excellent |
  | Fast detection | ✓ Good performance |
  | Large graphs | ✓ Scalable |
  | Unknown k | Use Louvain/Leiden instead |

  ## Complexity

  - **Time**: O(k × m × E) where k is communities, m is max iterations
  - **Space**: O(V + E)

  ## Example

      # Find exactly 4 communities
      communities = Yog.Community.FluidCommunities.detect_with_options(graph,
        target_communities: 4,
        max_iterations: 100,
        seed: 42
      )

      # Default: 2 communities
      communities = Yog.Community.FluidCommunities.detect(graph)

  ## References

  - Parés, F., et al. (2017). Fluid Communities: A Competitive, Scalable and Diverse Community Detection Algorithm.

  """

  use Yog.Algorithm

  alias Yog.Community.Result

  @typedoc "Options for Fluid Communities algorithm"
  @type fluid_options :: %{
          target_communities: integer(),
          max_iterations: integer(),
          seed: integer()
        }

  @doc """
  Returns default options for Fluid Communities.

  ## Defaults

  - `target_communities`: 2 - Number of communities to find
  - `max_iterations`: 100 - Maximum propagation iterations
  - `seed`: 42 - Random seed for reproducibility
  """
  @spec default_options() :: fluid_options()
  def default_options do
    %{target_communities: 2, max_iterations: 100, seed: 42}
  end

  @doc """
  Detects communities using Fluid Communities with default options.

  ## Example

      communities = Yog.Community.FluidCommunities.detect(graph)
      IO.inspect(communities.num_communities)
  """
  @spec detect(Yog.graph()) :: Result.t()
  def detect(graph) do
    detect_with_options(graph, [])
  end

  @doc """
  Detects communities using Fluid Communities with custom options.

  ## Options

  - `:target_communities` - Number of communities to find (default: 2)
  - `:max_iterations` - Maximum iterations (default: 100)
  - `:seed` - Random seed (default: 42)

  ## Example

      communities = Yog.Community.FluidCommunities.detect_with_options(graph,
        target_communities: 5,
        max_iterations: 150,
        seed: 123
      )
  """
  @spec detect_with_options(Yog.graph(), keyword() | map()) :: Result.t()
  def detect_with_options(graph, opts) when is_list(opts) do
    detect_with_options(graph, Map.new(opts))
  end

  def detect_with_options(graph, opts) when is_map(opts) do
    options = Map.merge(default_options(), opts)
    all_nodes = Model.all_nodes(graph)
    k = min(options.target_communities, length(all_nodes))

    case k do
      0 ->
        Result.new(%{})

      1 ->
        assignments = Map.new(all_nodes, fn n -> {n, 0} end)
        Result.new(assignments)

      _ ->
        # Select k initial seed nodes
        shuffled_nodes = Yog.Utils.fisher_yates(all_nodes, options.seed)
        initial_nodes = Enum.take(shuffled_nodes, k)

        # Initialize assignments and sizes
        {assignments, sizes} =
          initial_nodes
          |> Enum.with_index()
          |> Enum.reduce({%{}, %{}}, fn {node, i}, {asgn, sz} ->
            {Map.put(asgn, node, i), Map.put(sz, i, 1)}
          end)

        # Shuffle once at start using O(V) Fisher-Yates
        shuffled = Yog.Utils.fisher_yates(all_nodes, options.seed)

        do_fluid(
          graph,
          all_nodes,
          assignments,
          sizes,
          options.max_iterations,
          shuffled,
          options.seed + 1
        )
    end
  end

  # =============================================================================
  # FLUID PROPAGATION
  # =============================================================================

  defp do_fluid(_graph, nodes, assignments, sizes, iters, _shuffled, _seed)
       when iters <= 0 do
    normalize_communities(nodes, assignments, sizes)
  end

  defp do_fluid(graph, nodes, assignments, sizes, iters, shuffled, seed) do
    {new_assignments, new_sizes, changed, final_seed} =
      Enum.reduce(shuffled, {assignments, sizes, false, seed}, fn node,
                                                                  {curr_asgn, curr_sizes,
                                                                   has_changed, current_seed} ->
        current_com = Map.get(curr_asgn, node)

        # Check if node can move (not the last member of its community)
        can_move =
          case current_com do
            nil ->
              true

            c ->
              case Map.get(curr_sizes, c, 0) do
                s when s <= 1 -> false
                _ -> true
              end
          end

        if can_move do
          # Single-pass: find max density community without intermediate Map
          # Incorporates edge weights: density = weight / community_size
          {best_c, new_seed, found} =
            find_max_density_community(
              graph,
              node,
              curr_asgn,
              curr_sizes,
              current_seed
            )

          if found do
            changing =
              case current_com do
                nil -> true
                c -> c != best_c
              end

            if changing do
              # Perform the move
              next_asgn = Map.put(curr_asgn, node, best_c)

              # Decrease size of old community
              temp_sizes =
                case current_com do
                  nil ->
                    curr_sizes

                  old_c ->
                    old_size = Map.get(curr_sizes, old_c, 1)
                    Map.put(curr_sizes, old_c, old_size - 1)
                end

              # Increase size of new community
              best_c_size = Map.get(temp_sizes, best_c, 0)
              next_sizes = Map.put(temp_sizes, best_c, best_c_size + 1)

              {next_asgn, next_sizes, true, new_seed}
            else
              {curr_asgn, curr_sizes, has_changed, new_seed}
            end
          else
            # No assigned neighbors found - will be handled in fallback
            {curr_asgn, curr_sizes, has_changed, new_seed}
          end
        else
          {curr_asgn, curr_sizes, has_changed, current_seed}
        end
      end)

    if changed do
      do_fluid(graph, nodes, new_assignments, new_sizes, iters - 1, shuffled, final_seed)
    else
      # Fallback: assign any unassigned nodes (disconnected component handling)
      assignments_with_fallback = assign_unassigned_nodes(nodes, new_assignments, new_sizes)
      normalize_communities(nodes, assignments_with_fallback, new_sizes)
    end
  end

  # Single-pass reduction to find max density community without intermediate Map
  # Returns {best_community, new_seed, found?}
  defp find_max_density_community(graph, node, assignments, sizes, seed) do
    Model.successors(graph, node)
    |> Enum.reduce({nil, -1.0, nil, seed}, fn {neighbor_id, weight},
                                              {best_c, max_d, tie_candidates, current_seed} ->
      case Map.get(assignments, neighbor_id) do
        nil ->
          {best_c, max_d, tie_candidates, current_seed}

        neighbor_com ->
          com_size = Map.get(sizes, neighbor_com, 1)
          # Weighted density: weight / community_size
          density = weight / com_size

          cond do
            density > max_d ->
              # New max found
              {neighbor_com, density, [neighbor_com], current_seed}

            density == max_d ->
              # Tie - accumulate candidates
              {best_c, max_d, [neighbor_com | tie_candidates || []], current_seed}

            true ->
              {best_c, max_d, tie_candidates, current_seed}
          end
      end
    end)
    |> case do
      {nil, _, _, new_seed} ->
        # No assigned neighbors found
        {nil, new_seed, false}

      {best_c, _, nil, new_seed} ->
        # Single best community
        {best_c, new_seed, true}

      {best_c, _, candidates, new_seed} ->
        # Tie-breaking with random selection
        unique_candidates = Enum.uniq([best_c | candidates])

        {chosen, updated_seed} =
          case unique_candidates do
            [single] ->
              {single, new_seed}

            multi ->
              # LCG: simple deterministic pseudo-random
              r = rem(1_103_515_245 * new_seed + 12_345, 2_147_483_648)
              r_pos = abs(r)
              idx = rem(r_pos, length(multi))
              chosen = Enum.at(multi, idx, 0)
              {chosen, new_seed + 1}
          end

        {chosen, updated_seed, true}
    end
  end

  # Fallback: assign unassigned nodes to their own communities or nearest seed
  defp assign_unassigned_nodes(nodes, assignments, _sizes) do
    # Find unassigned nodes
    unassigned = Enum.filter(nodes, fn n -> Map.get(assignments, n) == nil end)

    if unassigned == [] do
      assignments
    else
      # Get max existing community ID
      max_comm =
        assignments
        |> Map.values()
        |> Enum.max(fn -> -1 end)

      # Assign each unassigned node to a new community
      Enum.reduce(Enum.with_index(unassigned), assignments, fn {node, idx}, acc ->
        Map.put(acc, node, max_comm + idx + 1)
      end)
    end
  end

  # =============================================================================
  # HELPER FUNCTIONS
  # =============================================================================

  defp normalize_communities(nodes, assignments, sizes) do
    # Re-index community IDs to be contiguous
    active_communities =
      sizes
      |> Enum.filter(fn {_, size} -> size > 0 end)
      |> Enum.map(fn {id, _} -> id end)
      |> Enum.sort()

    mapping =
      active_communities
      |> Enum.with_index()
      |> Map.new(fn {old_id, i} -> {old_id, i} end)

    default_c = 0

    new_assignments =
      Map.new(nodes, fn node ->
        old_id = Map.get(assignments, node, -1)
        new_id = Map.get(mapping, old_id, default_c)
        {node, new_id}
      end)

    Result.new(new_assignments)
  end
end
