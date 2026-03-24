defmodule Yog.Property.Clique do
  @moduledoc """
  [Clique](https://en.wikipedia.org/wiki/Clique_(graph_theory)) finding algorithms using the
  [Bron-Kerbosch algorithm](https://en.wikipedia.org/wiki/Bron%E2%80%93Kerbosch_algorithm).

  A clique is a subset of nodes where every pair of nodes is connected by an edge.
  Cliques represent tightly-knit communities or fully-connected subgraphs.

  ## Algorithms

  | Problem | Algorithm | Function | Complexity |
  |---------|-----------|----------|------------|
  | Maximum clique | [Bron-Kerbosch with pivot](https://en.wikipedia.org/wiki/Bron%E2%80%93Kerbosch_algorithm#With_pivoting) | `max_clique/1` | O(3^(n/3)) |
  | All maximal cliques | [Bron-Kerbosch](https://en.wikipedia.org/wiki/Bron%E2%80%93Kerbosch_algorithm) | `all_maximal_cliques/1` | O(3^(n/3)) |
  | k-Cliques | Bron-Kerbosch with pruning | `k_cliques/2` | O(3^(n/3)) |

  ## Key Concepts

  - **Clique**: Complete subgraph - every pair of vertices is adjacent
  - **Maximal Clique**: Cannot be extended by adding another vertex
  - **Maximum Clique**: Largest clique in the graph (NP-hard to find)
  - **Clique Number**: Size of the maximum clique, denoted ω(G)
  - **Clique Cover**: Partition of vertices into cliques

  ## The Bron-Kerbosch Algorithm

  A backtracking algorithm that recursively explores potential cliques using
  three sets:
  - **R**: Current clique being built
  - **P**: Candidates that can extend R (connected to all in R)
  - **X**: Excluded vertices (already processed)

  **Pivoting optimization**: Choose a pivot vertex to reduce recursive calls,
  achieving the worst-case optimal O(3^(n/3)) bound.

  ## Complexity Notes

  Finding the maximum clique is NP-hard. The O(3^(n/3)) bound is tight - there
  exist graphs with exactly 3^(n/3) maximal cliques (Moon-Moser graphs).

  ## Related Problems

  - **Independent Set**: Clique in the complement graph
  - **Vertex Cover**: Related via complement to independent set
  - **Graph Coloring**: Lower bounded by clique number

  ## Use Cases

  - **Social network analysis**: Finding tightly-knit friend groups
  - **Bioinformatics**: Protein interaction clusters
  - **Finance**: Detecting collusion rings in trading
  - **Recommendation**: Finding groups with similar preferences
  - **Compiler optimization**: Register allocation (interference graphs)

  ## Examples

      # Create a complete graph K4
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 4, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 4, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      iex> Yog.Property.Clique.max_clique(graph) |> MapSet.size()
      4

  ## References

  - [Wikipedia: Clique](https://en.wikipedia.org/wiki/Clique_(graph_theory))
  - [Wikipedia: Bron-Kerbosch Algorithm](https://en.wikipedia.org/wiki/Bron%E2%80%93Kerbosch_algorithm)
  - [Moon-Moser Theorem (Clique Enumeration)](https://en.wikipedia.org/wiki/Moon%E2%80%93Moser_theorem)
  - [CP-Algorithms: Finding Cliques](https://cp-algorithms.com/graph/search_for_connected_components.html)
  """

  alias Yog.Model

  @doc """
  Finds the maximum clique in an undirected graph.

  Returns the largest subset of nodes where every pair is connected.

  ## Examples

      # Triangle (3-clique)
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex> Yog.Property.Clique.max_clique(graph) |> MapSet.size()
      3

      # Path graph (no cliques larger than 2)
      iex> path = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> Yog.Property.Clique.max_clique(path) |> MapSet.size()
      2

      # Empty graph
      iex> empty = Yog.undirected()
      iex> Yog.Property.Clique.max_clique(empty) |> MapSet.size()
      0

  ## Time Complexity

  O(3^(n/3)) worst case
  """
  @spec max_clique(Yog.graph()) :: MapSet.t(Yog.node_id())
  def max_clique(graph) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      MapSet.new()
    else
      all_cliques = all_maximal_cliques(graph)

      if all_cliques == [] do
        MapSet.new()
      else
        Enum.max_by(all_cliques, &MapSet.size/1)
      end
    end
  end

  @doc """
  Finds all maximal cliques in an undirected graph.

  A maximal clique is a clique that cannot be extended by adding another node.

  ## Examples

      # Triangle has one maximal clique
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 1, with: 1)
      iex> Yog.Property.Clique.all_maximal_cliques(graph) |> length()
      1

      # Path graph: each edge is a maximal clique of size 2
      iex> path = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> Yog.Property.Clique.all_maximal_cliques(path) |> length()
      2
      iex> # Empty graph has no cliques
      iex> empty = Yog.undirected()
      iex> Yog.Property.Clique.all_maximal_cliques(empty)
      []

  ## Time Complexity

  O(3^(n/3)) worst case
  """
  @spec all_maximal_cliques(Yog.graph()) :: [MapSet.t(Yog.node_id())]
  def all_maximal_cliques(graph) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      []
    else
      # Build adjacency map for fast lookup
      adj =
        Map.new(nodes, fn u ->
          neighbors = Model.neighbor_ids(graph, u) |> MapSet.new()
          {u, neighbors}
        end)

      # Bron-Kerbosch with pivot
      p = MapSet.new(nodes)
      r = MapSet.new()
      x = MapSet.new()

      bron_kerbosch_pivot(r, p, x, adj, [])
    end
  end

  # Bron-Kerbosch with pivot optimization
  # R = current clique, P = candidates, X = excluded
  # When P and X are empty, R is a maximal clique
  defp bron_kerbosch_pivot(r, p, x, _adj, acc)
       when map_size(p) == 0 and map_size(x) == 0 do
    if MapSet.size(r) > 0 do
      [r | acc]
    else
      acc
    end
  end

  defp bron_kerbosch_pivot(_r, p, _x, _adj, acc) when map_size(p) == 0 do
    # P empty but X not empty - no maximal clique here
    acc
  end

  defp bron_kerbosch_pivot(r, p, x, adj, acc) do
    # Choose pivot from P union X with maximum degree to P
    pivot = choose_pivot(p, x, adj)

    # Get candidates: P \ N(pivot)
    pivot_neighbors = Map.get(adj, pivot, MapSet.new())
    candidates = MapSet.difference(p, pivot_neighbors)

    if MapSet.size(candidates) == 0 do
      # No candidates to process - check if R is maximal
      if MapSet.size(p) == 0 and MapSet.size(x) == 0 and MapSet.size(r) > 0 do
        [r | acc]
      else
        acc
      end
    else
      Enum.reduce(MapSet.to_list(candidates), {p, x, acc}, fn v, {p_acc, x_acc, acc_cliques} ->
        v_neighbors = Map.get(adj, v, MapSet.new())

        new_r = MapSet.put(r, v)
        new_p = MapSet.intersection(p_acc, v_neighbors)
        new_x = MapSet.intersection(x_acc, v_neighbors)

        new_cliques = bron_kerbosch_pivot(new_r, new_p, new_x, adj, acc_cliques)

        new_p_acc = MapSet.delete(p_acc, v)
        new_x_acc = MapSet.put(x_acc, v)

        {new_p_acc, new_x_acc, new_cliques}
      end)
      |> elem(2)
    end
  end

  # Choose pivot with maximum degree to P
  defp choose_pivot(p, x, adj) do
    candidates = MapSet.union(p, x)

    if MapSet.size(candidates) == 0 do
      nil
    else
      candidates
      |> MapSet.to_list()
      |> Enum.max_by(fn u ->
        neighbors = Map.get(adj, u, MapSet.new())
        MapSet.intersection(neighbors, p) |> MapSet.size()
      end)
    end
  end

  @doc """
  Finds all cliques of exactly size k in an undirected graph.

  Uses a modified Bron-Kerbosch algorithm with early pruning.

  ## Examples

      # Complete graph K4 has 4 cliques of size 3 (triangles)
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 4, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 4, with: 1)
      ...> |> Yog.add_edge!(from: 3, to: 4, with: 1)
      iex> Yog.Property.Clique.k_cliques(graph, 3) |> length()
      4
      iex> # Find edges (cliques of size 2)
      iex> Yog.Property.Clique.k_cliques(graph, 2) |> length()
      6
      iex> # k <= 0 returns empty list
      iex> Yog.Property.Clique.k_cliques(graph, 0)
      []

  ## Time Complexity

  O(3^(n/3)) worst case
  """
  @spec k_cliques(Yog.graph(), integer()) :: [MapSet.t(Yog.node_id())]
  def k_cliques(_graph, k) when k <= 0, do: []

  def k_cliques(graph, k) do
    all_cliques = all_maximal_cliques(graph)

    # Generate all k-cliques from maximal cliques
    all_cliques
    |> Enum.flat_map(fn clique ->
      size = MapSet.size(clique)

      if size >= k do
        clique
        |> MapSet.to_list()
        |> combinations(k)
        |> Enum.map(&MapSet.new/1)
      else
        []
      end
    end)
    |> Enum.uniq()
  end

  # Generate all k-combinations from a list
  defp combinations(_list, 0), do: [[]]
  defp combinations([], _k), do: []

  defp combinations([h | t], k) do
    with_h = for(l <- combinations(t, k - 1), do: [h | l])
    without_h = combinations(t, k)
    with_h ++ without_h
  end
end

defmodule Yog.Clique do
  @moduledoc "Deprecated. Use `Yog.Property.Clique` instead."
  defdelegate max_clique(graph), to: Yog.Property.Clique
  defdelegate all_maximal_cliques(graph), to: Yog.Property.Clique
  defdelegate k_cliques(graph, k), to: Yog.Property.Clique
end
