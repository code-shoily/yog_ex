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

  ## Maximum Clique Visualization

  A clique is a fully connected subgraph where every node is adjacent to every other node in the set.

  <div class="graphviz">
  graph G {
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];

    subgraph cluster_clique {
      label="Maximum Clique (K4)"; color="#6366f1"; style=rounded;
      C1; C2; C3; C4;
    }

    // Clique edges (fully connected)
    C1 -- C2 [color="#6366f1", penwidth=2.5];
    C1 -- C3 [color="#6366f1", penwidth=2.5];
    C1 -- C4 [color="#6366f1", penwidth=2.5];
    C2 -- C3 [color="#6366f1", penwidth=2.5];
    C2 -- C4 [color="#6366f1", penwidth=2.5];
    C3 -- C4 [color="#6366f1", penwidth=2.5];

    // Other nodes and edges
    C1 -- O1 [style=dashed, color="#94a3b8"];
    C2 -- O2 [style=dashed, color="#94a3b8"];
    O1 -- O2 [style=dashed, color="#94a3b8"];
  }
  </div>

      iex> alias Yog.Property.Clique
      iex> graph = Yog.from_edges(:undirected, [
      ...>   {"C1", "C2", 1}, {"C1", "C3", 1}, {"C1", "C4", 1},
      ...>   {"C2", "C3", 1}, {"C2", "C4", 1}, {"C3", "C4", 1},
      ...>   {"C1", "O1", 1}, {"C2", "O2", 1}, {"O1", "O2", 1}
      ...> ])
      iex> clique = Clique.max_clique(graph)
      iex> MapSet.member?(clique, "C1") and MapSet.size(clique) == 4
      true

  ## Examples

      # Create a complete graph K4
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 1, to: 4, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
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
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Property.Clique.max_clique(graph) |> MapSet.size()
      3

      # Path graph (no cliques larger than 2)
      iex> path = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
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
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)
      iex> Yog.Property.Clique.all_maximal_cliques(graph) |> length()
      1

      # Path graph: each edge is a maximal clique of size 2
      iex> path = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
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
      adj =
        Map.new(nodes, fn u ->
          neighbors = Model.neighbor_ids(graph, u) |> MapSet.new()
          {u, neighbors}
        end)

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
    acc
  end

  defp bron_kerbosch_pivot(r, p, x, adj, acc) do
    pivot = choose_pivot(p, x, adj)

    pivot_neighbors = Map.get(adj, pivot, MapSet.new())
    candidates = MapSet.difference(p, pivot_neighbors)

    if MapSet.size(candidates) == 0 do
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

  # Choose pivot from P union X with maximum degree to P
  defp choose_pivot(p, x, adj) do
    max_p = find_max_degree_to_p(p, p, adj, {nil, -1})
    {pivot_x, _} = find_max_degree_to_p(x, p, adj, max_p)
    pivot_x
  end

  defp find_max_degree_to_p(search_set, p, adj, {_current_best, _current_max} = acc) do
    Enum.reduce(search_set, acc, fn u, {_best_u, max_deg} = inner_acc ->
      neighbors = Map.get(adj, u, MapSet.new())
      # Degree to P
      deg = MapSet.intersection(neighbors, p) |> MapSet.size()

      if deg > max_deg do
        {u, deg}
      else
        inner_acc
      end
    end)
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
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 1, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 1, to: 4, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 4, with: 1)
      ...> |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)
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
  def k_cliques(_graph, k) when k <= 0, do: []
  def k_cliques(graph, 1), do: Model.all_nodes(graph) |> Enum.map(&MapSet.new([&1]))

  def k_cliques(graph, k) do
    nodes = Model.all_nodes(graph) |> Enum.sort()

    adj =
      Map.new(nodes, fn u ->
        neighbors = Model.neighbor_ids(graph, u) |> MapSet.new()
        {u, neighbors}
      end)

    find_k_cliques_recursive(nodes, k, [], adj, [])
  end

  defp find_k_cliques_recursive(_candidates, 0, current_clique, _adj, acc) do
    [MapSet.new(current_clique) | acc]
  end

  defp find_k_cliques_recursive([], _k, _current, _adj, acc), do: acc

  defp find_k_cliques_recursive([u | tail], k, current, adj, acc) do
    u_neighbors = Map.get(adj, u, MapSet.new())

    new_candidates = Enum.filter(tail, fn v -> MapSet.member?(u_neighbors, v) end)

    acc =
      if length(new_candidates) >= k - 1 do
        find_k_cliques_recursive(new_candidates, k - 1, [u | current], adj, acc)
      else
        acc
      end

    find_k_cliques_recursive(tail, k, current, adj, acc)
  end
end
