defmodule Yog.Community.Metrics do
  @moduledoc """
  Community quality metrics and graph statistics.

  Provides functions for measuring:
  - Modularity (community structure quality)
  - Triangle counts and clustering coefficients
  - Graph and community density
  """

  alias Yog.Community.Result

  @spec modularity(Yog.Graph.t(), any(), any()) :: any()
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

  def modularity(graph, %Result{assignments: assignments}, opts) do
    modularity(graph, %{assignments: assignments}, opts)
  end

  def modularity(
        %Yog.Graph{out_edges: out_edges, in_edges: in_edges, kind: kind} = _graph,
        communities,
        opts
      ) do
    total_weight =
      List.foldl(Map.keys(out_edges), 0.0, fn node, acc ->
        edges = Map.get(out_edges, node, %{})
        acc + List.foldl(Map.to_list(edges), 0.0, fn {_, w}, sum -> sum + w end)
      end)

    if total_weight == 0.0 do
      0.0
    else
      m = if kind == :undirected, do: total_weight / 2.0, else: total_weight
      gamma = Keyword.get(opts, :resolution, 1.0)

      community_nodes = group_nodes_by_community(communities.assignments)

      List.foldl(Map.to_list(community_nodes), 0.0, fn {_, nodes_in_comm}, acc ->
        node_set = MapSet.new(nodes_in_comm)

        internal_edges =
          List.foldl(nodes_in_comm, 0.0, fn node, int_acc ->
            successors = get_successors(out_edges, node)

            internal =
              List.foldl(successors, 0.0, fn {neighbor, weight}, sum ->
                if MapSet.member?(node_set, neighbor), do: sum + weight, else: sum
              end)

            int_acc + internal
          end)

        term1 = if kind == :undirected, do: internal_edges / 2.0 / m, else: internal_edges / m

        term2 =
          if kind == :undirected do
            degree_sum =
              List.foldl(nodes_in_comm, 0.0, fn node, sum ->
                edges = Map.get(out_edges, node, %{})
                sum + List.foldl(Map.to_list(edges), 0.0, fn {_, w}, s -> s + w end)
              end)

            gamma * :math.pow(degree_sum / (2.0 * m), 2)
          else
            in_degree_sum =
              List.foldl(nodes_in_comm, 0.0, fn node, sum ->
                edges = Map.get(in_edges, node, %{})
                sum + List.foldl(Map.to_list(edges), 0.0, fn {_, w}, s -> s + w end)
              end)

            out_degree_sum =
              List.foldl(nodes_in_comm, 0.0, fn node, sum ->
                edges = Map.get(out_edges, node, %{})
                sum + List.foldl(Map.to_list(edges), 0.0, fn {_, w}, s -> s + w end)
              end)

            gamma * (in_degree_sum * out_degree_sum / (m * m))
          end

        acc + (term1 - term2)
      end)
    end
  end

  @doc """
  Counts the total number of triangles in the graph.

  A triangle is a set of three nodes where each pair is connected.
  Uses neighbor intersection algorithm: O(Σ deg(v)²).

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Community.Metrics.count_triangles(graph)
      1
  """
  @spec count_triangles(Yog.graph()) :: integer()
  def count_triangles(graph) do
    neighbor_sets = get_neighbor_sets(graph)
    node_list = Map.keys(graph.nodes)

    List.foldl(node_list, 0, fn u, acc ->
      u_neighbors = Map.get(neighbor_sets, u)

      u_neighbors
      |> Enum.filter(&(&1 > u))
      |> Enum.reduce(acc, fn v, inner_acc ->
        v_neighbors = Map.get(neighbor_sets, v)

        common =
          MapSet.intersection(u_neighbors, v_neighbors)
          |> Enum.count(&(&1 > v))

        inner_acc + common
      end)
    end)
  end

  @doc """
  Returns the number of triangles each node participates in.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Community.Metrics.triangles_per_node(graph)
      %{1 => 1, 2 => 1, 3 => 1}
  """
  @spec triangles_per_node(Yog.graph()) :: %{Yog.node_id() => integer()}
  def triangles_per_node(graph) do
    neighbor_sets = get_neighbor_sets(graph)
    node_list = Map.keys(graph.nodes)

    List.foldl(node_list, %{}, fn node, acc ->
      neighbors = Map.get(neighbor_sets, node)
      neighbor_list = MapSet.to_list(neighbors)

      count =
        List.foldl(neighbor_list, 0, fn i, c1 ->
          i_neighbors = Map.get(neighbor_sets, i)

          neighbor_list
          |> Enum.filter(&(&1 > i))
          |> Enum.count(&MapSet.member?(i_neighbors, &1))
          |> Kernel.+(c1)
        end)

      Map.put(acc, node, count)
    end)
  end

  @doc """
  Calculates the local clustering coefficient for a node.

  Measures how close the node's neighbors are to forming a complete clique.
  Range: [0.0, 1.0].

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Community.Metrics.clustering_coefficient(graph, 1)
      1.0
  """
  @spec clustering_coefficient(Yog.graph(), Yog.node_id()) :: float()
  def clustering_coefficient(%Yog.Graph{out_edges: out_edges} = _graph, node) do
    neighbors = Map.keys(get_successors_map(out_edges, node))
    k = length(neighbors)

    if k < 2 do
      0.0
    else
      neighbor_set = MapSet.new(neighbors)

      neighbor_edges =
        List.foldl(neighbors, 0, fn i, acc ->
          i_neighbors = Map.keys(get_successors_map(out_edges, i))
          count = Enum.count(i_neighbors, fn j -> j > i and MapSet.member?(neighbor_set, j) end)
          acc + count
        end)

      2.0 * neighbor_edges / (k * (k - 1))
    end
  end

  @doc """
  Calculates the average clustering coefficient for the entire graph.
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
  Calculates the transitivity (global clustering coefficient) of the graph.

  Formula: T = 3 × number_of_triangles / number_of_connected_triples
  """
  @spec transitivity(Yog.graph()) :: float()
  def transitivity(%Yog.Graph{out_edges: out_edges, nodes: nodes}) do
    node_list = Map.keys(nodes)

    {total_triples, total_triangles} =
      List.foldl(node_list, {0, 0}, fn node, {triples_acc, triangles_acc} ->
        neighbors = Map.keys(get_successors_map(out_edges, node))
        k = length(neighbors)
        node_triples = div(k * (k - 1), 2)

        neighbor_set = MapSet.new(neighbors)

        node_triangles =
          neighbors
          |> Enum.filter(&(&1 > node))
          |> Enum.reduce(0, fn v, acc ->
            v_neighbors = Map.keys(get_successors_map(out_edges, v))
            count = Enum.count(v_neighbors, fn w -> w > v and MapSet.member?(neighbor_set, w) end)
            acc + count
          end)

        {triples_acc + node_triples, triangles_acc + node_triangles}
      end)

    if total_triples == 0, do: 0.0, else: 3.0 * total_triangles / total_triples
  end

  @doc """
  Calculates the graph density.
  """
  @spec density(Yog.graph()) :: float()
  def density(%Yog.Graph{nodes: nodes} = graph) do
    n = map_size(nodes)
    m = Yog.Graph.edge_count(graph)

    if n < 2, do: 0.0, else: 2.0 * m / (n * (n - 1))
  end

  @doc """
  Calculates the density of edges within a specific set of nodes.
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
          successors = Map.keys(get_successors_map(out_edges, i))
          count = Enum.count(successors, fn j -> j > i and MapSet.member?(nodes, j) end)
          acc + count
        end)

      2.0 * internal_edges / (n * (n - 1))
    end
  end

  @doc """
  Calculates the average density across all communities.
  """
  def average_community_density(graph, %Result{assignments: assignments}) do
    average_community_density(graph, %{assignments: assignments})
  end

  def average_community_density(graph, %{assignments: assignments}) do
    assignments
    |> group_nodes_by_community()
    |> Enum.map(fn {_, nodes} -> community_density(graph, MapSet.new(nodes)) end)
    |> then(fn densities ->
      if densities == [], do: 0.0, else: Enum.sum(densities) / length(densities)
    end)
  end

  # ============= Private Helpers =============

  defp get_neighbor_sets(%Yog.Graph{out_edges: out_edges, nodes: nodes}) do
    Map.new(nodes, fn {node, _} ->
      {node, MapSet.new(Map.keys(get_successors_map(out_edges, node)))}
    end)
  end

  defp group_nodes_by_community(assignments) do
    List.foldl(Map.to_list(assignments), %{}, fn {node, comm}, acc ->
      Map.update(acc, comm, [node], &[node | &1])
    end)
  end

  defp get_successors(out_edges, node) do
    Map.get(out_edges, node, %{}) |> Map.to_list()
  end

  defp get_successors_map(out_edges, node) do
    Map.get(out_edges, node, %{})
  end
end
