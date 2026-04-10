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
    all_nodes = Map.keys(graph.nodes)
    k = min(options.target_communities, length(all_nodes))

    case k do
      0 -> Result.new(%{})
      1 -> Result.new(Map.new(all_nodes, fn n -> {n, 0} end))
      _ -> initialize_and_run(graph, all_nodes, k, options)
    end
  end

  defp initialize_and_run(graph, all_nodes, k, options) do
    # Select k initial seed nodes and setup initial state
    shuffled_seeds = Yog.Utils.fisher_yates(all_nodes, options.seed)

    {assignments, sizes} =
      shuffled_seeds
      |> Enum.take(k)
      |> Enum.with_index()
      |> Enum.reduce({%{}, %{}}, fn {node, i}, {asgn, sz} ->
        {Map.put(asgn, node, i), Map.put(sz, i, 1)}
      end)

    # Shuffle once at start for the propagation order
    shuffled_nodes = Yog.Utils.fisher_yates(all_nodes, options.seed)

    do_fluid(
      graph,
      all_nodes,
      assignments,
      sizes,
      options.max_iterations,
      shuffled_nodes,
      options.seed + 1
    )
  end

  # =============================================================================
  # FLUID PROPAGATION
  # =============================================================================

  defp do_fluid(_graph, nodes, assignments, sizes, iters, _shuffled, _seed)
       when iters <= 0 do
    normalize_communities(nodes, assignments, sizes)
  end

  defp do_fluid(graph, nodes, assignments, sizes, iters, shuffled, seed) do
    {new_asgn, new_sz, changed, final_seed} =
      Enum.reduce(shuffled, {assignments, sizes, false, seed}, fn node, acc ->
        apply_fluid_propagation(graph, node, acc)
      end)

    if changed do
      do_fluid(graph, nodes, new_asgn, new_sz, iters - 1, shuffled, final_seed)
    else
      new_asgn
      |> assign_unassigned_nodes(nodes)
      |> then(&normalize_communities(nodes, &1, new_sz))
    end
  end

  defp apply_fluid_propagation(graph, node, {asgn, sizes, changed, seed}) do
    current_com = Map.get(asgn, node)

    if can_leave_community?(current_com, sizes) do
      # We attempt to find a better community. This will consume/update the seed.
      {best_c, new_seed, found} = find_max_density_community(graph, node, asgn, sizes, seed)

      if found and changing_community?(current_com, best_c) do
        {next_asgn, next_sizes} = update_state(asgn, sizes, node, current_com, best_c)
        {next_asgn, next_sizes, true, new_seed}
      else
        # Found nothing or community didn't change, but seed might have been updated by tie-breaking
        {asgn, sizes, changed, new_seed}
      end
    else
      # Cannot move, seed remains unchanged as we didn't even look for a new community
      {asgn, sizes, changed, seed}
    end
  end

  defp can_leave_community?(nil, _sizes), do: true
  defp can_leave_community?(com, sizes), do: Map.get(sizes, com, 0) > 1

  defp changing_community?(nil, _best_c), do: true
  defp changing_community?(current_c, best_c), do: current_c != best_c

  defp update_state(asgn, sizes, node, current_com, best_com) do
    next_asgn = Map.put(asgn, node, best_com)

    # Decrease old community size if it existed
    temp_sizes =
      if current_com do
        Map.update!(sizes, current_com, &(&1 - 1))
      else
        sizes
      end

    # Increment new community size
    next_sizes = Map.update(temp_sizes, best_com, 1, &(&1 + 1))

    {next_asgn, next_sizes}
  end

  defp find_max_density_community(%Yog.Graph{out_edges: out_edges}, node, asgn, sizes, seed) do
    successors = Map.get(out_edges, node, %{})

    successors
    |> Enum.reduce({nil, -1.0, [], seed}, fn {neighbor_id, weight}, acc ->
      calculate_neighbor_density(neighbor_id, weight, asgn, sizes, acc)
    end)
    |> resolve_community_ties()
  end

  defp calculate_neighbor_density(neighbor_id, weight, asgn, sizes, {best_c, max_d, ties, seed}) do
    case Map.get(asgn, neighbor_id) do
      nil ->
        {best_c, max_d, ties, seed}

      neighbor_com ->
        density = weight / Map.get(sizes, neighbor_com, 1)
        update_density_accumulator(neighbor_com, density, best_c, max_d, ties, seed)
    end
  end

  defp update_density_accumulator(com, d, _best, max_d, _ties, seed) when d > max_d do
    {com, d, [com], seed}
  end

  defp update_density_accumulator(com, d, best, max_d, ties, seed) when d == max_d do
    {best, max_d, [com | ties], seed}
  end

  defp update_density_accumulator(_com, _d, best, max_d, ties, seed) do
    {best, max_d, ties, seed}
  end

  defp resolve_community_ties({nil, _, _, seed}), do: {nil, seed, false}
  defp resolve_community_ties({best_c, _, [best_c], seed}), do: {best_c, seed, true}

  defp resolve_community_ties({best_c, _, candidates, seed}) do
    unique = Enum.uniq([best_c | candidates])

    case unique do
      [single] ->
        {single, seed, true}

      multi ->
        # Simple LCG-like tie breaker for stability
        r = rem(1_103_515_245 * seed + 12_345, 2_147_483_648)
        idx = rem(abs(r), length(multi))
        {Enum.at(multi, idx), seed + 1, true}
    end
  end

  defp assign_unassigned_nodes(assignments, nodes) do
    unassigned = Enum.filter(nodes, &(not Map.has_key?(assignments, &1)))

    if unassigned == [] do
      assignments
    else
      max_comm = assignments |> Map.values() |> Enum.max(fn -> -1 end)

      unassigned
      |> Enum.with_index(1)
      |> Enum.reduce(assignments, fn {node, idx}, acc ->
        Map.put(acc, node, max_comm + idx)
      end)
    end
  end

  # =============================================================================
  # HELPER FUNCTIONS
  # =============================================================================

  defp normalize_communities(nodes, assignments, sizes) do
    mapping =
      sizes
      |> Enum.filter(fn {_, size} -> size > 0 end)
      |> Enum.map(fn {id, _} -> id end)
      |> Enum.sort()
      |> Enum.with_index()
      |> Map.new()

    new_assignments =
      Map.new(nodes, fn node ->
        old_id = Map.get(assignments, node)
        {node, Map.get(mapping, old_id, 0)}
      end)

    Result.new(new_assignments)
  end
end
