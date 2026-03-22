defmodule Yog.Operation do
  @moduledoc """
  Graph operations - Set-theoretic operations, composition, and structural comparison.

  This module implements binary operations that treat graphs as sets of nodes and edges,
  following NetworkX's "Graph as a Set" philosophy. These operations allow you to combine,
  compare, and analyze structural differences between graphs.

  ## Set-Theoretic Operations

  | Function | Description | Use Case |
  |----------|-------------|----------|
  | `union/2` | All nodes and edges from both graphs | Combine graph data |
  | `intersection/2` | Only nodes and edges common to both | Find common structure |
  | `difference/2` | Nodes/edges in first but not second | Find unique structure |
  | `symmetric_difference/2` | Edges in exactly one graph | Find differing structure |

  ## Composition & Joins

  | Function | Description | Use Case |
  |----------|-------------|----------|
  | `disjoint_union/2` | Combine with automatic ID re-indexing | Safe graph combination |
  | `cartesian_product/2` | Multiply graphs (grids, hypercubes) | Generate complex structures |
  | `compose/2` | Merge overlapping graphs with combined edges | Layered systems |
  | `power/2` | k-th power (connect nodes within distance k) | Reachability analysis |

  ## Structural Comparison

  | Function | Description | Use Case |
  |----------|-------------|----------|
  | `subgraph?/2` | Check if first is subset of second | Validation, pattern matching |
  | `isomorphic?/2` | Check if graphs are structurally identical | Graph comparison |

  ## Examples

      # Two triangle graphs with overlapping IDs
      iex> triangle1 = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 0, to: 1, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 0, with: 1)
      iex> triangle2 = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 0, to: 1, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 0, with: 1)
      iex> # disjoint_union re-indexes the second graph automatically
      ...> combined = Yog.Operation.disjoint_union(triangle1, triangle2)
      iex> # Result: 6 nodes (0-5), two separate triangles
      ...> Yog.Model.order(combined)
      6

      # Finding common structure
      iex> graph_a = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> graph_b = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> common = Yog.Operation.intersection(graph_a, graph_b)
      iex> Yog.Model.order(common)
      2
  """

  # ============= Set-Theoretic Operations =============

  @doc """
  Returns a graph containing all nodes and edges from both input graphs.

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> union = Yog.Operation.union(g1, g2)
      iex> Yog.Model.order(union)
      3
  """
  @spec union(Yog.graph(), Yog.graph()) :: Yog.graph()
  defdelegate union(base, other), to: :yog@operation

  @doc """
  Returns a graph containing only nodes and edges that exist in both input graphs.

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> intersection = Yog.Operation.intersection(g1, g2)
      iex> Yog.Model.order(intersection)
      2
  """
  @spec intersection(Yog.graph(), Yog.graph()) :: Yog.graph()
  defdelegate intersection(first, second), to: :yog@operation

  @doc """
  Returns a graph containing nodes and edges that exist in the first graph
  but not in the second.

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(3, nil)
      iex> diff = Yog.Operation.difference(g1, g2)
      iex> Yog.Model.order(diff) >= 0
      true
  """
  @spec difference(Yog.graph(), Yog.graph()) :: Yog.graph()
  defdelegate difference(first, second), to: :yog@operation

  @doc """
  Returns a graph containing edges that exist in exactly one of the input graphs.

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      iex> sym_diff = Yog.Operation.symmetric_difference(g1, g2)
      iex> is_tuple(sym_diff)
      true
  """
  @spec symmetric_difference(Yog.graph(), Yog.graph()) :: Yog.graph()
  defdelegate symmetric_difference(first, second), to: :yog@operation

  # ============= Composition & Joins =============

  @doc """
  Combines two graphs assuming they are separate entities with automatic re-indexing.

  The second graph's node IDs are shifted by the order of the first graph,
  ensuring no ID collisions.

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_edge!(from: 0, to: 1, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_edge!(from: 0, to: 1, with: 1)
      iex> combined = Yog.Operation.disjoint_union(g1, g2)
      iex> # g1 has nodes 0,1; g2 nodes are re-indexed to 2,3
      ...> Yog.Model.order(combined)
      4
  """
  @spec disjoint_union(Yog.graph(), Yog.graph()) :: Yog.graph()
  defdelegate disjoint_union(base, other), to: :yog@operation

  @doc """
  Returns the Cartesian product of two graphs.

  Creates a new graph where each node represents a pair of nodes from the
  input graphs. Useful for generating grids, hypercubes, and other
  complex structures.

  ## Parameters

  - `first` - First input graph
  - `second` - Second input graph
  - `default_first` - Default edge data for edges from first graph
  - `default_second` - Default edge data for edges from second graph

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_edge!(from: 0, to: 1, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_edge!(from: 0, to: 1, with: 1)
      iex> product = Yog.Operation.cartesian_product(g1, g2, 0, 0)
      iex> # 2x2 grid structure: 4 nodes
      ...> Yog.Model.order(product)
      4
  """
  @spec cartesian_product(Yog.graph(), Yog.graph(), any(), any()) :: Yog.graph()
  defdelegate cartesian_product(first, second, default_first, default_second),
    to: :yog@operation

  @doc """
  Composes two graphs by merging overlapping nodes and combining their edges.

  This is equivalent to `union/2` - both graphs are merged together.

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> composed = Yog.Operation.compose(g1, g2)
      iex> Yog.Model.order(composed)
      3
  """
  @spec compose(Yog.graph(), Yog.graph()) :: Yog.graph()
  defdelegate compose(first, second), to: :yog@operation

  @doc """
  Returns the k-th power of a graph.

  The k-th power of a graph G, denoted G^k, is a graph where two nodes are
  adjacent if and only if their distance in G is at most k.

  ## Parameters

  - `graph` - The input graph
  - `k` - The power (distance threshold)
  - `default_weight` - Weight for newly created edges

  ## Examples

      iex> path = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 0, to: 1, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> # G^2 connects nodes at distance <= 2
      ...> power = Yog.Operation.power(path, 2, 1)
      iex> # Node 0 and 2 should now be connected (distance 2 in original)
      ...> Yog.Model.order(power)
      3
  """
  @spec power(Yog.graph(), integer(), any()) :: Yog.graph()
  defdelegate power(graph, k, default_weight), to: :yog@operation

  # ============= Structural Comparison =============

  @doc """
  Checks if the first graph is a subgraph of the second graph.

  Returns `true` if all nodes and edges in the first graph exist in the second.

  ## Examples

      iex> container = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 3, with: 1)
      iex> potential = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> Yog.Operation.subgraph?(potential, container)
      true
      iex> not_subgraph = Yog.undirected()
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_node(5, nil)
      ...> |> Yog.add_edge!(from: 4, to: 5, with: 1)
      iex> Yog.Operation.subgraph?(not_subgraph, container)
      false
  """
  @spec subgraph?(Yog.graph(), Yog.graph()) :: boolean()
  def subgraph?(potential, container) do
    :yog@operation.is_subgraph(potential, container)
  end

  @doc """
  Checks if two graphs are isomorphic (structurally identical).

  Two graphs are isomorphic if there exists a bijection between their node sets
  that preserves adjacency. This implementation uses degree sequence comparison
  and backtracking to test for isomorphism.

  ## Examples

      # Two identical triangles are isomorphic
      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 0, to: 1, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge!(from: 2, to: 0, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(10, nil)
      ...> |> Yog.add_node(20, nil)
      ...> |> Yog.add_node(30, nil)
      ...> |> Yog.add_edge!(from: 10, to: 20, with: 1)
      ...> |> Yog.add_edge!(from: 20, to: 30, with: 1)
      ...> |> Yog.add_edge!(from: 30, to: 10, with: 1)
      iex> Yog.Operation.isomorphic?(g1, g2)
      true
      iex> # Triangle is not isomorphic to a path
      iex> path = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge!(from: 0, to: 1, with: 1)
      ...> |> Yog.add_edge!(from: 1, to: 2, with: 1)
      iex> Yog.Operation.isomorphic?(g1, path)
      false
  """
  @spec isomorphic?(Yog.graph(), Yog.graph()) :: boolean()
  def isomorphic?(first, second) do
    :yog@operation.is_isomorphic(first, second)
  end
end
