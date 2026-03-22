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

  ## Example

      # Detect communities using Louvain
      communities = Yog.Community.Louvain.detect(graph)
      communities.num_communities  # => 4

      # Get nodes in each community
      communities_dict = Yog.Community.to_dict(communities)
      # => %{0 => MapSet.new([1, 2, 3]), 1 => MapSet.new([4, 5])}

      # Find largest community
      case Yog.Community.largest(communities) do
        {:some, community_id} -> community_id
        :none -> nil
      end

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

  alias Yog.Community.Metrics

  @typedoc "Community identifier"
  @type community_id :: integer()

  @typedoc "Community assignment for nodes"
  @type communities :: %{
          assignments: %{Yog.node_id() => community_id()},
          num_communities: integer()
        }

  @typedoc "Hierarchical community structure"
  @type dendrogram :: %{
          levels: [communities()],
          merge_order: [{community_id(), community_id()}]
        }

  @typedoc "Overlapping communities (nodes can belong to multiple)"
  @type overlapping_communities :: %{
          memberships: %{Yog.node_id() => [community_id()]},
          num_communities: integer()
        }

  # ============================================================
  # Utility Functions
  # ============================================================

  @doc """
  Converts community assignments to a dictionary mapping community IDs to sets of node IDs.

  This is useful when you need to iterate over all nodes in each community
  rather than looking up the community for each node.

  ## Example

      communities = %{
        assignments: %{1 => 0, 2 => 0, 3 => 1},
        num_communities: 2
      }

      Yog.Community.to_dict(communities)
      # => %{0 => MapSet.new([1, 2]), 1 => MapSet.new([3])}
  """
  @spec to_dict(communities()) :: %{community_id() => MapSet.t(Yog.node_id())}
  def to_dict(communities) do
    Enum.reduce(communities.assignments, %{}, fn {node, community}, acc ->
      current_set = Map.get(acc, community, MapSet.new())
      Map.put(acc, community, MapSet.put(current_set, node))
    end)
  end

  @doc """
  Returns the community ID with the largest number of nodes.

  Returns `:none` if there are no communities (empty graph or no assignments).

  ## Example

      communities = %{
        assignments: %{1 => 0, 2 => 0, 3 => 0, 4 => 1},
        num_communities: 2
      }

      Yog.Community.largest(communities)
      # => {:some, 0}  # Community 0 has 3 nodes vs 1 for community 1
  """
  @spec largest(communities()) :: {:some, community_id()} | :none
  def largest(communities) do
    communities
    |> sizes()
    |> Enum.to_list()
    |> Enum.sort_by(fn {_, size} -> size end, :desc)
    |> List.first()
    |> case do
      nil -> :none
      {community_id, _} -> {:some, community_id}
    end
  end

  @doc """
  Returns a dictionary mapping community IDs to their sizes (number of nodes).

  ## Example

      communities = %{
        assignments: %{1 => 0, 2 => 0, 3 => 1, 4 => 1, 5 => 1},
        num_communities: 2
      }

      Yog.Community.sizes(communities)
      # => %{0 => 2, 1 => 3}
  """
  @spec sizes(communities()) :: %{community_id() => integer()}
  def sizes(communities) do
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

    * `communities` - The current community partition
    * `source` - The community ID to merge from (will be removed)
    * `target` - The community ID to merge into (will be kept)

  ## Example

      communities = %{
        assignments: %{1 => 0, 2 => 0, 3 => 1, 4 => 1},
        num_communities: 2
      }

      # Merge community 1 into community 0
      merged = Yog.Community.merge(communities, source: 1, target: 0)
      # merged.assignments => %{1 => 0, 2 => 0, 3 => 0, 4 => 0}
      # merged.num_communities => 1
  """
  @spec merge(communities(), source: community_id(), target: community_id()) ::
          communities()
  def merge(communities, source: source, target: target) do
    new_assignments =
      Enum.reduce(communities.assignments, communities.assignments, fn
        {node, ^source}, acc ->
          Map.put(acc, node, target)

        _, acc ->
          acc
      end)

    num_communities =
      if source == target do
        communities.num_communities
      else
        communities.num_communities - 1
      end

    %{
      assignments: new_assignments,
      num_communities: num_communities
    }
  end

  @doc """
  Returns all nodes belonging to a specific community.

  ## Example

      nodes = Yog.Community.nodes_in(communities, 0)
      # => MapSet.new([1, 2, 3])
  """
  @spec nodes_in(communities(), community_id()) :: MapSet.t(Yog.node_id())
  def nodes_in(communities, community_id) do
    communities.assignments
    |> Enum.filter(fn {_, c} -> c == community_id end)
    |> Enum.map(fn {node, _} -> node end)
    |> MapSet.new()
  end

  @doc """
  Returns the community ID for a specific node.

  Returns `:none` if the node is not assigned to any community.

  ## Example

      Yog.Community.for_node(communities, 1)
      # => {:some, 0}
  """
  @spec for_node(communities(), Yog.node_id()) :: {:some, community_id()} | :none
  def for_node(communities, node) do
    case Map.fetch(communities.assignments, node) do
      {:ok, community} -> {:some, community}
      :error -> :none
    end
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

  ## Example

      q = Yog.Community.modularity(graph, communities)
      # => 0.42
  """
  @spec modularity(Yog.graph(), communities()) :: float()
  def modularity(graph, communities) do
    Metrics.modularity(graph, communities)
  end

  @doc """
  Counts the total number of triangles in the graph.

  A triangle is a set of three nodes where each pair is connected.

  ## Example

      triangles = Yog.Community.count_triangles(graph)
      # => 15
  """
  @spec count_triangles(Yog.graph()) :: integer()
  def count_triangles(graph) do
    Metrics.count_triangles(graph)
  end

  @doc """
  Returns the number of triangles each node participates in.

  ## Example

      per_node = Yog.Community.triangles_per_node(graph)
      # => %{1 => 2, 2 => 3, 3 => 1}
  """
  @spec triangles_per_node(Yog.graph()) :: %{Yog.node_id() => integer()}
  def triangles_per_node(graph) do
    Metrics.triangles_per_node(graph)
  end

  @doc """
  Calculates the local clustering coefficient for a node.

  Measures how close the node's neighbors are to forming a complete clique.

  Range: [0.0, 1.0]. 1.0 means all neighbors are connected to each other.

  ## Example

      cc = Yog.Community.clustering_coefficient(graph, :a)
      # => 0.67
  """
  @spec clustering_coefficient(Yog.graph(), Yog.node_id()) :: float()
  def clustering_coefficient(graph, node) do
    Metrics.clustering_coefficient(graph, node)
  end

  @doc """
  Calculates the average clustering coefficient for the entire graph.

  ## Example

      avg_cc = Yog.Community.average_clustering_coefficient(graph)
      # => 0.45
  """
  @spec average_clustering_coefficient(Yog.graph()) :: float()
  def average_clustering_coefficient(graph) do
    Metrics.average_clustering_coefficient(graph)
  end

  @doc """
  Calculates the graph density.

  The ratio of actual edges to possible edges.

  ## Example

      d = Yog.Community.density(graph)
      # => 0.3
  """
  @spec density(Yog.graph()) :: float()
  def density(graph) do
    Metrics.density(graph)
  end

  @doc """
  Calculates the density of edges within a specific community.

  ## Example

      cd = Yog.Community.community_density(graph, communities, 0)
      # => 0.5
  """
  @spec community_density(Yog.graph(), communities(), community_id()) :: float()
  def community_density(graph, communities, community_id) do
    nodes = nodes_in(communities, community_id)
    Metrics.community_density(graph, nodes)
  end

  @doc """
  Calculates the average density across all communities.

  ## Example

      avg_cd = Yog.Community.average_community_density(graph, communities)
      # => 0.42
  """
  @spec average_community_density(Yog.graph(), communities()) :: float()
  def average_community_density(graph, communities) do
    Metrics.average_community_density(graph, communities)
  end
end
