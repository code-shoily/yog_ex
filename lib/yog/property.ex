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

  alias Yog.Property.{Bipartite, Clique, Cyclicity, Eulerian, Structure}

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
  """
  defdelegate arborescence_root(graph), to: Structure

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

  @doc "Checks if a directed graph is strongly connected."
  defdelegate strongly_connected?(graph), to: Structure

  @doc "Checks if a directed graph is weakly connected."
  defdelegate weakly_connected?(graph), to: Structure

  @doc """
  Checks if the graph is planar. Uses density heuristics (necessary conditions).

  For graphs with $V \ge 3$, validates $|E| \le 3|V| - 6$.
  If bipartite, validates $|E| \le 2|V| - 4$.
  """
  defdelegate planar?(graph), to: Structure

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
  """
  defdelegate has_eulerian_circuit?(graph), to: Eulerian

  @doc "Finds an Eulerian circuit in the graph using Hierholzer's algorithm."
  defdelegate eulerian_circuit(graph), to: Eulerian

  @doc "Checks if the graph contains an Eulerian path."
  defdelegate has_eulerian_path?(graph), to: Eulerian

  @doc "Finds an Eulerian path in the graph using Hierholzer's algorithm."
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

  @doc "Returns the two partitions of a bipartite graph, or an error if not bipartite."
  defdelegate partition(graph), to: Bipartite

  @doc "Finds a 2-coloring of a graph if it is bipartite."
  defdelegate coloring(graph), to: Bipartite

  @doc "Finds a maximum matching in a bipartite graph."
  defdelegate maximum_matching(graph, partition), to: Bipartite

  @doc "Finds a stable matching given preference lists for two groups."
  defdelegate stable_marriage(left_prefs, right_prefs), to: Bipartite

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

  @doc "Finds all maximal cliques in an undirected graph."
  defdelegate all_maximal_cliques(graph), to: Clique

  @doc "Finds all cliques of exactly size k in an undirected graph."
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

  @doc "Checks if the graph contains at least one cycle."
  defdelegate cyclic?(graph), to: Cyclicity
end
