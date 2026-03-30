defmodule Yog.Community do
  @moduledoc """
  Community detection and clustering algorithms.

  Provides types and utility functions for working with community structures
  in graphs. Community detection algorithms identify groups of nodes that
  are more densely connected internally than with the rest of the graph.

  ## Algorithms

  | Algorithm | Module | Best For |
  |-----------|--------|----------|
  | Louvain | `Yog.Community.Louvain` | Large graphs, modularity optimization |
  | Leiden | `Yog.Community.Leiden` | Quality guarantee, well-connected communities |
  | Label Propagation | `Yog.Community.LabelPropagation` | Speed, near-linear time |
  | Girvan-Newman | `Yog.Community.GirvanNewman` | Hierarchical structure, edge betweenness |
  | Infomap | `Yog.Community.Infomap` | Information-theoretic, flow-based |
  | Clique Percolation | `Yog.Community.CliquePercolation` | Overlapping communities |
  | Walktrap | `Yog.Community.Walktrap` | Random walk-based distances |
  | Local Community | `Yog.Community.LocalCommunity` | Massive graphs, seed expansion |
  | Fluid Communities | `Yog.Community.FluidCommunities` | Exact `k` partitions, fast |

  ## Core Types

  - `Communities` - Community assignment mapping nodes to community IDs
  - `Dendrogram` - Hierarchical community structure with multiple levels
  - `CommunityId` - Integer identifier for a community

  ## Performance Notes

  For frequent community-level queries, use `to_dict/1` to convert the
  assignments map to a community-centric structure (community_id -> nodes).
  Functions like `sizes/1`, `nodes_in/2`, and `largest/1` perform O(V) scans;
  `to_dict/1` performs a single O(V) conversion that enables O(1) lookups
  for all subsequent community operations.

  ## Examples

      # Create a graph with clear community structure (two cliques connected by a bridge)
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_node(5, nil)
      ...> |> Yog.add_node(6, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)  # Triangle: 1-2-3
      ...> |> Yog.add_edge_ensure(from: 4, to: 5, with: 1)
      ...> |> Yog.add_edge_ensure(from: 5, to: 6, with: 1)
      ...> |> Yog.add_edge_ensure(from: 4, to: 6, with: 1)  # Triangle: 4-5-6
      ...> |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)  # Bridge between communities
      iex> communities = Yog.Community.Louvain.detect(graph)
      iex> communities.num_communities >= 2
      true
      iex> communities_dict = Yog.Community.to_dict(communities)
      iex> map_size(communities_dict) >= 2
      true
      iex> {:ok, _community_id} = Yog.Community.largest(communities)
      iex> true
      true

  ## Choosing an Algorithm

  - **Louvain**: Fast and widely used, good for most cases
  - **Leiden**: Better quality than Louvain, guarantees well-connected communities
  - **Label Propagation**: Fastest option for very large graphs
  - **Girvan-Newman**: When you need hierarchical structure
  - **Infomap**: When flow/random walk structure matters
  - **Clique Percolation**: When nodes may belong to multiple communities
  - **Walktrap**: Good for capturing local structure via random walks
  - **Local Community**: When the graph is massive/infinite and you only care about the immediate community around specific seeds
  - **Fluid Communities**: Fast and allows finding exactly `k` communities
  """
  alias Yog.Community.{Dendrogram, Metrics, Overlapping, Result}

  @typedoc "Community identifier"
  @type community_id :: integer()

  @typedoc "Community assignment for nodes"
  @type communities :: Result.t()

  @typedoc "Hierarchical community structure"
  @type dendrogram :: Dendrogram.t()

  @typedoc "Overlapping communities (nodes can belong to multiple)"
  @type overlapping_communities :: Overlapping.t()

  # ============================================================
  # Utility Functions
  # ============================================================

  @doc """
  Converts community assignments to a dictionary mapping community IDs to sets of node IDs.

  This is useful when you need to iterate over all nodes in each community
  rather than looking up the community for each node. This performs a single
  O(V) scan and produces a structure optimized for community-level queries.

  > **Performance Tip**: Use this function before making multiple community-level
  > queries. Functions like `sizes/1`, `nodes_in/2`, and `largest/1` each perform
  > O(V) scans. Converting once with `to_dict/1` enables O(1) lookups thereafter.

  ## Examples

      iex> communities = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 1})
      iex> Yog.Community.to_dict(communities)
      %{0 => MapSet.new([1, 2]), 1 => MapSet.new([3])}
  """
  @spec to_dict(communities()) :: %{community_id() => MapSet.t(Yog.node_id())}
  def to_dict(%Result{} = communities) do
    Enum.reduce(communities.assignments, %{}, fn {node, community}, acc ->
      current_set = Map.get(acc, community, MapSet.new())
      Map.put(acc, community, MapSet.put(current_set, node))
    end)
  end

  @doc """
  Returns the community ID with the largest number of nodes.

  Returns `:error` if there are no communities (empty graph or no assignments).

  ## Performance

  This function performs a single-pass O(V) reduction. For repeated queries,
  consider using `to_dict/1` first.

  ## Examples

      iex> communities = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 0, 4 => 1})
      iex> Yog.Community.largest(communities)
      {:ok, 0}
  """
  @spec largest(communities()) :: {:ok, community_id()} | :error
  def largest(%Result{} = communities) do
    # YOG-FAC-002: Single-pass reduction to find max-sized community
    communities.assignments
    |> Enum.reduce({%{}, {nil, 0}}, fn {_node, comm}, {counts, {max_c, max_s}} ->
      new_count = Map.get(counts, comm, 0) + 1
      new_counts = Map.put(counts, comm, new_count)

      if new_count > max_s do
        {new_counts, {comm, new_count}}
      else
        {new_counts, {max_c, max_s}}
      end
    end)
    |> case do
      {_, {nil, _}} -> :error
      {_, {comm, _}} -> {:ok, comm}
    end
  end

  @doc """
  Returns a dictionary mapping community IDs to their sizes (number of nodes).

  ## Performance

  This function performs a single O(V) scan. For repeated queries,
  consider using `to_dict/1` first.

  ## Examples

      iex> communities = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1, 5 => 1})
      iex> Yog.Community.sizes(communities)
      %{0 => 2, 1 => 3}
  """
  @spec sizes(communities()) :: %{community_id() => integer()}
  def sizes(%Result{} = communities) do
    Enum.reduce(communities.assignments, %{}, fn {_node, community}, acc ->
      current_size = Map.get(acc, community, 0)
      Map.put(acc, community, current_size + 1)
    end)
  end

  @doc """
  Merges two communities into one.

  All nodes from the source community are reassigned to the target community.
  The source community ID is effectively removed.

  ## Parameters

    * `communities` - The current community partition (can be Result struct or legacy map)
    * `source` - The community ID to merge from (will be removed)
    * `target` - The community ID to merge into (will be kept)

  ## Examples

      iex> communities = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1})
      iex> merged = Yog.Community.merge(communities, source: 1, target: 0)
      iex> merged.assignments
      %{1 => 0, 2 => 0, 3 => 0, 4 => 0}
      iex> merged.num_communities
      1
  """
  @spec merge(communities() | map(), source: community_id(), target: community_id()) ::
          communities() | map()
  def merge(%Result{} = communities, source: source, target: target) do
    # YOG-FAC-003: Only decrement num_communities if source exists
    source_exists =
      Enum.any?(communities.assignments, fn {_node, comm} -> comm == source end)

    new_assignments =
      Enum.reduce(communities.assignments, communities.assignments, fn
        {node, ^source}, acc ->
          Map.put(acc, node, target)

        _, acc ->
          acc
      end)

    num_communities =
      cond do
        source == target ->
          communities.num_communities

        source_exists ->
          communities.num_communities - 1

        true ->
          communities.num_communities
      end

    %Result{
      assignments: new_assignments,
      num_communities: num_communities,
      metadata: communities.metadata
    }
  end

  # Legacy map support
  def merge(%{assignments: _, num_communities: _} = communities, source: source, target: target) do
    # YOG-FAC-003: Only decrement num_communities if source exists
    source_exists =
      Enum.any?(communities.assignments, fn {_node, comm} -> comm == source end)

    new_assignments =
      Enum.reduce(communities.assignments, communities.assignments, fn
        {node, ^source}, acc ->
          Map.put(acc, node, target)

        _, acc ->
          acc
      end)

    num_communities =
      cond do
        source == target ->
          communities.num_communities

        source_exists ->
          communities.num_communities - 1

        true ->
          communities.num_communities
      end

    %{
      assignments: new_assignments,
      num_communities: num_communities
    }
  end

  @doc """
  Returns all nodes belonging to a specific community.

  ## Performance

  This function performs an O(V) scan. For repeated queries or checking
  multiple communities, use `to_dict/1` first for O(1) lookups.

  ## Examples

      iex> communities = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 0, 4 => 1})
      iex> Yog.Community.nodes_in(communities, 0)
      MapSet.new([1, 2, 3])
  """
  @spec nodes_in(communities(), community_id()) :: MapSet.t(Yog.node_id())
  def nodes_in(%Result{} = communities, community_id) do
    communities.assignments
    |> Enum.filter(fn {_, c} -> c == community_id end)
    |> Enum.map(fn {node, _} -> node end)
    |> MapSet.new()
  end

  @doc """
  Returns the community ID for a specific node.

  Returns `:error` if the node is not assigned to any community.

  ## Examples

      iex> communities = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 1})
      iex> Yog.Community.for_node(communities, 1)
      {:ok, 0}
      iex> Yog.Community.for_node(communities, 999)
      :error
  """
  @spec for_node(communities(), Yog.node_id()) :: {:ok, community_id()} | :error
  def for_node(%Result{} = communities, node) do
    Map.fetch(communities.assignments, node)
  end

  # ============================================================
  # Metrics (delegated to Metrics module)
  # ============================================================

  @doc """
  Calculates modularity for a given community partition.

  Modularity measures the quality of a division of a network into modules
  (communities). High modularity indicates that the community structure
  captures significant structural patterns in the graph.

  Range: [-0.5, 1.0]. Values > 0.3 indicate significant community structure.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> communities = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 0})
      iex> q = Yog.Community.modularity(graph, communities)
      iex> is_float(q)
      true
  """
  def modularity(graph, %Result{} = communities, opts \\ []) do
    # YOG-FAC-004: Metrics module now supports Result struct natively
    Metrics.modularity(graph, communities, opts)
  end

  @doc """
  Counts the total number of triangles in the graph.

  A triangle is a set of three nodes where each pair is connected.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Community.count_triangles(graph)
      1
  """
  @spec count_triangles(Yog.graph()) :: integer()
  def count_triangles(graph) do
    Metrics.count_triangles(graph)
  end

  @doc """
  Returns the number of triangles each node participates in.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Community.triangles_per_node(graph)
      %{1 => 1, 2 => 1, 3 => 1}
  """
  @spec triangles_per_node(Yog.graph()) :: %{Yog.node_id() => integer()}
  def triangles_per_node(graph) do
    Metrics.triangles_per_node(graph)
  end

  @doc """
  Calculates the local clustering coefficient for a node.

  Measures how close the node's neighbors are to forming a complete clique.

  Range: [0.0, 1.0]. 1.0 means all neighbors are connected to each other.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Community.clustering_coefficient(graph, 1)
      1.0
  """
  @spec clustering_coefficient(Yog.graph(), Yog.node_id()) :: float()
  def clustering_coefficient(graph, node) do
    Metrics.clustering_coefficient(graph, node)
  end

  @doc """
  Calculates the average clustering coefficient for the entire graph.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Community.average_clustering_coefficient(graph)
      1.0
  """
  @spec average_clustering_coefficient(Yog.graph()) :: float()
  def average_clustering_coefficient(graph) do
    Metrics.average_clustering_coefficient(graph)
  end

  @doc """
  Calculates the graph density.

  The ratio of actual edges to possible edges.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> d = Yog.Community.density(graph)
      iex> is_float(d)
      true
  """
  @spec density(Yog.graph()) :: float()
  def density(graph) do
    Metrics.density(graph)
  end

  @doc """
  Calculates the density of edges within a specific community.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> communities = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 0})
      iex> cd = Yog.Community.community_density(graph, communities, 0)
      iex> is_float(cd)
      true
  """
  @spec community_density(Yog.graph(), communities(), community_id()) :: float()
  def community_density(graph, %Result{} = communities, community_id) do
    nodes = nodes_in(communities, community_id)
    Metrics.community_density(graph, nodes)
  end

  @doc """
  Calculates the average density across all communities.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> communities = Yog.Community.Result.new(%{1 => 0, 2 => 0, 3 => 0})
      iex> avg_cd = Yog.Community.average_community_density(graph, communities)
      iex> is_float(avg_cd)
      true
  """
  @spec average_community_density(Yog.graph(), communities()) :: float()
  def average_community_density(graph, %Result{} = communities) do
    # YOG-FAC-004: Metrics module now supports Result struct natively
    Metrics.average_community_density(graph, communities)
  end
end
