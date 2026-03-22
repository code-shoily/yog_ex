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
    :yog@property@clique.max_clique(graph) |> :gleam@set.to_list() |> MapSet.new()
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
    :yog@property@clique.all_maximal_cliques(graph)
    |> Enum.map(fn cl -> cl |> :gleam@set.to_list() |> MapSet.new() end)
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
  def k_cliques(graph, k) do
    :yog@property@clique.k_cliques(graph, k)
    |> Enum.map(fn cl -> cl |> :gleam@set.to_list() |> MapSet.new() end)
  end
end

defmodule Yog.Clique do
  @moduledoc "Deprecated. Use `Yog.Property.Clique` instead."
  defdelegate max_clique(graph), to: Yog.Property.Clique
  defdelegate all_maximal_cliques(graph), to: Yog.Property.Clique
  defdelegate k_cliques(graph, k), to: Yog.Property.Clique
end
