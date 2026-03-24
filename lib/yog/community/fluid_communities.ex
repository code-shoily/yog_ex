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
     - Density decreases as community size increases (density = 1 / size)
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

  > **Migration Note:** Migrated to pure Elixir in v0.53.0. Implements fluid density
  > propagation with random node processing order.
  """

  alias Yog.Community.Result
  alias Yog.Model

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
    all_nodes = Yog.all_nodes(graph)
    k = min(options.target_communities, length(all_nodes))

    case k do
      0 ->
        Result.new(%{})

      1 ->
        assignments = Map.new(all_nodes, fn n -> {n, 0} end)
        Result.new(assignments)

      _ ->
        # Select k initial seed nodes
        shuffled_nodes = shuffle(all_nodes, options.seed)
        initial_nodes = Enum.take(shuffled_nodes, k)

        # Initialize assignments and sizes
        {assignments, sizes} =
          initial_nodes
          |> Enum.with_index()
          |> Enum.reduce({%{}, %{}}, fn {node, i}, {asgn, sz} ->
            {Map.put(asgn, node, i), Map.put(sz, i, 1)}
          end)

        do_fluid(graph, all_nodes, assignments, sizes, options.max_iterations, options.seed + 1)
    end
  end

  # =============================================================================
  # FLUID PROPAGATION
  # =============================================================================

  defp do_fluid(_graph, nodes, assignments, sizes, iters, _seed) when iters <= 0 do
    normalize_communities(nodes, assignments, sizes)
  end

  defp do_fluid(graph, nodes, assignments, sizes, iters, seed) do
    shuffled = shuffle(nodes, seed)
    next_seed = seed + 1

    {new_assignments, new_sizes, changed, final_seed} =
      Enum.reduce(shuffled, {assignments, sizes, false, next_seed}, fn node,
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
          # Calculate density sums for neighbor communities
          density_sums =
            Model.successors(graph, node)
            |> Enum.reduce(%{}, fn {neighbor_id, _weight}, densities ->
              case Map.get(curr_asgn, neighbor_id) do
                nil ->
                  densities

                neighbor_com ->
                  com_size = Map.get(curr_sizes, neighbor_com, 1)
                  # Fluid density = 1 / community_size
                  density = 1.0 / com_size
                  existing = Map.get(densities, neighbor_com, 0.0)
                  Map.put(densities, neighbor_com, existing + density)
              end
            end)

          if map_size(density_sums) == 0 do
            # No assigned neighbors
            {curr_asgn, curr_sizes, has_changed, current_seed}
          else
            # Find communities with max density sum
            {best_com_candidates, _max_d} =
              Enum.reduce(density_sums, {[], -1.0}, fn {c, d_sum}, {best_coms, max_d} ->
                cond do
                  d_sum > max_d -> {[c], d_sum}
                  d_sum == max_d -> {[c | best_coms], max_d}
                  true -> {best_coms, max_d}
                end
              end)

            # Tie breaking with random selection
            {best_c, new_seed} =
              case best_com_candidates do
                [single] ->
                  {single, current_seed}

                multi ->
                  # LCG: simple deterministic pseudo-random
                  r = rem(1_103_515_245 * current_seed + 12_345, 2_147_483_648)
                  r_pos = abs(r)
                  idx = rem(r_pos, length(multi))
                  chosen = Enum.at(multi, idx, 0)
                  {chosen, current_seed + 1}
              end

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
          end
        else
          {curr_asgn, curr_sizes, has_changed, current_seed}
        end
      end)

    if changed do
      do_fluid(graph, nodes, new_assignments, new_sizes, iters - 1, final_seed)
    else
      normalize_communities(nodes, new_assignments, sizes)
    end
  end

  # =============================================================================
  # HELPER FUNCTIONS
  # =============================================================================

  defp normalize_communities(nodes, assignments, sizes) do
    # Re-index community IDs to be contiguous from 0
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

  # Deterministic shuffle using Linear Congruential Generator
  defp shuffle(list, seed) do
    # LCG parameters (same as glibc)
    a = 1_103_515_245
    c = 12_345
    m = 2_147_483_648

    list
    |> Enum.with_index()
    |> Enum.map(fn {item, i} ->
      rand = rem(a * (seed + i) + c, m)
      {rand, item}
    end)
    |> Enum.sort_by(fn {rand, _} -> rand end)
    |> Enum.map(fn {_, item} -> item end)
  end
end
