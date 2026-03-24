defmodule Yog.Community.Metrics do
  @moduledoc """
  Community quality metrics and graph statistics.

  Provides functions for measuring:
  - Modularity (community structure quality)
  - Triangle counts and clustering coefficients
  - Graph and community density
  """

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
  def modularity(graph, communities) do
    # Modularity formula: Q = (1/2m) * Σ_ij [A_ij - (k_i * k_j / 2m)] * δ(c_i, c_j)
    # where m = number of edges, A = adjacency matrix, k = degree, c = community, δ = kronecker delta

    edge_count = Yog.Model.edge_count(graph)

    if edge_count == 0 do
      0.0
    else
      m = edge_count
      # 2m for undirected
      m2 = 2 * m

      nodes = Yog.all_nodes(graph)

      # Calculate weighted degrees (sum of edge weights)
      degrees =
        Map.new(nodes, fn node ->
          degree =
            Yog.Model.successors(graph, node)
            |> Enum.reduce(0, fn {_neighbor, weight}, acc -> acc + weight end)

          {node, degree}
        end)

      # Build edge lookup for O(1) edge existence checks
      edge_set = build_edge_set(graph)

      # Group nodes by community
      community_nodes =
        Enum.reduce(communities.assignments, %{}, fn {node, comm}, acc ->
          current = Map.get(acc, comm, [])
          Map.put(acc, comm, [node | current])
        end)

      # Calculate modularity by summing over all community pairs
      q =
        Enum.reduce(community_nodes, 0.0, fn {_, nodes_in_comm}, acc ->
          # For each pair of nodes in the same community
          pairs = for i <- nodes_in_comm, j <- nodes_in_comm, do: {i, j}

          sum_pairs =
            Enum.reduce(pairs, 0.0, fn {i, j}, sum ->
              a_ij = if edge_exists_fast?(edge_set, i, j), do: 1, else: 0
              k_i = degrees[i] || 0
              k_j = degrees[j] || 0
              expected = k_i * k_j / m2
              sum + (a_ij - expected)
            end)

          acc + sum_pairs
        end)

      q / m2
    end
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
    nodes = Yog.all_nodes(graph)

    triangles =
      for i <- nodes,
          j <- nodes,
          k <- nodes,
          i < j,
          j < k,
          edge_exists?(graph, i, j),
          edge_exists?(graph, j, k),
          edge_exists?(graph, i, k),
          do: 1

    length(triangles)
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
    nodes = Yog.all_nodes(graph)

    Map.new(nodes, fn node ->
      neighbors = Yog.Model.neighbor_ids(graph, node)

      count =
        for i <- neighbors,
            j <- neighbors,
            i < j,
            edge_exists?(graph, i, j),
            do: 1

      {node, length(count)}
    end)
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
    neighbors = Yog.Model.neighbor_ids(graph, node)
    k = length(neighbors)

    if k < 2 do
      0.0
    else
      # Count edges between neighbors
      neighbor_edges =
        for i <- neighbors,
            j <- neighbors,
            i < j,
            edge_exists?(graph, i, j),
            do: 1

      # C = 2 * E / (k * (k - 1)) for undirected
      2.0 * length(neighbor_edges) / (k * (k - 1))
    end
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
    nodes = Yog.all_nodes(graph)

    if nodes == [] do
      0.0
    else
      coefficients = Enum.map(nodes, fn node -> clustering_coefficient(graph, node) end)
      Enum.sum(coefficients) / length(coefficients)
    end
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
    n = Yog.Model.node_count(graph)
    m = Yog.Model.edge_count(graph)

    if n < 2 do
      0.0
    else
      # For undirected: D = 2m / (n * (n - 1))
      2.0 * m / (n * (n - 1))
    end
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
    n = length(node_list)

    if n < 2 do
      0.0
    else
      # Count edges within the community
      internal_edges =
        for i <- node_list,
            j <- node_list,
            i < j,
            edge_exists?(graph, i, j),
            do: 1

      m = length(internal_edges)

      # Density = 2m / (n * (n - 1))
      2.0 * m / (n * (n - 1))
    end
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
  def average_community_density(graph, communities) do
    # Calculate for each community and average
    # Convert assignments map to dictionary (community_id -> set of nodes)
    community_dict =
      Enum.reduce(communities.assignments, %{}, fn {node, community}, acc ->
        current_set = Map.get(acc, community, MapSet.new())
        Map.put(acc, community, MapSet.put(current_set, node))
      end)

    community_dict
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

  # Build a MapSet of all edges for O(1) lookup
  defp build_edge_set(graph) do
    nodes = Yog.all_nodes(graph)

    Enum.reduce(nodes, MapSet.new(), fn node, acc ->
      neighbors = Yog.Model.neighbor_ids(graph, node)

      Enum.reduce(neighbors, acc, fn neighbor, inner_acc ->
        # Store both directions for undirected graphs
        MapSet.put(inner_acc, {node, neighbor})
      end)
    end)
  end

  # Fast O(1) edge existence check using pre-built MapSet
  defp edge_exists_fast?(edge_set, i, j) do
    MapSet.member?(edge_set, {i, j})
  end

  # Original O(deg) edge check for functions that don't use pre-built set
  defp edge_exists?(graph, i, j) do
    neighbors = Yog.Model.neighbor_ids(graph, i)
    j in neighbors
  end
end
