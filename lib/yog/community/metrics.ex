defmodule Yog.Community.Metrics do
  @moduledoc """
  Community quality metrics and graph statistics.

  Provides functions for measuring:
  - Modularity (community structure quality)
  - Triangle counts and clustering coefficients
  - Graph and community density
  """

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

  def modularity(%Yog.Graph{out_edges: out_edges} = graph, communities, opts) do
    # Formula: Q = Σ_c [ (L_c/m) - γ*(k_c/2m)² ]
    # where L_c = internal edges in community c, k_c = sum of degrees in c

    edge_count = Yog.Graph.edge_count(graph)

    if edge_count == 0 do
      0.0
    else
      m = edge_count / 1.0
      m2 = 2 * m
      gamma = Keyword.get(opts, :resolution, 1.0)

      community_nodes =
        :maps.fold(
          fn node, comm, acc ->
            Map.update(acc, comm, [node], &[node | &1])
          end,
          %{},
          communities.assignments
        )

      :maps.fold(
        fn _, nodes_in_comm, acc ->
          node_set = MapSet.new(nodes_in_comm)

          {internal_edges, degree_sum} =
            List.foldl(nodes_in_comm, {0, 0}, fn node, {int_acc, deg_acc} ->
              # Optimization: Check directly for edge existence
              case Map.fetch(out_edges, node) do
                {:ok, edges} ->
                  {internal, degree} =
                    :maps.fold(
                      fn neighbor, weight, {int, deg} ->
                        new_int =
                          if MapSet.member?(node_set, neighbor), do: int + weight, else: int

                        {new_int, deg + weight}
                      end,
                      {0, 0},
                      edges
                    )

                  {int_acc + internal, deg_acc + degree}

                :error ->
                  {int_acc, deg_acc}
              end
            end)

          internal_edges = internal_edges / 2.0

          term1 = internal_edges / m
          term2 = gamma * :math.pow(degree_sum / m2, 2)
          acc + (term1 - term2)
        end,
        0.0,
        community_nodes
      )
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
  def count_triangles(%Yog.Graph{out_edges: out_edges, nodes: nodes}) do
    node_list = Map.keys(nodes)

    neighbor_sets =
      Map.new(node_list, fn node ->
        neighbors =
          case Map.fetch(out_edges, node) do
            {:ok, edges} -> Map.keys(edges)
            :error -> []
          end
          |> MapSet.new()

        {node, neighbors}
      end)

    triangles =
      List.foldl(node_list, 0, fn u, acc ->
        u_neighbors = Map.get(neighbor_sets, u)

        u_neighbors
        |> Enum.filter(&(&1 > u))
        |> Enum.reduce(acc, fn v, inner_acc ->
          v_neighbors = Map.get(neighbor_sets, v)

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
  def triangles_per_node(%Yog.Graph{out_edges: out_edges, nodes: nodes}) do
    node_list = Map.keys(nodes)

    neighbor_sets =
      Map.new(node_list, fn node ->
        neighbors =
          case Map.fetch(out_edges, node) do
            {:ok, edges} -> Map.keys(edges)
            :error -> []
          end
          |> MapSet.new()

        {node, neighbors}
      end)

    List.foldl(node_list, %{}, fn node, acc ->
      neighbors = Map.get(neighbor_sets, node)
      neighbor_list = MapSet.to_list(neighbors)

      count =
        neighbor_list
        |> List.foldl(0, fn i, c1 ->
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
  def clustering_coefficient(%Yog.Graph{out_edges: out_edges}, node) do
    neighbors =
      case Map.fetch(out_edges, node) do
        {:ok, edges} -> Map.keys(edges)
        :error -> []
      end

    k = length(neighbors)

    if k < 2 do
      0.0
    else
      neighbor_set = MapSet.new(neighbors)

      neighbor_edges =
        List.foldl(neighbors, 0, fn i, acc ->
          i_neighbors =
            case Map.fetch(out_edges, i) do
              {:ok, edges} -> Map.keys(edges)
              :error -> []
            end

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
  def average_clustering_coefficient(%Yog.Graph{nodes: nodes} = graph) do
    node_list = Map.keys(nodes)

    if node_list == [] do
      0.0
    else
      total = Enum.sum(Enum.map(node_list, fn node -> clustering_coefficient(graph, node) end))
      total / length(node_list)
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
  def density(%Yog.Graph{nodes: nodes} = graph) do
    n = map_size(nodes)
    m = Yog.Graph.edge_count(graph)

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
  def community_density(%Yog.Graph{out_edges: out_edges}, nodes) do
    node_list = MapSet.to_list(nodes)
    n = length(node_list)

    if n < 2 do
      0.0
    else
      internal_edges =
        List.foldl(node_list, 0, fn i, acc ->
          successors =
            case Map.fetch(out_edges, i) do
              {:ok, edges} -> Map.to_list(edges)
              :error -> []
            end

          count =
            Enum.count(successors, fn {j, _} ->
              j > i and MapSet.member?(nodes, j)
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
    community_dict =
      List.foldl(Map.to_list(communities.assignments), %{}, fn {node, community}, acc ->
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
