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
  alias Yog.Model

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
        MapSet.new(Model.all_nodes(first)),
        MapSet.new(Model.all_nodes(second))
      )

    first
    |> Yog.Transform.subgraph(MapSet.to_list(common_nodes))
    |> Yog.Transform.filter_edges(fn u, v, _w -> Model.has_edge?(second, u, v) end)
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
    second_node_set = MapSet.new(Model.all_nodes(second))

    nodes_v1_minus_v2 =
      Model.all_nodes(first)
      |> Enum.reject(&MapSet.member?(second_node_set, &1))

    first
    |> Yog.Transform.subgraph(nodes_v1_minus_v2)
    |> Yog.Transform.filter_edges(fn u, v, _w -> not Model.has_edge?(second, u, v) end)
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
    Yog.Graph.new(Model.type(graph_a))
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
    first_nodes = Model.all_nodes(first)
    second_nodes = Model.all_nodes(second)
    second_order = Model.order(second)

    # Rank nodes to create stable integer re-indexing
    u_map = Enum.with_index(first_nodes) |> Enum.into(%{})
    v_map = Enum.with_index(second_nodes) |> Enum.into(%{})

    # Create empty graph with same kind
    init_graph = Yog.Graph.new(Model.type(first))

    # Add nodes: new_id = rank(u) * second_order + rank(v)
    graph_with_nodes =
      Enum.reduce(first_nodes, init_graph, fn u, g_acc ->
        u_data = Model.node(first, u)
        u_idx = Map.fetch!(u_map, u)

        Enum.reduce(second_nodes, g_acc, fn v, g ->
          v_idx = Map.fetch!(v_map, v)
          new_id = u_idx * second_order + v_idx
          v_data = Model.node(second, v)
          Model.add_node(g, new_id, {u_data, v_data})
        end)
      end)

    # Add edges from second graph (vertical)
    graph_with_second_edges =
      Enum.reduce(first_nodes, graph_with_nodes, fn u, g_acc ->
        u_idx = Map.fetch!(u_map, u)

        Enum.reduce(second_nodes, g_acc, fn v, g ->
          v_idx = Map.fetch!(v_map, v)

          Enum.reduce(Model.successors(second, v), g, fn {v_succ, weight}, g_inner ->
            v_succ_idx = Map.fetch!(v_map, v_succ)
            src_id = u_idx * second_order + v_idx
            dst_id = u_idx * second_order + v_succ_idx
            Model.add_edge!(g_inner, src_id, dst_id, {default_second, weight})
          end)
        end)
      end)

    # Add edges from first graph (horizontal)
    Enum.reduce(second_nodes, graph_with_second_edges, fn v, g_acc ->
      v_idx = Map.fetch!(v_map, v)

      Enum.reduce(first_nodes, g_acc, fn u, g ->
        u_idx = Map.fetch!(u_map, u)

        Enum.reduce(Model.successors(first, u), g, fn {u_succ, weight}, g_inner ->
          u_succ_idx = Map.fetch!(u_map, u_succ)
          src_id = u_idx * second_order + v_idx
          dst_id = u_succ_idx * second_order + v_idx
          Model.add_edge!(g_inner, src_id, dst_id, {weight, default_first})
        end)
      end)
    end)
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
      nodes = Model.all_nodes(graph)

      Enum.reduce(nodes, graph, fn src, acc_graph ->
        reachable = nodes_within_distance(acc_graph, src, k)

        Enum.reduce(reachable, acc_graph, fn dst, g ->
          cond do
            src == dst ->
              g

            Model.has_edge?(g, src, dst) ->
              g

            true ->
              case Model.add_edge(g, src, dst, default_weight) do
                {:ok, new_g} -> new_g
                {:error, _} -> g
              end
          end
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
    potential_nodes = Model.all_nodes(potential)
    container_nodes = MapSet.new(Model.all_nodes(container))

    all_nodes_exist =
      Enum.all?(potential_nodes, fn node ->
        MapSet.member?(container_nodes, node)
      end)

    if all_nodes_exist do
      Enum.all?(potential_nodes, fn src ->
        potential_successors = Model.successors(potential, src)

        Enum.all?(potential_successors, fn {dst, _weight} ->
          Model.has_edge?(container, src, dst)
        end)
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
    first_order = Model.order(first)
    second_order = Model.order(second)

    if first_order != second_order do
      false
    else
      first_edges = Model.edge_count(first)
      second_edges = Model.edge_count(second)

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

  # Reindex edges with a tag to avoid ID collisions
  defp add_tagged_component(target_graph, source_graph, tag) do
    target_graph =
      Enum.reduce(Model.all_nodes(source_graph), target_graph, fn node_id, acc ->
        data = Model.node(source_graph, node_id)
        Model.add_node(acc, {tag, node_id}, data)
      end)

    Enum.reduce(Model.all_edges(source_graph), target_graph, fn {u, v, data}, acc ->
      Model.add_edge!(acc, {tag, u}, {tag, v}, data)
    end)
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
    Model.all_nodes(graph)
    |> Enum.map(fn node ->
      out_deg = length(Model.successor_ids(graph, node))
      in_deg = length(Model.predecessors(graph, node))
      {in_deg, out_deg}
    end)
  end

  # Attempts to find an isomorphism between two graphs using backtracking
  defp attempt_isomorphism(first, second) do
    # Sort nodes by degree (descending) for better pruning
    first_nodes =
      Model.all_nodes(first)
      |> Enum.sort(fn a, b ->
        deg_a = length(Model.predecessors(first, a)) + length(Model.successor_ids(first, a))
        deg_b = length(Model.predecessors(first, b)) + length(Model.successor_ids(first, b))
        deg_b <= deg_a
      end)

    second_nodes = Model.all_nodes(second)

    try_mapping(first, second, first_nodes, second_nodes, %{})
  end

  defp try_mapping(_first, _second, [], _available, _mapping), do: true

  defp try_mapping(first, second, [src | rest], available, mapping) do
    src_in = length(Model.predecessors(first, src))
    src_out = length(Model.successor_ids(first, src))

    valid_candidates =
      Enum.filter(available, fn candidate ->
        cand_in = length(Model.predecessors(second, candidate))
        cand_out = length(Model.successor_ids(second, candidate))
        src_in == cand_in && src_out == cand_out
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
    src_successors = Model.successor_ids(first, src)
    candidate_successors = Model.successor_ids(second, candidate)

    inconsistent_edges =
      Enum.reduce(mapping, 0, fn {src_neighbor, candidate_neighbor}, count ->
        edge_in_first? = src_neighbor in src_successors
        edge_in_second? = candidate_neighbor in candidate_successors

        if edge_in_first? == edge_in_second? do
          count
        else
          count + 1
        end
      end)

    src_predecessors =
      Model.predecessors(first, src) |> Enum.map(fn {id, _} -> id end)

    candidate_predecessors =
      Model.predecessors(second, candidate) |> Enum.map(fn {id, _} -> id end)

    inconsistent_incoming =
      Enum.reduce(mapping, 0, fn {src_neighbor, candidate_neighbor}, count ->
        edge_in_first? = src_neighbor in src_predecessors
        edge_in_second? = candidate_neighbor in candidate_predecessors

        if edge_in_first? == edge_in_second? do
          count
        else
          count + 1
        end
      end)

    inconsistent_edges == 0 && inconsistent_incoming == 0
  end
end
