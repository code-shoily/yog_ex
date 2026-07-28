defmodule Yog.Operation do
  @moduledoc """
  Graph operations - Set-theoretic operations, composition, and structural comparison.

  This module implements binary operations that treat graphs as sets of nodes and edges,
  following NetworkX's "Graph as a Set" philosophy. These operations allow you to combine,
  compare, and analyze structural differences between graphs.

  ## Set-Theoretic Operations

  | Function | Complexity | Description | Use Case |
  |----------|------------|-------------|----------|
  | `union/2` | $\\mathcal{O}(V_1 + V_2 + E_1 + E_2)$ | All nodes and edges from both graphs | Combine graph data |
  | `intersection/2` | $\\mathcal{O}(V + E)$ | Only nodes and edges common to both | Find common structure |
  | `difference/2` | $\\mathcal{O}(V + E)$ | Nodes/edges in first but not second | Find unique structure |
  | `symmetric_difference/2` | $\\mathcal{O}(V_1 + V_2 + E_1 + E_2)$ | Edges in exactly one graph | Find differing structure |

  ## Composition & Joins

  | Function | Complexity | Description | Use Case |
  |----------|------------|-------------|----------|
  | `disjoint_union/2` | $\\mathcal{O}(V_1 + V_2 + E_1 + E_2)$ | Combine with automatic ID re-indexing | Safe graph combination |
  | `cartesian_product/4` | $\\mathcal{O}(V_1 V_2 + E_1 V_2 + E_2 V_1)$ | Multiply graphs (grids, hypercubes) | Generate complex structures |
  | `tensor_product/2` | $\\mathcal{O}(V_1 V_2 + E_1 E_2)$ | Kronecker direct product | Product graphs |
  | `strong_product/4` | $\\mathcal{O}(V_1 V_2 + E_1 V_2 + E_2 V_1 + E_1 E_2)$ | Strong product (grid + diagonals) | Spatial topologies |
  | `lexicographic_product/4` | $\\mathcal{O}(V_1 V_2 + E_1 V_2^2 + V_1 E_2)$ | Graph composition | Hierarchical substitution |
  | `compose/2` | $\\mathcal{O}(V_1 + V_2 + E_1 + E_2)$ | Merge overlapping graphs | Layered systems |
  | `line_graph/2` | $\\mathcal{O}(E^2)$ | Convert edges to nodes | Edge-centric analysis |
  | `power/3` | $\\mathcal{O}(V \\cdot (V + E))$ | $k$-th power (distance $\\le k$) | Reachability analysis |

  ## Structural Comparison

  | Function | Complexity | Description | Use Case |
  |----------|------------|-------------|----------|
  | `subgraph?/2` | $\\mathcal{O}(V_p + E_p)$ | Check if first is subset of second | Validation, pattern matching |
  | `isomorphic?/2` | Exponential worst-case | Check if graphs are structurally identical | Structural equivalence |
  """

  alias Yog.Graph
  alias Yog.Utils

  # =============================================================================
  # SET-THEORETIC OPERATIONS
  # =============================================================================

  @doc """
  Returns a graph containing all nodes and edges from both input graphs.

  Node data and edge weights from `other` take precedence on conflicts.
  Both graphs must be `%Yog.Graph{}` structs.

  **Time Complexity:** $\\mathcal{O}(V_1 + V_2 + E_1 + E_2)$
  """
  @spec union(Graph.t(), Graph.t()) :: Graph.t()
  def union(base, other) do
    validate_graph!(base)
    validate_graph!(other)
    Yog.Transform.merge(base, other)
  end

  @doc """
  Returns a graph containing only nodes and edges that exist in both input graphs.

  Both graphs must have the same kind (`:directed` or `:undirected`).

  **Time Complexity:** $\\mathcal{O}(V + E)$

  ## Errors

  - Raises `ArgumentError` if input graphs have different kinds.
  """
  @spec intersection(Graph.t(), Graph.t()) :: Graph.t()
  def intersection(first, second) do
    validate_graph!(first)
    validate_graph!(second)
    validate_same_kind!(first, second)

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

  Both graphs must have the same kind (`:directed` or `:undirected`).

  **Time Complexity:** $\\mathcal{O}(V + E)$

  ## Errors

  - Raises `ArgumentError` if input graphs have different kinds.
  """
  @spec difference(Graph.t(), Graph.t()) :: Graph.t()
  def difference(first, second) do
    validate_graph!(first)
    validate_graph!(second)
    validate_same_kind!(first, second)

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

  Both graphs must have the same kind (`:directed` or `:undirected`).

  **Time Complexity:** $\\mathcal{O}(V_1 + V_2 + E_1 + E_2)$

  ## Errors

  - Raises `ArgumentError` if input graphs have different kinds.
  """
  @spec symmetric_difference(Graph.t(), Graph.t()) :: Graph.t()
  def symmetric_difference(%Graph{} = first, %Graph{} = second) do
    validate_graph!(first)
    validate_graph!(second)
    validate_same_kind!(first, second)

    set1 = MapSet.new(Map.keys(first.nodes))
    set2 = MapSet.new(Map.keys(second.nodes))

    v1_minus_v2 = MapSet.difference(set1, set2)
    v2_minus_v1 = MapSet.difference(set2, set1)

    merged_nodes =
      Map.merge(
        Map.take(first.nodes, MapSet.to_list(v1_minus_v2)),
        Map.take(second.nodes, MapSet.to_list(v2_minus_v1))
      )

    base_graph = %Graph{first | nodes: merged_nodes, out_edges: %{}, in_edges: %{}}
    is_directed = first.kind == :directed

    edges1 =
      Enum.flat_map(MapSet.to_list(v1_minus_v2), fn u ->
        first_successors = Map.get(first.out_edges, u, %{})

        for {v, w} <- first_successors,
            MapSet.member?(v1_minus_v2, v),
            is_directed or u <= v do
          {u, v, w}
        end
      end)

    edges2 =
      Enum.flat_map(MapSet.to_list(v2_minus_v1), fn u ->
        second_successors = Map.get(second.out_edges, u, %{})

        for {v, w} <- second_successors,
            MapSet.member?(v2_minus_v1, v),
            is_directed or u <= v do
          {u, v, w}
        end
      end)

    Enum.reduce(edges1 ++ edges2, base_graph, fn {u, v, w}, acc ->
      Yog.add_edge_ensure(acc, u, v, w)
    end)
  end

  # =============================================================================
  # COMPOSITION & JOINS
  # =============================================================================

  @doc """
  Computes the disjoint union of two graphs.

  Guarantees that nodes from Graph A and Graph B remain distinct by tagging their
  IDs as `{0, id}` and `{1, id}`.

  **Time Complexity:** $\\mathcal{O}(V_1 + V_2 + E_1 + E_2)$
  """
  @spec disjoint_union(Graph.t(), Graph.t()) :: Graph.t()
  def disjoint_union(graph_a, graph_b) do
    validate_graph!(graph_a)
    validate_graph!(graph_b)

    Graph.new(graph_a.kind)
    |> add_tagged_component(graph_a, 0)
    |> add_tagged_component(graph_b, 1)
  end

  @doc """
  Returns the Cartesian product of two graphs.

  Creates a new graph where each node represents a pair of nodes from the
  input graphs.

  **Time Complexity:** $\\mathcal{O}(V_1 V_2 + E_1 V_2 + E_2 V_1)$
  """
  @spec cartesian_product(Graph.t(), Graph.t(), any(), any()) :: Graph.t()
  def cartesian_product(first, second, default_first, default_second) do
    validate_graph!(first)
    validate_graph!(second)

    first_nodes = Map.keys(first.nodes)
    second_nodes = Map.keys(second.nodes)
    second_order = map_size(second.nodes)

    u_map = Enum.with_index(first_nodes) |> Enum.into(%{})
    v_map = Enum.with_index(second_nodes) |> Enum.into(%{})

    Graph.new(first.kind)
    |> add_product_nodes(first, second, u_map, v_map, second_order)
    |> add_product_vertical_edges(first, second, u_map, v_map, second_order, default_second)
    |> add_product_horizontal_edges(first, second, u_map, v_map, second_order, default_first)
  end

  @doc """
  Returns the Tensor product (Kronecker product) of two graphs.

  **Time Complexity:** $\\mathcal{O}(V_1 V_2 + E_1 E_2)$
  """
  @spec tensor_product(Graph.t(), Graph.t()) :: Graph.t()
  def tensor_product(first, second) do
    validate_graph!(first)
    validate_graph!(second)

    first_nodes = Map.keys(first.nodes)
    second_nodes = Map.keys(second.nodes)
    second_order = map_size(second.nodes)

    u_map = Enum.with_index(first_nodes) |> Enum.into(%{})
    v_map = Enum.with_index(second_nodes) |> Enum.into(%{})

    Graph.new(first.kind)
    |> add_product_nodes(first, second, u_map, v_map, second_order)
    |> add_tensor_edges(first, second, u_map, v_map, second_order)
  end

  @doc """
  Returns the Strong product of two graphs.

  **Time Complexity:** $\\mathcal{O}(V_1 V_2 + E_1 V_2 + E_2 V_1 + E_1 E_2)$
  """
  @spec strong_product(Graph.t(), Graph.t(), any(), any()) :: Graph.t()
  def strong_product(first, second, default_first, default_second) do
    validate_graph!(first)
    validate_graph!(second)

    first_nodes = Map.keys(first.nodes)
    second_nodes = Map.keys(second.nodes)
    second_order = map_size(second.nodes)

    u_map = Enum.with_index(first_nodes) |> Enum.into(%{})
    v_map = Enum.with_index(second_nodes) |> Enum.into(%{})

    Graph.new(first.kind)
    |> add_product_nodes(first, second, u_map, v_map, second_order)
    |> add_product_vertical_edges(first, second, u_map, v_map, second_order, default_second)
    |> add_product_horizontal_edges(first, second, u_map, v_map, second_order, default_first)
    |> add_tensor_edges(first, second, u_map, v_map, second_order)
  end

  @doc """
  Returns the Lexicographic product (composition) of two graphs.

  **Time Complexity:** $\\mathcal{O}(V_1 V_2 + E_1 V_2^2 + V_1 E_2)$
  """
  @spec lexicographic_product(Graph.t(), Graph.t(), any(), any()) :: Graph.t()
  def lexicographic_product(first, second, default_first, default_second) do
    validate_graph!(first)
    validate_graph!(second)

    first_nodes = Map.keys(first.nodes)
    second_nodes = Map.keys(second.nodes)
    second_order = map_size(second.nodes)

    u_map = Enum.with_index(first_nodes) |> Enum.into(%{})
    v_map = Enum.with_index(second_nodes) |> Enum.into(%{})

    Graph.new(first.kind)
    |> add_product_nodes(first, second, u_map, v_map, second_order)
    |> add_product_vertical_edges(first, second, u_map, v_map, second_order, default_second)
    |> add_lexicographic_horizontal_edges(
      first,
      second,
      u_map,
      v_map,
      second_order,
      default_first
    )
  end

  @doc """
  Composes two graphs by merging overlapping nodes and combining their edges.

  **Time Complexity:** $\\mathcal{O}(V_1 + V_2 + E_1 + E_2)$
  """
  @spec compose(Graph.t(), Graph.t()) :: Graph.t()
  def compose(first, second) do
    validate_graph!(first)
    validate_graph!(second)
    union(first, second)
  end

  @doc """
  Returns the line graph of a graph.

  **Time Complexity:** $\\mathcal{O}(E^2)$
  """
  @spec line_graph(Graph.t(), term()) :: Graph.t()
  def line_graph(%Graph{kind: kind} = graph, default_weight \\ 1) do
    validate_graph!(graph)
    edges = extract_edges_for_line_graph(graph)

    init_lg =
      Enum.reduce(edges, Graph.new(kind), fn {u, v, w}, acc ->
        Yog.add_node(acc, {u, v}, w)
      end)

    connect_line_graph(init_lg, graph, edges, kind, default_weight)
  end

  @doc """
  Returns the $k$-th power of a graph (connecting nodes at distance $\\le k$).

  **Time Complexity:** $\\mathcal{O}(V \\cdot (V + E))$

  ## Errors

  - Raises `ArgumentError` if `k` is not a positive integer ($\ge 1$).
  """
  @spec power(Graph.t(), integer(), any()) :: Graph.t()
  def power(graph, k, default_weight) do
    validate_graph!(graph)

    unless is_integer(k) and k >= 0 do
      raise ArgumentError, "expected k to be a non-negative integer, got: #{inspect(k)}"
    end

    nodes = Map.keys(graph.nodes)

    List.foldl(nodes, graph, fn src, acc_graph ->
      reachable = nodes_within_distance(acc_graph, src, k)

      List.foldl(reachable, acc_graph, fn dst, g ->
        maybe_add_power_edge(g, src, dst, default_weight)
      end)
    end)
  end

  # =============================================================================
  # STRUCTURAL COMPARISON
  # =============================================================================

  @doc """
  Checks if the first graph is a subgraph of the second graph.

  Both graphs must have the same kind (`:directed` or `:undirected`).

  **Time Complexity:** $\\mathcal{O}(V_p + E_p)$

  ## Errors

  - Raises `ArgumentError` if input graphs have different kinds.
  """
  @spec subgraph?(Graph.t(), Graph.t()) :: boolean()
  def subgraph?(potential, container) do
    validate_graph!(potential)
    validate_graph!(container)
    validate_same_kind!(potential, container)

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

  Both graphs must have the same kind (`:directed` or `:undirected`).

  **Time Complexity:** Exponential in worst case due to backtracking.

  ## Errors

  - Raises `ArgumentError` if input graphs have different kinds.
  """
  @spec isomorphic?(Graph.t(), Graph.t()) :: boolean()
  def isomorphic?(first, second) do
    validate_graph!(first)
    validate_graph!(second)
    validate_same_kind!(first, second)

    first_order = map_size(first.nodes)
    second_order = map_size(second.nodes)

    if first_order != second_order do
      false
    else
      first_edges = Graph.edge_count(first)
      second_edges = Graph.edge_count(second)

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

  defp validate_graph!(%Graph{}), do: :ok

  defp validate_graph!(other) do
    raise ArgumentError, "expected a Yog.Graph struct, got: #{inspect(other)}"
  end

  defp validate_same_kind!(g1, g2) do
    if g1.kind != g2.kind do
      raise ArgumentError,
            "Cannot perform operation on graphs of different kinds: #{g1.kind} and #{g2.kind}"
    end
  end

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

  defp add_tagged_component(target_graph, source_graph, tag) do
    target_graph =
      Utils.map_fold(source_graph.nodes, target_graph, fn node_id, data, acc ->
        Yog.add_node(acc, {tag, node_id}, data)
      end)

    is_directed = source_graph.kind == :directed

    Utils.map_fold(source_graph.out_edges, target_graph, fn u, dests, acc_outer ->
      Utils.map_fold(dests, acc_outer, fn v, data, acc ->
        if is_directed or u <= v do
          {:ok, new_g} = Yog.add_edge(acc, {tag, u}, {tag, v}, data)
          new_g
        else
          acc
        end
      end)
    end)
  end

  defp add_product_nodes(init_graph, first, second, u_map, v_map, second_order) do
    Utils.map_fold(first.nodes, init_graph, fn u, u_data, g_acc ->
      u_idx = Map.fetch!(u_map, u)

      Utils.map_fold(second.nodes, g_acc, fn v, v_data, g ->
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
    List.foldl(Map.keys(first.nodes), graph, fn u, g_acc ->
      u_idx = Map.fetch!(u_map, u)

      Utils.map_fold(second.out_edges, g_acc, fn v, edges, g ->
        v_idx = Map.fetch!(v_map, v)

        Utils.map_fold(edges, g, fn v_succ, weight, g_inner ->
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
    List.foldl(Map.keys(second.nodes), graph, fn v, g_acc ->
      v_idx = Map.fetch!(v_map, v)

      Utils.map_fold(first.out_edges, g_acc, fn u, edges, g ->
        u_idx = Map.fetch!(u_map, u)

        Utils.map_fold(edges, g, fn u_succ, weight, g_inner ->
          u_succ_idx = Map.fetch!(u_map, u_succ)
          src_id = u_idx * second_order + v_idx
          dst_id = u_succ_idx * second_order + v_idx
          {:ok, new_g} = Yog.add_edge(g_inner, src_id, dst_id, {weight, default_first})
          new_g
        end)
      end)
    end)
  end

  defp add_tensor_edges(graph, first, second, u_map, v_map, second_order) do
    is_directed = first.kind == :directed

    Utils.map_fold(first.out_edges, graph, fn u, u_edges, g_acc ->
      u_idx = Map.fetch!(u_map, u)

      Utils.map_fold(u_edges, g_acc, fn u_succ, w_first, g ->
        u_succ_idx = Map.fetch!(u_map, u_succ)

        if is_directed or u <= u_succ do
          Utils.map_fold(second.out_edges, g, fn v, v_edges, g_inner ->
            v_idx = Map.fetch!(v_map, v)

            Utils.map_fold(v_edges, g_inner, fn v_succ, w_second, g_edge ->
              v_succ_idx = Map.fetch!(v_map, v_succ)
              src_id = u_idx * second_order + v_idx
              dst_id = u_succ_idx * second_order + v_succ_idx

              {:ok, new_g} = Yog.add_edge(g_edge, src_id, dst_id, {w_first, w_second})
              new_g
            end)
          end)
        else
          g
        end
      end)
    end)
  end

  defp add_lexicographic_horizontal_edges(
         graph,
         first,
         second,
         u_map,
         v_map,
         second_order,
         default_first
       ) do
    is_directed = first.kind == :directed
    second_nodes = Map.keys(second.nodes)

    Utils.map_fold(first.out_edges, graph, fn u, u_edges, g_acc ->
      u_idx = Map.fetch!(u_map, u)

      Utils.map_fold(u_edges, g_acc, fn u_succ, w_first, g ->
        u_succ_idx = Map.fetch!(u_map, u_succ)

        if is_directed or u <= u_succ do
          List.foldl(second_nodes, g, fn u2, g_inner ->
            u2_idx = Map.fetch!(v_map, u2)
            src_id = u_idx * second_order + u2_idx

            List.foldl(second_nodes, g_inner, fn v2, g_edge ->
              v2_idx = Map.fetch!(v_map, v2)
              dst_id = u_succ_idx * second_order + v2_idx

              {:ok, new_g} = Yog.add_edge(g_edge, src_id, dst_id, {w_first, default_first})
              new_g
            end)
          end)
        else
          g
        end
      end)
    end)
  end

  defp extract_edges_for_line_graph(graph) do
    if graph.kind == :undirected do
      Utils.map_fold(graph.out_edges, [], fn u, inner, acc ->
        Utils.map_fold(inner, acc, fn v, w, inner_acc ->
          if u <= v do
            [{u, v, w} | inner_acc]
          else
            inner_acc
          end
        end)
      end)
    else
      Utils.map_fold(graph.out_edges, [], fn u, inner, acc ->
        Utils.map_fold(inner, acc, fn v, w, inner_acc ->
          [{u, v, w} | inner_acc]
        end)
      end)
    end
  end

  defp connect_line_graph(lg, graph, edges, :directed, default_weight) do
    List.foldl(edges, lg, fn {u, v, _w}, acc ->
      v_successors = Yog.successors(graph, v)

      List.foldl(v_successors, acc, fn {y, _w2}, inner_acc ->
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

    List.foldl(nodes, lg, fn node, acc ->
      neighbors = Yog.neighbors(graph, node)

      incident_edges =
        List.foldl(neighbors, [], fn {succ, _weight}, acc_edges ->
          edge = if node <= succ, do: {node, succ}, else: {succ, node}
          [edge | acc_edges]
        end)
        |> Enum.sort()

      connect_incident_pairs(incident_edges, acc, default_weight)
    end)
  end

  defp connect_incident_pairs([], acc, _weight), do: acc

  defp connect_incident_pairs([e1 | rest], acc, weight) do
    new_acc =
      List.foldl(rest, acc, fn e2, inner_acc ->
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

  defp degree_sequence(graph) do
    Enum.map(Map.keys(graph.nodes), fn node ->
      {in_degree(graph, node), out_degree(graph, node)}
    end)
  end

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

  defp mapping_valid?(first, second, src, candidate, mapping) do
    src_succs = Map.get(first.out_edges, src, %{})
    cand_succs = Map.get(second.out_edges, candidate, %{})

    consistent_out =
      Enum.all?(mapping, fn {s, c} ->
        Map.has_key?(src_succs, s) == Map.has_key?(cand_succs, c)
      end)

    src_preds = Map.get(first.in_edges, src, %{})
    cand_preds = Map.get(second.in_edges, candidate, %{})

    consistent_in =
      Enum.all?(mapping, fn {s, c} ->
        Map.has_key?(src_preds, s) == Map.has_key?(cand_preds, c)
      end)

    consistent_out and consistent_in
  end
end
