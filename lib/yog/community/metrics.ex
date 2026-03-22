defmodule Yog.Community.Metrics do
  @moduledoc """
  Community quality metrics and graph statistics.

  Provides functions for measuring:
  - Modularity (community structure quality)
  - Triangle counts and clustering coefficients
  - Graph and community density
  """

  alias Yog.Community

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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> communities = %{assignments: %{1 => 0, 2 => 0}, num_communities: 1}
      iex> q = Yog.Community.Metrics.modularity(graph, communities)
      iex> is_float(q)
      true
  """
  @spec modularity(Yog.graph(), Community.communities()) :: float()
  def modularity(graph, communities) do
    :yog@community@metrics.modularity(graph, wrap_communities(communities))
  end

  @doc """
  Counts the total number of triangles in the graph.

  A triangle is a set of three nodes where each pair is connected.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex> Yog.Community.Metrics.count_triangles(graph)
      1
  """
  @spec count_triangles(Yog.graph()) :: integer()
  def count_triangles(graph) do
    :yog@community@metrics.count_triangles(graph)
  end

  @doc """
  Returns the number of triangles each node participates in.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex> Yog.Community.Metrics.triangles_per_node(graph)
      %{1 => 1, 2 => 1, 3 => 1}
  """
  @spec triangles_per_node(Yog.graph()) :: %{Yog.node_id() => integer()}
  def triangles_per_node(graph) do
    :yog@community@metrics.triangles_per_node(graph)
    |> :gleam@dict.to_list()
    |> Map.new()
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
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex> Yog.Community.Metrics.clustering_coefficient(graph, 1)
      1.0
  """
  @spec clustering_coefficient(Yog.graph(), Yog.node_id()) :: float()
  def clustering_coefficient(graph, node) do
    :yog@community@metrics.clustering_coefficient(graph, node)
  end

  @doc """
  Calculates the average clustering coefficient for the entire graph.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex> Yog.Community.Metrics.average_clustering_coefficient(graph)
      1.0
  """
  @spec average_clustering_coefficient(Yog.graph()) :: float()
  def average_clustering_coefficient(graph) do
    :yog@community@metrics.average_clustering_coefficient(graph)
  end

  @doc """
  Calculates the graph density.

  The ratio of actual edges to possible edges.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> d = Yog.Community.Metrics.density(graph)
      iex> is_float(d)
      true
  """
  @spec density(Yog.graph()) :: float()
  def density(graph) do
    :yog@community@metrics.density(graph)
  end

  @doc """
  Calculates the density of edges within a specific set of nodes.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> cd = Yog.Community.Metrics.community_density(graph, MapSet.new([1, 2]))
      iex> is_float(cd)
      true
  """
  @spec community_density(Yog.graph(), MapSet.t(Yog.node_id())) :: float()
  def community_density(graph, nodes) do
    node_list = MapSet.to_list(nodes)
    # Convert to Gleam set (internal representation is a sorted list)
    gleam_set = :gleam@set.from_list(node_list)
    :yog@community@metrics.community_density(graph, gleam_set)
  end

  @doc """
  Calculates the average density across all communities.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> communities = %{assignments: %{1 => 0, 2 => 0}, num_communities: 1}
      iex> avg_cd = Yog.Community.Metrics.average_community_density(graph, communities)
      iex> is_float(avg_cd)
      true
  """
  @spec average_community_density(Yog.graph(), Community.communities()) :: float()
  def average_community_density(graph, communities) do
    # Calculate for each community and average
    communities
    |> Community.to_dict()
    |> Enum.map(fn {_, nodes} -> community_density(graph, nodes) end)
    |> then(fn densities ->
      if densities == [] do
        0.0
      else
        Enum.sum(densities) / length(densities)
      end
    end)
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp wrap_communities(communities) do
    assignments =
      communities.assignments
      |> Map.to_list()
      |> :gleam@dict.from_list()

    {:communities, assignments, communities.num_communities}
  end
end
