defmodule Yog.Property do
  @moduledoc """
  Unified facade for assessing graph structures and invariant properties.

  This module provides a convenient entry point for querying whether a graph
  satisfies certain topological or algorithmic properties (e.g., connectivity,
  planarity, chordality).

  ## Categories

  ### Structure
  Predicates for tree structures, connectivity, and topological density.

  ### Eulerian Properties
  Algorithms for discovering paths or circuits that visit every edge exactly once.

  ### Bipartite & Matching
  Checks for 2-colorability and finding maximum matchings in bipartite configurations.

  ### Cliques & Communities
  Finding complete subgraphs (maximal, maximum, or of specific size k).

  ### Cyclicity
  Acyclicity (DAG) and general cycle detection.

  ### Treewidth & Decompositions
  Heuristic upper bounds and tree decomposition construction.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(2, 3, 1, nil)
      ...> |> Yog.add_edge_ensure(3, 1, 1, nil)
      iex> Yog.Property.connected?(graph)
      true
      iex> Yog.Property.complete?(graph)
      true
      iex> Yog.Property.max_clique(graph) |> MapSet.size()
      3
  """

  alias Yog.Property.{
    Bipartite,
    Clique,
    Coloring,
    Cyclicity,
    Eulerian,
    Planarity,
    Structure,
    WeisfeilerLehman
  }

  # ============= Structure =============

  @doc """
  Checks if the graph is a tree (connected and acyclic).

  ## Examples

      iex> tree = Yog.undirected()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(2, 3, 1, nil)
      iex> Yog.Property.tree?(tree)
      true
  """
  defdelegate tree?(graph), to: Structure

  @doc """
  Checks if the graph is an arborescence (directed tree with a single root).

  ## Examples

      iex> arb = Yog.directed()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(1, 3, 1, nil)
      iex> Yog.Property.arborescence?(arb)
      true
  """
  defdelegate arborescence?(graph), to: Structure

  @doc """
  Finds the root of an arborescence. Returns nil if none exists.

  ## Examples

      iex> arb = Yog.from_edges(:directed, [{"R", "A", 1}, {"R", "B", 1}, {"A", "C", 1}])
      iex> Yog.Property.arborescence_root(arb)
      "R"
      iex> not_arb = Yog.from_edges(:directed, [{1, 2, 1}, {2, 1, 1}])
      iex> Yog.Property.arborescence_root(not_arb)
      nil
  """
  defdelegate arborescence_root(graph), to: Structure

  @doc """
  Checks if the graph is a forest (disjoint collection of trees).

  ## Examples

      iex> forest = Yog.undirected()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(3, 4, 1, nil)
      iex> Yog.Property.forest?(forest)
      true
  """
  defdelegate forest?(graph), to: Structure

  @doc """
  Checks if a directed graph is a branching (directed forest).

  ## Examples

      iex> branch = Yog.directed()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(1, 3, 1, nil)
      ...> |> Yog.add_edge_ensure(4, 5, 1, nil)
      iex> Yog.Property.branching?(branch)
      true
  """
  defdelegate branching?(graph), to: Structure

  @doc """
  Checks if the graph is complete (every pair of distinct nodes is connected).

  ## Examples

      iex> k3 = Yog.undirected()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(2, 3, 1, nil)
      ...> |> Yog.add_edge_ensure(3, 1, 1, nil)
      iex> Yog.Property.complete?(k3)
      true
  """
  defdelegate complete?(graph), to: Structure

  @doc """
  Checks if the graph is k-regular (every node has degree exactly k).

  ## Examples

      iex> c4 = Yog.undirected()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(2, 3, 1, nil)
      ...> |> Yog.add_edge_ensure(3, 4, 1, nil)
      ...> |> Yog.add_edge_ensure(4, 1, 1, nil)
      iex> Yog.Property.regular?(c4, 2)
      true
  """
  defdelegate regular?(graph, k), to: Structure

  @doc """
  Checks if the graph is connected (undirected) or strongly connected (directed).

  ## Examples

      iex> g = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil) |> Yog.add_edge_ensure(2, 1, 1, nil)
      iex> Yog.Property.connected?(g)
      true
  """
  defdelegate connected?(graph), to: Structure

  @doc """
  Checks if a directed graph is strongly connected.

  ## Examples

      iex> cycle = Yog.from_edges(:directed, [{"A", "B", 1}, {"B", "C", 1}, {"C", "A", 1}])
      iex> Yog.Property.strongly_connected?(cycle)
      true
      iex> path = Yog.from_edges(:directed, [{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Property.strongly_connected?(path)
      false
  """
  defdelegate strongly_connected?(graph), to: Structure

  @doc """
  Checks if a directed graph is weakly connected.

  ## Examples

      iex> g = Yog.from_edges(:directed, [{"A", "B", 1}, {"C", "B", 1}])
      iex> Yog.Property.weakly_connected?(g)
      true
      iex> disconnected = Yog.from_edges(:directed, [{1, 2, 1}, {3, 4, 1}])
      iex> Yog.Property.weakly_connected?(disconnected)
      false
  """
  defdelegate weakly_connected?(graph), to: Structure

  @doc """
  Checks if the graph is planar. Uses density heuristics (necessary conditions).

  For graphs with $V \ge 3$, validates $|E| \le 3|V| - 6$.
  If bipartite, validates $|E| \le 2|V| - 4$.
  """
  defdelegate planar?(graph), to: Planarity

  @doc """
  Returns a combinatorial embedding if the graph is planar.

  ## Examples

      iex> square = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}, {4, 1, 1}])
      iex> {:ok, embedding} = Yog.Property.planar_embedding(square)
      iex> is_map(embedding)
      true
  """
  defdelegate planar_embedding(graph), to: Planarity

  @doc """
  Identifies a Kuratowski witness that proves the graph is non-planar.

  ## Examples

      iex> k5 = Yog.Generator.Classic.complete(5)
      iex> {:ok, witness} = Yog.Property.kuratowski_witness(k5)
      iex> witness.type
      :k5
      iex> square = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}, {4, 1, 1}])
      iex> Yog.Property.kuratowski_witness(square)
      :planar
  """
  defdelegate kuratowski_witness(graph), to: Planarity

  @doc """
  Checks if the graph is chordal (no induced cycles longer than 3).
  Uses Maximum Cardinality Search (MCS).

  ## Examples

      iex> g = Yog.undirected()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(2, 3, 1, nil)
      ...> |> Yog.add_edge_ensure(3, 1, 1, nil) # triangle
      iex> Yog.Property.chordal?(g)
      true
  """
  defdelegate chordal?(graph), to: Structure

  # ============= Eulerian =============

  @doc """
  Checks if the graph contains an Eulerian circuit (visits every edge once).

  Degrees must be even (undirected) or balanced (directed).

  ## Examples

      iex> square = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}, {4, 1, 1}])
      iex> Yog.Property.has_eulerian_circuit?(square)
      true
      iex> path = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Property.has_eulerian_circuit?(path)
      false
  """
  defdelegate has_eulerian_circuit?(graph), to: Eulerian

  @doc """
  Finds an Eulerian circuit in the graph using Hierholzer's algorithm.

  ## Examples

      iex> square = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}, {4, 1, 1}])
      iex> {:ok, circuit} = Yog.Property.eulerian_circuit(square)
      iex> length(circuit)
      5
  """
  defdelegate eulerian_circuit(graph), to: Eulerian

  @doc """
  Checks if the graph contains an Eulerian path.

  ## Examples

      iex> path = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Property.has_eulerian_path?(path)
      true
      iex> two_paths = Yog.from_edges(:undirected, [{1, 2, 1}, {3, 4, 1}])
      iex> Yog.Property.has_eulerian_path?(two_paths)
      false
  """
  defdelegate has_eulerian_path?(graph), to: Eulerian

  @doc """
  Finds an Eulerian path in the graph using Hierholzer's algorithm.

  ## Examples

      iex> path = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
      iex> {:ok, p} = Yog.Property.eulerian_path(path)
      iex> length(p)
      3
  """
  defdelegate eulerian_path(graph), to: Eulerian

  # ============= Bipartite =============

  @doc """
  Determines if a graph is bipartite (2-colorable).

  ## Examples

      iex> square = Yog.undirected()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(2, 3, 1, nil)
      ...> |> Yog.add_edge_ensure(3, 4, 1, nil)
      ...> |> Yog.add_edge_ensure(4, 1, 1, nil)
      iex> Yog.Property.bipartite?(square)
      true
  """
  defdelegate bipartite?(graph), to: Bipartite

  @doc """
  Returns the two partitions of a bipartite graph, or an error if not bipartite.

  ## Examples

      iex> path = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])
      iex> {:ok, %{left: left, right: right}} = Yog.Property.partition(path)
      iex> MapSet.size(left) + MapSet.size(right)
      4
      iex> triangle = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> Yog.Property.partition(triangle)
      {:error, :not_bipartite}
  """
  defdelegate partition(graph), to: Bipartite

  @doc """
  Finds a 2-coloring of a graph if it is bipartite.

  ## Examples

      iex> path = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
      iex> {:ok, colors} = Yog.Property.coloring(path)
      iex> colors[1] != colors[2]
      true
  """
  defdelegate coloring(graph), to: Bipartite

  @doc """
  Finds a maximum matching in a bipartite graph.

  ## Examples

      iex> g = Yog.from_edges(:undirected, [{"w1", "t1", 1}, {"w1", "t2", 1}, {"w2", "t1", 1}])
      iex> {:ok, p} = Yog.Property.partition(g)
      iex> length(Yog.Property.maximum_matching(g, p))
      2
  """
  defdelegate maximum_matching(graph, partition), to: Bipartite

  @doc """
  Finds a stable matching given preference lists for two groups.

  ## Examples

      iex> residents = %{1 => [101, 102], 2 => [102, 101]}
      iex> hospitals = %{101 => [1, 2], 102 => [2, 1]}
      iex> matches = Yog.Property.stable_marriage(residents, hospitals)
      iex> matches[1]
      101
  """
  defdelegate stable_marriage(left_prefs, right_prefs), to: Bipartite

  # ============= Coloring =============

  @doc """
  Greedy graph coloring using Welsh-Powell ordering.

  Returns a tuple `{upper_bound, color_map}` where `upper_bound` is the number
  of colors used and `color_map` maps each node to its assigned color.

  ## Examples

      iex> graph = Yog.Generator.Classic.complete(3)
      iex> {upper, _colors} = Yog.Property.coloring_greedy(graph)
      iex> upper == 3
      true
  """
  defdelegate coloring_greedy(graph), to: Coloring

  @doc """
  DSatur heuristic for graph coloring.

  Usually produces better colorings than simple greedy ordering.

  ## Examples

      iex> graph = Yog.Generator.Classic.cycle(5)
      iex> {upper, _colors} = Yog.Property.coloring_dsatur(graph)
      iex> upper == 3
      true
  """
  defdelegate coloring_dsatur(graph), to: Coloring

  @doc """
  Exact graph coloring using backtracking with pruning and an optional timeout.

  Returns `{:ok, chromatic_number, coloring}` on success, or `{:timeout, best_result}`
  if the timeout is reached.

  ## Examples

      iex> graph = Yog.Generator.Classic.complete(4)
      iex> {:ok, chi, _colors} = Yog.Property.coloring_exact(graph)
      iex> chi == 4
      true
  """
  defdelegate coloring_exact(graph, timeout_ms), to: Coloring

  @doc """
  Exact graph coloring with default 5-second timeout.

  ## Examples

      iex> k4 = Yog.Generator.Classic.complete(4)
      iex> {:ok, chi, _colors} = Yog.Property.coloring_exact(k4)
      iex> chi
      4
  """
  defdelegate coloring_exact(graph), to: Coloring

  # ============= Treewidth =============

  @doc """
  Returns an upper bound on the treewidth using heuristic elimination ordering.

  ## Options
  - `:heuristic` - `:min_degree` (default) or `:min_fill`

  ## Examples

      iex> graph = Yog.Generator.Classic.cycle(5)
      iex> Yog.Property.treewidth_upper_bound(graph) <= 2
      true
  """
  defdelegate treewidth_upper_bound(graph, opts), to: Yog.Approximate

  @doc """
  Returns an upper bound on the treewidth with default `:min_degree` heuristic.

  ## Examples

      iex> graph = Yog.Generator.Classic.cycle(5)
      iex> Yog.Property.treewidth_upper_bound(graph) <= 2
      true
  """
  defdelegate treewidth_upper_bound(graph), to: Yog.Approximate

  @doc """
  Returns a tree decomposition of the graph using heuristic elimination ordering.

  Returns `{:ok, Yog.Property.TreeDecomposition.t()}` on success.

  ## Examples

      iex> graph = Yog.Generator.Classic.cycle(5)
      iex> {:ok, td} = Yog.Property.tree_decomposition(graph, heuristic: :min_degree)
      iex> is_map(td.bags)
      true
  """
  defdelegate tree_decomposition(graph, opts), to: Yog.Approximate

  @doc """
  Returns a tree decomposition with default `:min_degree` heuristic.

  ## Examples

      iex> graph = Yog.Generator.Classic.cycle(5)
      iex> {:ok, td} = Yog.Property.tree_decomposition(graph)
      iex> is_map(td.bags)
      true
  """
  defdelegate tree_decomposition(graph), to: Yog.Approximate

  @doc """
  Returns the minimum degree of the graph.

  ## Examples

      iex> graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Property.minimum_degree(graph)
      1
      iex> isolated = Yog.undirected() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil)
      iex> Yog.Property.minimum_degree(isolated)
      0
  """
  defdelegate minimum_degree(graph), to: Structure

  # ============= Clique =============

  @doc """
  Finds the maximum clique in an undirected graph.

  ## Examples

      iex> graph = Yog.undirected()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(1, 3, 1, nil)
      ...> |> Yog.add_edge_ensure(2, 3, 1, nil)
      iex> Yog.Property.max_clique(graph) |> MapSet.size()
      3
  """
  defdelegate max_clique(graph), to: Clique

  @doc """
  Finds all maximal cliques in an undirected graph.

  ## Examples

      iex> triangle = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> Yog.Property.all_maximal_cliques(triangle) |> length()
      1
  """
  defdelegate all_maximal_cliques(graph), to: Clique

  @doc """
  Finds all cliques of exactly size k in an undirected graph.

  ## Examples

      iex> k4 = Yog.Generator.Classic.complete(4)
      iex> Yog.Property.k_cliques(k4, 3) |> length()
      4
  """
  defdelegate k_cliques(graph, k), to: Clique

  # ============= Cyclicity =============

  @doc """
  Checks if the graph is a Directed Acyclic Graph (DAG) or has no cycles.

  ## Examples

      iex> dag = Yog.directed() |> Yog.add_edge_ensure(1, 2, 1, nil)
      iex> Yog.Property.acyclic?(dag)
      true
  """
  defdelegate acyclic?(graph), to: Cyclicity

  @doc """
  Checks if the graph contains at least one cycle.

  ## Examples

      iex> cycle = Yog.from_edges(:directed, [{"A", "B", 1}, {"B", "C", 1}, {"C", "A", 1}])
      iex> Yog.Property.cyclic?(cycle)
      true
      iex> dag = Yog.from_edges(:directed, [{1, 2, 1}, {2, 3, 1}])
      iex> Yog.Property.cyclic?(dag)
      false
  """
  defdelegate cyclic?(graph), to: Cyclicity

  # ============= Isomorphism & Hashing =============

  @doc """
  Returns a deterministic structural hash of the graph.
  Uses the Weisfeiler-Lehman topological graph hashing algorithm.

  Graphs with identical structural arrangements return the same hash.

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(2, 3, 1, nil)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_edge_ensure(:a, :b, 1, nil)
      ...> |> Yog.add_edge_ensure(:b, :c, 1, nil)
      iex> Yog.Property.hash(g1) == Yog.Property.hash(g2)
      true
  """
  defdelegate hash(graph), to: WeisfeilerLehman, as: :graph_hash

  @doc """
  Returns a deterministic structural hash of the graph with custom options.

  ## Examples

      iex> g = Yog.Generator.Classic.cycle(4)
      iex> hash = Yog.Property.hash(g, iterations: 5)
      iex> is_binary(hash) and byte_size(hash) == 32
      true
  """
  defdelegate hash(graph, opts), to: WeisfeilerLehman, as: :graph_hash

  @doc """
  Checks if two graphs are structurally isomorphic.

  ## Examples

      iex> g1 = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}])
      iex> g2 = Yog.from_edges(:undirected, [{:a, :b, 1}, {:b, :c, 1}])
      iex> Yog.Property.isomorphic?(g1, g2)
      true
      iex> triangle = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      iex> Yog.Property.isomorphic?(g1, triangle)
      false
  """
  def isomorphic?(g1, g2) do
    hash(g1) == hash(g2)
  end
end
