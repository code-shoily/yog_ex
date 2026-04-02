defmodule Yog.Community.Metrics do
  @moduledoc """
  Community quality metrics and graph statistics.

  Provides functions for measuring:
  - Modularity (community structure quality)
  - Triangle counts and clustering coefficients
  - Graph and community density
  """

  use Yog.Algorithm

  alias Yog.Community.Result

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
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> communities = %{assignments: %{1 => 0, 2 => 0}, num_communities: 1}
      iex> q = Yog.Community.Metrics.modularity(graph, communities)
      iex> is_float(q)
      true
  """

  def modularity(graph, communities, opts \\ [])

  def modularity(graph, %Result{} = communities, opts) do
    modularity(graph, %{assignments: communities.assignments}, opts)
  end

  def modularity(graph, communities, opts) do
    # Formula: Q = Σ_c [ (L_c/m) - γ*(k_c/2m)² ]
    # where L_c = internal edges in community c, k_c = sum of degrees in c

    edge_count = Model.edge_count(graph)

    if edge_count == 0 do
      0.0
    else
      m = edge_count / 1.0
      m2 = 2 * m
      gamma = Keyword.get(opts, :resolution, 1.0)

      # Build community -> nodes mapping
      community_nodes =
        Enum.reduce(communities.assignments, %{}, fn {node, comm}, acc ->
          Map.update(acc, comm, [node], &[node | &1])
        end)

      # Calculate modularity using O(E) approach
      Enum.reduce(community_nodes, 0.0, fn {_, nodes_in_comm}, acc ->
        # Convert to MapSet for O(1) membership tests
        node_set = MapSet.new(nodes_in_comm)

        # Count internal edges and sum degrees
        {internal_edges, degree_sum} =
          Enum.reduce(nodes_in_comm, {0, 0}, fn node, {int_acc, deg_acc} ->
            successors = Model.successors(graph, node)
            degree = Enum.reduce(successors, 0, fn {_, w}, sum -> sum + w end)

            # Count internal edges (weighted)
            internal =
              Enum.reduce(successors, 0, fn {neighbor, weight}, sum ->
                if MapSet.member?(node_set, neighbor) do
                  sum + weight
                else
                  sum
                end
              end)

            {int_acc + internal, deg_acc + degree}
          end)

        # Internal edges counted twice (once per endpoint)
        internal_edges = internal_edges / 2.0

        # Add contribution: (L_c/m) - γ*(k_c/2m)²
        term1 = internal_edges / m
        term2 = gamma * :math.pow(degree_sum / m2, 2)
        acc + (term1 - term2)
      end)
    end
  end

  @doc """
  Counts the total number of triangles in the graph.

  A triangle is a set of three nodes where each pair is connected.

  Uses neighbor intersection algorithm: O(Σ deg(v)²) instead of O(V³).

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Community.Metrics.count_triangles(graph)
      1
  """
  @spec count_triangles(Yog.graph()) :: integer()
  def count_triangles(graph) do
    # For each edge (u,v), count |N(u) ∩ N(v)|
    # Each triangle counted 3 times (once per edge), so divide by 3

    nodes = Model.all_nodes(graph)

    # Pre-compute neighbor MapSets for O(1) intersection
    neighbor_sets =
      Map.new(nodes, fn node ->
        neighbors =
          Model.successors(graph, node)
          |> Enum.map(fn {n, _} -> n end)
          |> MapSet.new()

        {node, neighbors}
      end)

    # Count triangles via neighbor intersection
    triangles =
      Enum.reduce(nodes, 0, fn u, acc ->
        u_neighbors = Map.get(neighbor_sets, u)

        # Only consider neighbors v > u to avoid double counting
        u_neighbors
        |> Enum.filter(&(&1 > u))
        |> Enum.reduce(acc, fn v, inner_acc ->
          v_neighbors = Map.get(neighbor_sets, v)

          # Count common neighbors w > v to ensure each triangle counted once
          common =
            v_neighbors
            |> Enum.filter(fn w ->
              w > v and MapSet.member?(u_neighbors, w)
            end)
            |> length()

          inner_acc + common
        end)
      end)

    triangles
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
      iex> Yog.Community.Metrics.triangles_per_node(graph)
      %{1 => 1, 2 => 1, 3 => 1}
  """
  @spec triangles_per_node(Yog.graph()) :: %{Yog.node_id() => integer()}
  def triangles_per_node(graph) do
    nodes = Model.all_nodes(graph)

    # Pre-compute ordered neighbor lists
    neighbor_sets =
      Map.new(nodes, fn node ->
        neighbors =
          Model.successors(graph, node)
          |> Enum.map(fn {n, _} -> n end)
          |> MapSet.new()

        {node, neighbors}
      end)

    # Count triangles per node
    Enum.reduce(nodes, %{}, fn node, acc ->
      neighbors = Map.get(neighbor_sets, node)
      neighbor_list = MapSet.to_list(neighbors)

      # Count pairs of neighbors that are connected
      count =
        neighbor_list
        |> Enum.reduce(0, fn i, c1 ->
          i_neighbors = Map.get(neighbor_sets, i)

          neighbor_list
          |> Enum.filter(&(&1 > i))
          |> Enum.count(fn j ->
            MapSet.member?(i_neighbors, j)
          end)
          |> Kernel.+(c1)
        end)

      Map.put(acc, node, count)
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
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Community.Metrics.clustering_coefficient(graph, 1)
      1.0
  """
  @spec clustering_coefficient(Yog.graph(), Yog.node_id()) :: float()
  def clustering_coefficient(graph, node) do
    neighbors = Model.neighbor_ids(graph, node)
    k = length(neighbors)

    if k < 2 do
      0.0
    else
      neighbor_set = MapSet.new(neighbors)

      neighbor_edges =
        Enum.reduce(neighbors, 0, fn i, acc ->
          # Count neighbors j > i to avoid double counting
          i_neighbors = Model.neighbor_ids(graph, i)

          count =
            Enum.count(i_neighbors, fn j ->
              j > i and MapSet.member?(neighbor_set, j)
            end)

          acc + count
        end)

      # C = 2 * E / (k * (k - 1)) for undirected
      2.0 * neighbor_edges / (k * (k - 1))
    end
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
      iex> Yog.Community.Metrics.average_clustering_coefficient(graph)
      1.0
  """
  @spec average_clustering_coefficient(Yog.graph()) :: float()
  def average_clustering_coefficient(graph) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      0.0
    else
      total = Enum.sum(Enum.map(nodes, fn node -> clustering_coefficient(graph, node) end))
      total / length(nodes)
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
      iex> d = Yog.Community.Metrics.density(graph)
      iex> is_float(d)
      true
  """
  @spec density(Yog.graph()) :: float()
  def density(graph) do
    n = Model.node_count(graph)
    m = Model.edge_count(graph)

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
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
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
      node_set = nodes

      internal_edges =
        Enum.reduce(node_list, 0, fn i, acc ->
          successors = Model.successors(graph, i)

          count =
            Enum.count(successors, fn {j, _} ->
              j > i and MapSet.member?(node_set, j)
            end)

          acc + count
        end)

      # Density = 2m / (n * (n - 1))
      2.0 * internal_edges / (n * (n - 1))
    end
  end

  @doc """
  Calculates the average density across all communities.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> communities = %{assignments: %{1 => 0, 2 => 0}, num_communities: 1}
      iex> avg_cd = Yog.Community.Metrics.average_community_density(graph, communities)
      iex> is_float(avg_cd)
      true
  """
  def average_community_density(graph, %Result{} = communities) do
    average_community_density(graph, %{assignments: communities.assignments})
  end

  def average_community_density(graph, %{assignments: _} = communities) do
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
end
