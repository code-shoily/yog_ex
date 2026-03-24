defmodule Yog.Community.CliquePercolation do
  @moduledoc """
  Clique Percolation Method (CPM) for detecting overlapping communities.

  Identifies communities by finding "chains" of adjacent k-cliques.
  Two k-cliques are adjacent if they share k-1 nodes. Unlike other
  algorithms, CPM can identify nodes that belong to multiple communities.

  ## Algorithm

  1. **Find** all maximal cliques (using Bron-Kerbosch)
  2. **Extract** all k-cliques from maximal cliques
  3. **Build** adjacency between k-cliques (share k-1 nodes)
  4. **Find** connected components of k-cliques
  5. **Merge** cliques in each component to form communities

  ## When to Use

  | Use Case | Recommendation |
  |----------|----------------|
  | Overlapping communities | ✓ Only algorithm in this module |
  | Dense networks with cliques | ✓ Excellent |
  | Sparse graphs | ✗ May find no communities |
  | Non-overlapping needed | Convert with `to_communities/1` |

  ## Complexity

  - **Time**: O(3^(V/3)) for maximal clique enumeration (worst case)
  - **Space**: O(V + E)

  **Note**: Clique enumeration can be expensive on large or dense graphs.

  ## Example

      # Detect overlapping communities (k=3 finds triangles)
      overlapping = Yog.Community.CliquePercolation.detect_overlapping(graph)

      # Convert to non-overlapping (assigns node to first community)
      communities = Yog.Community.CliquePercolation.to_communities(overlapping)

      # With custom k
      overlapping = Yog.Community.CliquePercolation.detect_overlapping_with_options(graph,
        k: 4
      )

  ## References

  - [Palla et al. 2005 - Uncovering overlapping community structure](https://doi.org/10.1038/nature03607)
  - [Wikipedia: Clique Percolation Method](https://en.wikipedia.org/wiki/Clique_percolation_method)

  > **Migration Note:** Migrated to pure Elixir in v0.53.0. Uses existing
  > Bron-Kerbosch algorithm from Yog.Property.Clique.
  """

  alias Yog.Community.{Overlapping, Result}
  alias Yog.Property.Clique

  @typedoc "Options for Clique Percolation Method"
  @type cpm_options :: %{k: integer()}

  @doc """
  Returns default options for CPM.

  ## Defaults

  - `k`: 3 - Size of the clique (typically 3 or 4)
  """
  @spec default_options() :: cpm_options()
  def default_options do
    %{k: 3}
  end

  @doc """
  Detects overlapping communities using CPM with default options.

  Returns overlapping communities where each node can belong to multiple communities.

  ## Example

      overlapping = Yog.Community.CliquePercolation.detect_overlapping(graph)
      IO.inspect(overlapping.num_communities)
  """
  @spec detect_overlapping(Yog.graph()) :: Overlapping.t()
  def detect_overlapping(graph) do
    detect_overlapping_with_options(graph, [])
  end

  @doc """
  Detects overlapping communities using CPM with custom options.

  ## Options

  - `:k` - Clique size (default: 3)

  ## Example

      overlapping = Yog.Community.CliquePercolation.detect_overlapping_with_options(graph,
        k: 4
      )
  """
  @spec detect_overlapping_with_options(Yog.graph(), keyword() | map()) ::
          Overlapping.t()
  def detect_overlapping_with_options(graph, opts) when is_list(opts) do
    detect_overlapping_with_options(graph, Map.new(opts))
  end

  def detect_overlapping_with_options(graph, opts) when is_map(opts) do
    options = Map.merge(default_options(), opts)
    k = options.k

    # 1. Find all maximal cliques (Bron-Kerbosch)
    maximal_cliques = Clique.all_maximal_cliques(graph)

    # 2. Extract all k-cliques from maximal cliques
    k_cliques =
      maximal_cliques
      |> Enum.flat_map(fn clique ->
        clique_list = MapSet.to_list(clique)

        if length(clique_list) < k do
          []
        else
          combinations(clique_list, k)
          |> Enum.map(&MapSet.new/1)
        end
      end)
      |> Enum.uniq()

    # 3. Build adjacency between k-cliques
    # Two k-cliques are adjacent if they share k-1 nodes
    clique_adj =
      k_cliques
      |> Enum.with_index()
      |> Map.new(fn {c1, i} ->
        neighbors =
          k_cliques
          |> Enum.with_index()
          |> Enum.reduce([], fn {c2, j}, acc ->
            if i < j and MapSet.size(MapSet.intersection(c1, c2)) == k - 1 do
              [j | acc]
            else
              acc
            end
          end)

        {i, neighbors}
      end)

    # 4. Find connected components of cliques
    clique_components = find_clique_components(clique_adj, length(k_cliques))

    # 5. Build node-to-communities memberships from clique components
    memberships =
      clique_components
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {component, comm_id}, acc ->
        # Get all nodes in this component
        component_nodes =
          component
          |> Enum.reduce(MapSet.new(), fn clique_idx, nodes_acc ->
            clique = Enum.at(k_cliques, clique_idx, MapSet.new())
            MapSet.union(nodes_acc, clique)
          end)

        # Add this community to each node's membership list
        Enum.reduce(component_nodes, acc, fn node, inner_acc ->
          Map.update(inner_acc, node, [comm_id], fn communities -> [comm_id | communities] end)
        end)
      end)

    Overlapping.new(memberships)
  end

  @doc """
  Converts overlapping communities to standard communities.

  Each node is assigned to the first community in its membership list.

  ## Example

      overlapping = Yog.Community.CliquePercolation.detect_overlapping(graph)
      communities = Yog.Community.CliquePercolation.to_communities(overlapping)
      IO.inspect(communities.num_communities)
  """
  @spec to_communities(Overlapping.t()) :: Result.t()
  def to_communities(overlapping) do
    Overlapping.to_result(overlapping)
  end

  # =============================================================================
  # HELPER FUNCTIONS
  # =============================================================================

  # Generate all k-combinations of a list
  defp combinations(_items, 0), do: [[]]
  defp combinations([], _k), do: []

  defp combinations([first | rest], k) do
    with_first =
      combinations(rest, k - 1)
      |> Enum.map(fn c -> [first | c] end)

    without_first = combinations(rest, k)

    with_first ++ without_first
  end

  # Find connected components in clique adjacency graph
  defp find_clique_components(adj, n) do
    # DFS to find connected components
    {_visited, components} =
      Enum.reduce(0..(n - 1), {MapSet.new(), []}, fn i, {visited, comps} ->
        if MapSet.member?(visited, i) do
          {visited, comps}
        else
          {new_visited, component} = dfs_component(i, adj, visited, [])
          {new_visited, [component | comps]}
        end
      end)

    components
  end

  defp dfs_component(u, adj, visited, component) do
    visited = MapSet.put(visited, u)
    component = [u | component]
    neighbors = Map.get(adj, u, [])

    Enum.reduce(neighbors, {visited, component}, fn v, {visited_acc, component_acc} ->
      if MapSet.member?(visited_acc, v) do
        {visited_acc, component_acc}
      else
        dfs_component(v, adj, visited_acc, component_acc)
      end
    end)
  end
end
