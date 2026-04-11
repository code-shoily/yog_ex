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
  | `cartesian_product/4` | Multiply graphs (grids, hypercubes) | Generate complex structures |
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
      ...> |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 0, with: 1)
      iex> triangle2 = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 0, with: 1)
      iex> # disjoint_union re-indexes the second graph automatically
      ...> combined = Yog.Operation.disjoint_union(triangle1, triangle2)
      iex> # Result: 6 nodes (0-5), two separate triangles
      ...> Yog.Model.order(combined)
      6

      # Finding common structure
      iex> graph_a = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> graph_b = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> common = Yog.Operation.intersection(graph_a, graph_b)
      iex> Yog.Model.order(common)
      2


  """

  alias Yog.Graph

  # =============================================================================
  # SET-THEORETIC OPERATIONS
  # =============================================================================

  @doc """
  Returns a graph containing all nodes and edges from both input graphs.

  Node data and edge weights from `other` take precedence on conflicts.
  Both graphs must have the same kind (`:directed` or `:undirected`);
  the result inherits the kind from `base`.

  **Time Complexity:** O(V₁ + V₂ + E₁ + E₂)

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> union = Yog.Operation.union(g1, g2)
      iex> Yog.Model.order(union)
      3
  """
  @spec union(Graph.t(), Graph.t()) :: Graph.t()
  def union(base, other) do
    Yog.Transform.merge(base, other)
  end

  @doc """
  Returns a graph containing only nodes and edges that exist in both input graphs.

  For directed graphs, a directed edge must exist in both graphs to be kept.
  For undirected graphs, an undirected edge must exist in both graphs.

  **Time Complexity:** O(V + E)

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> intersection = Yog.Operation.intersection(g1, g2)
      iex> Yog.Model.order(intersection)
      3
  """
  @spec intersection(Graph.t(), Graph.t()) :: Graph.t()
  def intersection(first, second) do
    common_nodes =
      MapSet.intersection(
        MapSet.new(Map.keys(first.nodes)),
        MapSet.new(Map.keys(second.nodes))
      )

    first
    |> Yog.Transform.subgraph(MapSet.to_list(common_nodes))
    |> Yog.Transform.filter_edges(fn u, v, _w ->
      has_edge?(second, u, v)
    end)
  end

  @doc """
  Returns a graph containing nodes and edges that exist in the first graph
  but not in the second.

  Any node that appears in `second` is removed from the result, along with
  all its incident edges. Of the remaining nodes, only edges that do not
  appear in `second` are kept.

  **Time Complexity:** O(V + E)

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(3, nil)
      iex> diff = Yog.Operation.difference(g1, g2)
      iex> Yog.Model.order(diff)
      2
      iex> Yog.Model.has_edge?(diff, 1, 2)
      true
  """
  @spec difference(Graph.t(), Graph.t()) :: Graph.t()
  def difference(first, second) do
    second_node_set = MapSet.new(Map.keys(second.nodes))

    nodes_v1_minus_v2 =
      Map.keys(first.nodes)
      |> Enum.reject(&MapSet.member?(second_node_set, &1))

    first
    |> Yog.Transform.subgraph(nodes_v1_minus_v2)
    |> Yog.Transform.filter_edges(fn u, v, _w ->
      not has_edge?(second, u, v)
    end)
  end

  @doc """
  Returns a graph containing edges that exist in exactly one of the input graphs.

  The result is the union of `difference(first, second)` and
  `difference(second, first)`. Nodes that have no incident unique edges
  will not appear in the result.

  **Time Complexity:** O(V₁ + V₂ + E₁ + E₂)

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> sym_diff = Yog.Operation.symmetric_difference(g1, g2)
      iex> Yog.Model.order(sym_diff)
      1
      iex> Yog.Model.edge_count(sym_diff)
      0
  """
  @spec symmetric_difference(Graph.t(), Graph.t()) :: Graph.t()
  def symmetric_difference(first, second) do
    first_only = difference(first, second)
    second_only = difference(second, first)
    union(first_only, second_only)
  end

  # =============================================================================
  # COMPOSITION & JOINS
  # =============================================================================

  @doc """
  Computes the disjoint union of two graphs.

  Unlike a simple join, this function guarantees that nodes from Graph A
  and Graph B remain distinct by tagging their IDs as `{0, id}` and `{1, id}`,
  even if they share the same original ID.

  The resulting graph uses the kind (`:directed` or `:undirected`) from
  `graph_a`. Combining graphs of different kinds may lead to unexpected
  edge behavior.

  **Time Complexity:** O(V₁ + V₂ + E₁ + E₂)

  ## Example
      iex> g1 = Yog.directed() |> Yog.add_node("root", "Data A")
      iex> g2 = Yog.directed() |> Yog.add_node("root", "Data B")
      iex> union = Yog.Operation.disjoint_union(g1, g2)
      iex> Yog.Model.node_count(union)
      2
      iex> Yog.Model.node(union, {0, "root"})
      "Data A"
  """
  @spec disjoint_union(Graph.t(), Graph.t()) :: Graph.t()
  def disjoint_union(graph_a, graph_b) do
    Yog.Graph.new(graph_a.kind)
    |> add_tagged_component(graph_a, 0)
    |> add_tagged_component(graph_b, 1)
  end

  @doc """
  Returns the Cartesian product of two graphs.

  Creates a new graph where each node represents a pair of nodes from the
  input graphs. Useful for generating grids, hypercubes, and other
  complex structures.

  **Time Complexity:** O(V₁ × V₂ + E₁ × V₂ + E₂ × V₁)

  ## Parameters

  - `first` - First input graph
  - `second` - Second input graph
  - `default_first` - Default edge data for edges derived from `first`
  - `default_second` - Default edge data for edges derived from `second`

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
      iex> product = Yog.Operation.cartesian_product(g1, g2, 0, 0)
      iex> # 2x2 grid structure: 4 nodes
      ...> Yog.Model.order(product)
      4
  """
  @spec cartesian_product(Graph.t(), Graph.t(), any(), any()) :: Graph.t()
  def cartesian_product(first, second, default_first, default_second) do
    first_nodes = Map.keys(first.nodes)
    second_nodes = Map.keys(second.nodes)
    second_order = map_size(second.nodes)

    u_map = Enum.with_index(first_nodes) |> Enum.into(%{})
    v_map = Enum.with_index(second_nodes) |> Enum.into(%{})

    Yog.Graph.new(first.kind)
    |> add_product_nodes(first, second, u_map, v_map, second_order)
    |> add_product_vertical_edges(first, second, u_map, v_map, second_order, default_second)
    |> add_product_horizontal_edges(first, second, u_map, v_map, second_order, default_first)
  end

  @doc """
  Composes two graphs by merging overlapping nodes and combining their edges.

  This is equivalent to `union/2` - both graphs are merged together with
  `other`'s data taking precedence on conflicts.

  **Time Complexity:** O(V₁ + V₂ + E₁ + E₂)

  ## Examples

      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> composed = Yog.Operation.compose(g1, g2)
      iex> Yog.Model.order(composed)
      3
  """
  @spec compose(Graph.t(), Graph.t()) :: Graph.t()
  def compose(first, second) do
    union(first, second)
  end

  @doc """
  Returns the line graph of a graph.

  The line graph L(G) is a graph where each node represents an edge of G,
  and two nodes are adjacent if and only if their corresponding edges share
  a common endpoint in G.

  For **directed graphs**, two edges `(u, v)` and `(x, y)` are adjacent in the
  line graph if and only if `v == x` (the head of the first edge matches the
  tail of the second edge). This is the standard line digraph definition.

  For **undirected graphs**, two edges `{u, v}` and `{x, y}` are adjacent if
  and only if they share at least one endpoint.

  Line graph nodes are represented as `{u, v}` tuples. For undirected graphs,
  the tuple follows the same ordering convention as `Yog.Model.all_edges/1`
  (`u <= v` using Erlang term ordering).

  **Time Complexity:** O(E²) where E is the number of edges in the original graph

  ## Parameters

  - `graph` - The input graph
  - `default_weight` - Weight for edges in the line graph (default: 1)

  ## Examples

      iex> path = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 0, to: 1, with: 10)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 20)
      iex> lg = Yog.Operation.line_graph(path, 1)
      iex> # Line graph of a path has 2 nodes ({0,1} and {1,2}) and 1 edge
      iex> Yog.Model.order(lg)
      2
      iex> Yog.Model.has_edge?(lg, {0, 1}, {1, 2})
      true
  """
  @spec line_graph(Graph.t(), term()) :: Graph.t()
  def line_graph(%Graph{kind: kind} = graph, default_weight \\ 1) do
    edges = extract_edges_for_line_graph(graph)

    init_lg =
      Enum.reduce(edges, Graph.new(kind), fn {u, v, w}, acc ->
        Yog.add_node(acc, {u, v}, w)
      end)

    connect_line_graph(init_lg, graph, edges, kind, default_weight)
  end

  @doc """
  Returns the k-th power of a graph.

  The k-th power of a graph G, denoted G^k, is a graph where two nodes are
  adjacent if and only if their distance in G is at most k.

  Self-loops are never added.

  **Time Complexity:** O(V × (V + E)) in the worst case

  ## Parameters

  - `graph` - The input graph
  - `k` - The power (distance threshold)
  - `default_weight` - Weight for newly created edges

  ## Examples

      iex> path = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> # G^2 connects nodes at distance <= 2
      ...> power = Yog.Operation.power(path, 2, 1)
      iex> # Node 0 and 2 should now be connected (distance 2 in original)
      ...> Yog.Model.has_edge?(power, 0, 2)
      true
  """
  @spec power(Graph.t(), integer(), any()) :: Graph.t()
  def power(graph, k, default_weight) do
    if k <= 1 do
      graph
    else
      nodes = Map.keys(graph.nodes)

      Enum.reduce(nodes, graph, fn src, acc_graph ->
        reachable = nodes_within_distance(acc_graph, src, k)

        Enum.reduce(reachable, acc_graph, fn dst, g ->
          maybe_add_power_edge(g, src, dst, default_weight)
        end)
      end)
    end
  end

  # =============================================================================
  # STRUCTURAL COMPARISON
  # =============================================================================

  @doc """
  Checks if the first graph is a subgraph of the second graph.

  Returns `true` if all nodes and edges in the first graph exist in the second.

  **Time Complexity:** O(Vₚ + Eₚ) where Vₚ and Eₚ are the nodes and edges of the potential subgraph

  ## Examples

      iex> container = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)
      iex> potential = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> Yog.Operation.subgraph?(potential, container)
      true
      iex> not_subgraph = Yog.undirected()
      ...> |> Yog.add_node(4, nil)
      ...> |> Yog.add_node(5, nil)
      ...> |> Yog.add_edge_ensure(from: 4, to: 5, with: 1)
      iex> Yog.Operation.subgraph?(not_subgraph, container)
      false
  """
  @spec subgraph?(Graph.t(), Graph.t()) :: boolean()
  def subgraph?(potential, container) do
    potential_nodes = Map.keys(potential.nodes)
    container_nodes = MapSet.new(Map.keys(container.nodes))

    all_nodes_present = Enum.all?(potential_nodes, &MapSet.member?(container_nodes, &1))

    if all_nodes_present do
      Enum.all?(potential_nodes, fn src ->
        potential_successors = successors_list(potential, src)
        Enum.all?(potential_successors, fn {dst, _} -> has_edge?(container, src, dst) end)
      end)
    else
      false
    end
  end

  @doc """
  Checks if two graphs are isomorphic (structurally identical).

  Two graphs are isomorphic if there exists a bijection between their node sets
  that preserves adjacency. This implementation uses degree sequence comparison
  and backtracking to test for isomorphism.

  **Time Complexity:** O(V log V + E) for the fast checks; exponential in the
  worst case due to backtracking (not recommended for large graphs).

  ## Examples

      # Two identical triangles are isomorphic
      iex> g1 = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      ...> |> Yog.add_edge_ensure(from: 2, to: 0, with: 1)
      iex> g2 = Yog.undirected()
      ...> |> Yog.add_node(10, nil)
      ...> |> Yog.add_node(20, nil)
      ...> |> Yog.add_node(30, nil)
      ...> |> Yog.add_edge_ensure(from: 10, to: 20, with: 1)
      ...> |> Yog.add_edge_ensure(from: 20, to: 30, with: 1)
      ...> |> Yog.add_edge_ensure(from: 30, to: 10, with: 1)
      iex> Yog.Operation.isomorphic?(g1, g2)
      true
      iex> # Triangle is not isomorphic to a path
      iex> path = Yog.undirected()
      ...> |> Yog.add_node(0, nil)
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(from: 0, to: 1, with: 1)
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      iex> Yog.Operation.isomorphic?(g1, path)
      false
  """
  @spec isomorphic?(Graph.t(), Graph.t()) :: boolean()
  def isomorphic?(first, second) do
    first_order = map_size(first.nodes)
    second_order = map_size(second.nodes)

    if first_order != second_order do
      false
    else
      first_edges = Yog.Graph.edge_count(first)
      second_edges = Yog.Graph.edge_count(second)

      if first_edges != second_edges do
        false
      else
        first_degrees = degree_sequence(first) |> Enum.sort()
        second_degrees = degree_sequence(second) |> Enum.sort()

        if first_degrees != second_degrees do
          false
        else
          attempt_isomorphism(first, second)
        end
      end
    end
  end

  # =============================================================================
  # Private Helper Functions
  # =============================================================================

  defp has_edge?(graph, u, v) do
    graph.out_edges |> Map.get(u, %{}) |> Map.has_key?(v)
  end

  defp out_degree(graph, node) do
    graph.out_edges |> Map.get(node, %{}) |> map_size()
  end

  defp in_degree(graph, node) do
    graph.in_edges |> Map.get(node, %{}) |> map_size()
  end

  defp successors_list(graph, node) do
    graph.out_edges |> Map.get(node, %{}) |> Map.to_list()
  end

  # Reindex edges with a tag to avoid ID collisions
  defp add_tagged_component(target_graph, source_graph, tag) do
    target_graph =
      Enum.reduce(source_graph.nodes, target_graph, fn {node_id, data}, acc ->
        Yog.add_node(acc, {tag, node_id}, data)
      end)

    edges =
      Enum.flat_map(source_graph.out_edges, fn {u, inner} ->
        Enum.map(inner, fn {v, data} -> {u, v, data} end)
      end)

    Enum.reduce(edges, target_graph, fn {u, v, data}, acc ->
      {:ok, new_g} = Yog.add_edge(acc, {tag, u}, {tag, v}, data)
      new_g
    end)
  end

  defp add_product_nodes(init_graph, first, second, u_map, v_map, second_order) do
    Enum.reduce(first.nodes, init_graph, fn {u, u_data}, g_acc ->
      u_idx = Map.fetch!(u_map, u)

      Enum.reduce(second.nodes, g_acc, fn {v, v_data}, g ->
        v_idx = Map.fetch!(v_map, v)
        new_id = u_idx * second_order + v_idx
        Yog.add_node(g, new_id, {u_data, v_data})
      end)
    end)
  end

  defp add_product_vertical_edges(
         graph,
         first,
         second,
         u_map,
         v_map,
         second_order,
         default_second
       ) do
    Enum.reduce(Map.keys(first.nodes), graph, fn u, g_acc ->
      u_idx = Map.fetch!(u_map, u)

      Enum.reduce(second.out_edges, g_acc, fn {v, edges}, g ->
        v_idx = Map.fetch!(v_map, v)

        Enum.reduce(edges, g, fn {v_succ, weight}, g_inner ->
          v_succ_idx = Map.fetch!(v_map, v_succ)
          src_id = u_idx * second_order + v_idx
          dst_id = u_idx * second_order + v_succ_idx
          {:ok, new_g} = Yog.add_edge(g_inner, src_id, dst_id, {default_second, weight})
          new_g
        end)
      end)
    end)
  end

  defp add_product_horizontal_edges(
         graph,
         first,
         second,
         u_map,
         v_map,
         second_order,
         default_first
       ) do
    Enum.reduce(Map.keys(second.nodes), graph, fn v, g_acc ->
      v_idx = Map.fetch!(v_map, v)

      Enum.reduce(first.out_edges, g_acc, fn {u, edges}, g ->
        u_idx = Map.fetch!(u_map, u)

        Enum.reduce(edges, g, fn {u_succ, weight}, g_inner ->
          u_succ_idx = Map.fetch!(u_map, u_succ)
          src_id = u_idx * second_order + v_idx
          dst_id = u_succ_idx * second_order + v_idx
          {:ok, new_g} = Yog.add_edge(g_inner, src_id, dst_id, {weight, default_first})
          new_g
        end)
      end)
    end)
  end

  defp extract_edges_for_line_graph(graph) do
    edges_i =
      Enum.flat_map(graph.out_edges, fn {u, inner} ->
        Enum.map(inner, fn {v, w} -> {u, v, w} end)
      end)

    if graph.kind == :undirected do
      edges_i
      |> Enum.map(fn {u, v, w} -> if u <= v, do: {u, v, w}, else: {v, u, w} end)
      |> Enum.uniq_by(fn {u, v, _} -> {u, v} end)
    else
      edges_i
    end
  end

  defp connect_line_graph(lg, graph, edges, :directed, default_weight) do
    Enum.reduce(edges, lg, fn {u, v, _w}, acc ->
      v_successors = Yog.successors(graph, v)

      Enum.reduce(v_successors, acc, fn {y, _w2}, inner_acc ->
        if {u, v} != {v, y} do
          {:ok, new_g} = Yog.add_edge(inner_acc, {u, v}, {v, y}, default_weight)
          new_g
        else
          inner_acc
        end
      end)
    end)
  end

  defp connect_line_graph(lg, graph, _edges, :undirected, default_weight) do
    nodes = Map.keys(graph.nodes)

    Enum.reduce(nodes, lg, fn node, acc ->
      neighbors = Yog.neighbors(graph, node)

      incident_edges =
        Enum.map(neighbors, fn {succ, _weight} ->
          if node <= succ, do: {node, succ}, else: {succ, node}
        end)
        |> Enum.sort()

      connect_incident_pairs(incident_edges, acc, default_weight)
    end)
  end

  defp connect_incident_pairs([], acc, _weight), do: acc

  defp connect_incident_pairs([e1 | rest], acc, weight) do
    new_acc =
      Enum.reduce(rest, acc, fn e2, inner_acc ->
        if e1 != e2 do
          {:ok, new_g} = Yog.add_edge(inner_acc, e1, e2, weight)
          new_g
        else
          inner_acc
        end
      end)

    connect_incident_pairs(rest, new_acc, weight)
  end

  defp maybe_add_power_edge(g, src, dst, default_weight) do
    if src != dst and not has_edge?(g, src, dst) do
      case Yog.add_edge(g, src, dst, default_weight) do
        {:ok, new_g} -> new_g
        {:error, _} -> g
      end
    else
      g
    end
  end

  # Finds all nodes within distance k from a source node using BFS
  defp nodes_within_distance(graph, src, max_dist) do
    Yog.Traversal.fold_walk(
      over: graph,
      from: src,
      using: :breadth_first,
      initial: [],
      with: fn acc, node_id, meta ->
        if meta.depth <= max_dist do
          {:continue, [node_id | acc]}
        else
          {:stop, acc}
        end
      end
    )
  end

  # Computes the degree sequence of a graph as {in_degree, out_degree} pairs
  defp degree_sequence(graph) do
    Enum.map(Map.keys(graph.nodes), fn node ->
      {in_degree(graph, node), out_degree(graph, node)}
    end)
  end

  # Attempts to find an isomorphism between two graphs using backtracking
  defp attempt_isomorphism(first, second) do
    first_nodes =
      Map.keys(first.nodes)
      |> Enum.sort_by(fn n -> out_degree(first, n) + in_degree(first, n) end, :desc)

    second_nodes = Map.keys(second.nodes)

    try_mapping(first, second, first_nodes, second_nodes, %{})
  end

  defp try_mapping(_first, _second, [], _available, _mapping), do: true

  defp try_mapping(first, second, [src | rest], available, mapping) do
    src_deg = {in_degree(first, src), out_degree(first, src)}

    valid_candidates =
      Enum.filter(available, fn cand ->
        {in_degree(second, cand), out_degree(second, cand)} == src_deg
      end)

    Enum.any?(valid_candidates, fn candidate ->
      if mapping_valid?(first, second, src, candidate, mapping) do
        new_mapping = Map.put(mapping, src, candidate)
        new_available = Enum.filter(available, fn n -> n != candidate end)
        try_mapping(first, second, rest, new_available, new_mapping)
      else
        false
      end
    end)
  end

  # Checks if mapping src -> candidate is consistent with current mapping
  defp mapping_valid?(first, second, src, candidate, mapping) do
    src_succs = Map.get(first.out_edges, src, %{})
    cand_succs = Map.get(second.out_edges, candidate, %{})

    consistent_out =
      Enum.all?(mapping, fn {s, c} ->
        s in Map.keys(src_succs) == c in Map.keys(cand_succs)
      end)

    src_preds = Map.get(first.in_edges, src, %{})
    cand_preds = Map.get(second.in_edges, candidate, %{})

    consistent_in =
      Enum.all?(mapping, fn {s, c} ->
        s in Map.keys(src_preds) == c in Map.keys(cand_preds)
      end)

    consistent_out and consistent_in
  end
end
