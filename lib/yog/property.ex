defmodule Yog.Property do
  @moduledoc """
  Unified facade for assessing graph structures and invariant properties.

  Delegates structural and analytical verifications to domain-specific property submodules.
  """

  alias Yog.Property.{Bipartite, Clique, Cyclicity, Eulerian, Structure}

  # ============= Structure =============

  @doc "Checks if the graph is a tree (connected and acyclic)."
  defdelegate tree?(graph), to: Structure

  @doc "Checks if the graph is an arborescence (directed tree with a single root)."
  defdelegate arborescence?(graph), to: Structure

  @doc "Finds the root of an arborescence."
  defdelegate arborescence_root(graph), to: Structure

  @doc "Checks if the graph is complete (every pair of distinct nodes is connected)."
  defdelegate complete?(graph), to: Structure

  @doc "Checks if the graph is k-regular (every node has degree exactly k)."
  defdelegate regular?(graph, k), to: Structure

  # ============= Eulerian =============

  @doc "Checks if the graph contains an Eulerian circuit."
  defdelegate has_eulerian_circuit?(graph), to: Eulerian

  @doc "Finds an Eulerian circuit in the graph using Hierholzer's algorithm."
  defdelegate eulerian_circuit(graph), to: Eulerian

  @doc "Checks if the graph contains an Eulerian path."
  defdelegate has_eulerian_path?(graph), to: Eulerian

  @doc "Finds an Eulerian path in the graph using Hierholzer's algorithm."
  defdelegate eulerian_path(graph), to: Eulerian

  # ============= Bipartite =============

  @doc "Determines if a graph is bipartite (2-colorable)."
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

  @doc "Finds the maximum clique in an undirected graph."
  defdelegate max_clique(graph), to: Clique

  @doc "Finds all maximal cliques in an undirected graph."
  defdelegate all_maximal_cliques(graph), to: Clique

  @doc "Finds all cliques of exactly size k in an undirected graph."
  defdelegate k_cliques(graph, k), to: Clique

  # ============= Cyclicity =============

  @doc "Checks if the graph is a Directed Acyclic Graph (DAG) or has no cycles if undirected."
  defdelegate acyclic?(graph), to: Cyclicity

  @doc "Checks if the graph contains at least one cycle."
  defdelegate cyclic?(graph), to: Cyclicity
end
