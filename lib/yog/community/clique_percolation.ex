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

  """

  alias Yog.Community.{Overlapping, Result}
  alias Yog.Property.Clique
  alias Yog.Utils

  # Maximum number of k-cliques to process before raising an error
  # Prevents memory exhaustion on graphs with large maximal cliques
  @max_k_cliques 100_000

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

    maximal_cliques = Clique.all_maximal_cliques(graph)
    estimated_cliques = estimate_k_cliques(maximal_cliques, k)

    if estimated_cliques > @max_k_cliques do
      raise ArgumentError,
            "CPM would generate too many k-cliques (#{estimated_cliques} > #{@max_k_cliques}). " <>
              "Try increasing k (current: #{k}) or using a different algorithm."
    end

    k_cliques_list =
      maximal_cliques
      |> Enum.flat_map(fn clique ->
        clique_list = MapSet.to_list(clique)

        if length(clique_list) < k do
          []
        else
          combinations_to_mapsets(clique_list, k)
        end
      end)
      |> Enum.uniq()

    k_cliques = List.to_tuple(k_cliques_list)
    num_cliques = tuple_size(k_cliques)

    if num_cliques == 0 do
      Overlapping.new(%{})
    else
      clique_adj = build_clique_adjacency_indexed(k_cliques, num_cliques, k)
      clique_components = find_clique_components(clique_adj, num_cliques)

      memberships =
        clique_components
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {component, comm_id}, acc ->
          component_nodes =
            component
            |> Enum.reduce(MapSet.new(), fn clique_idx, nodes_acc ->
              clique = elem(k_cliques, clique_idx)
              MapSet.union(nodes_acc, clique)
            end)

          Enum.reduce(component_nodes, acc, fn node, inner_acc ->
            Map.update(inner_acc, node, [comm_id], fn communities -> [comm_id | communities] end)
          end)
        end)

      Overlapping.new(memberships)
    end
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

  # Estimate total number of k-cliques before generation
  defp estimate_k_cliques(maximal_cliques, k) do
    Enum.reduce(maximal_cliques, 0, fn clique, acc ->
      n = MapSet.size(clique)

      if n < k do
        acc
      else
        # C(n, k) = n! / (k! * (n-k)!)
        acc + comb(n, k)
      end
    end)
  end

  defp comb(n, k) when k > n, do: 0
  defp comb(_n, 0), do: 1
  defp comb(n, k) when k > div(n, 2), do: comb(n, n - k)

  defp comb(n, k) do
    Enum.reduce(1..k, 1, fn i, acc ->
      (acc * (n - k + i)) |> div(i)
    end)
  end

  # Generate MapSets directly without intermediate list allocations
  defp combinations_to_mapsets(items, k) do
    items
    |> Utils.combinations(k)
    |> Enum.map(&MapSet.new/1)
  end

  defp build_clique_adjacency_indexed(k_cliques_tuple, num_cliques, k) do
    inverted_index =
      Enum.reduce(0..(num_cliques - 1), %{}, fn i, acc ->
        clique = elem(k_cliques_tuple, i)
        clique_list = MapSet.to_list(clique)

        # Generate all (k-1)-subsets
        subcliques = Utils.combinations(clique_list, k - 1)

        Enum.reduce(subcliques, acc, fn subclique, inner_acc ->
          sub_key = MapSet.new(subclique)
          Map.update(inner_acc, sub_key, [i], &[i | &1])
        end)
      end)

    # Build adjacency: two cliques are adjacent if they share a (k-1)-subclique
    Enum.reduce(0..(num_cliques - 1), %{}, fn i, acc ->
      clique = elem(k_cliques_tuple, i)
      clique_list = MapSet.to_list(clique)
      subcliques = Utils.combinations(clique_list, k - 1)

      neighbors =
        subcliques
        |> Enum.flat_map(fn subclique ->
          sub_key = MapSet.new(subclique)
          Map.get(inverted_index, sub_key, [])
        end)
        |> Enum.uniq()
        |> Enum.reject(&(&1 == i))

      Map.put(acc, i, neighbors)
    end)
  end

  defp find_clique_components(adj, n) do
    {_visited, components} =
      Enum.reduce(Enum.to_list(0..(n - 1)//1), {MapSet.new(), []}, fn i, {visited, comps} ->
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
