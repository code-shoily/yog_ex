defmodule Yog.Multi.Model do
  @moduledoc """
  Core multigraph type and basic operations.

  A multigraph allows multiple (parallel) edges between the same pair of nodes.
  Both directed and undirected variants are supported.

  The internal representation keeps three indexes:
  - `edges`: EdgeId → {from, to, data} — canonical edge store
  - `out_edge_ids`: NodeId → [EdgeId] — outgoing edges per node
  - `in_edge_ids`: NodeId → [EdgeId] — incoming edges per node

  All operations in this module work on `Yog.Multi.Graph` structs.
  """

  alias Yog.Multi.Graph

  @type t :: Graph.t()
  @type edge_id :: Graph.edge_id()

  # ============================================================
  # Construction
  # ============================================================

  @doc """
  Creates a new, empty multigraph of the given type.
  """
  @spec new(Yog.graph_type()) :: t()
  def new(graph_type), do: Graph.new(graph_type)

  @doc """
  Creates a new, empty directed multigraph.
  """
  @spec directed() :: t()
  def directed, do: Graph.directed()

  @doc """
  Creates a new, empty undirected multigraph.
  """
  @spec undirected() :: t()
  def undirected, do: Graph.undirected()

  # ============================================================
  # Node Operations
  # ============================================================

  @doc """
  Adds a node with the given ID and data.
  If the node already exists, its data is replaced (edges are unaffected).
  """
  @spec add_node(t(), Yog.Model.node_id(), any()) :: t()
  def add_node(graph, id, data) do
    %{graph | nodes: Map.put(graph.nodes, id, data)}
  end

  @doc """
  Removes a node and all edges connected to it.
  """
  @spec remove_node(t(), Yog.Model.node_id()) :: t()
  def remove_node(graph, id) do
    out_ids = Map.get(graph.out_edge_ids, id, MapSet.new())
    in_ids = Map.get(graph.in_edge_ids, id, MapSet.new())
    ids_to_remove = MapSet.union(out_ids, in_ids)

    graph = Enum.reduce(ids_to_remove, graph, fn eid, g -> do_remove_edge(g, eid) end)

    %{
      graph
      | nodes: Map.delete(graph.nodes, id),
        out_edge_ids: Map.delete(graph.out_edge_ids, id),
        in_edge_ids: Map.delete(graph.in_edge_ids, id)
    }
  end

  @doc """
  Returns all node IDs in the multigraph.
  """
  @spec all_nodes(t()) :: [Yog.Model.node_id()]
  def all_nodes(graph), do: Map.keys(graph.nodes)

  @doc """
  Returns the number of nodes (graph order).
  """
  @spec order(t()) :: integer()
  def order(graph), do: map_size(graph.nodes)

  # ============================================================
  # Edge Operations
  # ============================================================

  @doc """
  Adds an edge from `from` to `to` with the given data.

  Returns `{updated_graph, new_edge_id}`.

  For undirected graphs, a single `EdgeId` is issued and the reverse
  direction is indexed automatically.
  """
  @spec add_edge(t(), Yog.Model.node_id(), Yog.Model.node_id(), any()) :: {t(), edge_id()}
  def add_edge(graph, from, to, data) do
    eid = graph.next_edge_id
    new_edges = Map.put(graph.edges, eid, {from, to, data})

    new_out =
      Map.update(graph.out_edge_ids, from, MapSet.new([eid]), fn ids -> MapSet.put(ids, eid) end)

    new_in =
      Map.update(graph.in_edge_ids, to, MapSet.new([eid]), fn ids -> MapSet.put(ids, eid) end)

    # For undirected graphs, also index the reverse direction
    {new_out2, new_in2} =
      case graph.kind do
        :directed ->
          {new_out, new_in}

        :undirected ->
          rev_out =
            Map.update(new_out, to, MapSet.new([eid]), fn ids -> MapSet.put(ids, eid) end)

          rev_in =
            Map.update(new_in, from, MapSet.new([eid]), fn ids -> MapSet.put(ids, eid) end)

          {rev_out, rev_in}
      end

    updated = %{
      graph
      | edges: new_edges,
        out_edge_ids: new_out2,
        in_edge_ids: new_in2,
        next_edge_id: eid + 1
    }

    {updated, eid}
  end

  @doc """
  Removes a single edge by its `EdgeId`.
  For undirected graphs, both direction-index entries are removed.
  """
  @spec remove_edge(t(), edge_id()) :: t()
  def remove_edge(graph, edge_id) do
    do_remove_edge(graph, edge_id)
  end

  @doc """
  Returns `true` if an edge with this ID exists in the graph.
  """
  @spec has_edge(t(), edge_id()) :: boolean()
  def has_edge(graph, edge_id) do
    Map.has_key?(graph.edges, edge_id)
  end

  @doc """
  Returns all edge IDs in the graph.
  """
  @spec all_edge_ids(t()) :: [edge_id()]
  def all_edge_ids(graph), do: Map.keys(graph.edges)

  @doc """
  Returns the total number of edges (graph size).
  For undirected graphs, each physical edge is counted once.
  """
  @spec size(t()) :: integer()
  def size(graph), do: map_size(graph.edges)

  @doc """
  Returns all parallel edges between `from` and `to` as
  `[{edge_id, edge_data}]`.
  """
  @spec edges_between(t(), Yog.Model.node_id(), Yog.Model.node_id()) :: [{edge_id(), any()}]
  def edges_between(graph, from, to) do
    edge_ids = Map.get(graph.out_edge_ids, from, MapSet.new())

    for eid <- edge_ids,
        {:ok, {_, ^to, data}} <- [Map.fetch(graph.edges, eid)],
        do: {eid, data}
  end

  @doc """
  Returns the number of parallel edges between two nodes.
  """
  @spec edge_count(t(), Yog.Model.node_id(), Yog.Model.node_id()) :: non_neg_integer()
  def edge_count(graph, from, to) do
    graph
    |> edges_between(from, to)
    |> Kernel.length()
  end

  @doc """
  Returns all outgoing edges from `id` as `[{to_node, edge_id, edge_data}]`.
  """
  @spec successors(t(), Yog.Model.node_id()) :: [{Yog.Model.node_id(), edge_id(), any()}]
  def successors(graph, id) do
    edge_ids = Map.get(graph.out_edge_ids, id, MapSet.new())

    Enum.reduce(edge_ids, [], fn eid, acc ->
      case Map.fetch(graph.edges, eid) do
        {:ok, {^id, dst, data}} -> [{dst, eid, data} | acc]
        {:ok, {src, ^id, data}} when graph.kind == :undirected -> [{src, eid, data} | acc]
        _ -> acc
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Returns all incoming edges to `id` as `[{from_node, edge_id, edge_data}]`.
  """
  @spec predecessors(t(), Yog.Model.node_id()) :: [{Yog.Model.node_id(), edge_id(), any()}]
  def predecessors(graph, id) do
    edge_ids = Map.get(graph.in_edge_ids, id, MapSet.new())

    Enum.reduce(edge_ids, [], fn eid, acc ->
      case Map.fetch(graph.edges, eid) do
        {:ok, {src, ^id, data}} -> [{src, eid, data} | acc]
        {:ok, {^id, dst, data}} when graph.kind == :undirected -> [{dst, eid, data} | acc]
        _ -> acc
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Returns the out-degree of a node (number of outgoing edges).
  For undirected graphs, this equals the total degree.
  """
  @spec out_degree(t(), Yog.Model.node_id()) :: integer()
  def out_degree(graph, id) do
    MapSet.size(Map.get(graph.out_edge_ids, id, MapSet.new()))
  end

  @doc """
  Returns the in-degree of a node (number of incoming edges).
  """
  @spec in_degree(t(), Yog.Model.node_id()) :: integer()
  def in_degree(graph, id) do
    MapSet.size(Map.get(graph.in_edge_ids, id, MapSet.new()))
  end

  # ============================================================
  # Conversion
  # ============================================================

  @doc """
  Collapses the multigraph into a simple `Yog.graph()` by combining
  parallel edges with `combine_fn(existing, new)`.

  ## Example

  Keep minimum weight among parallel edges:

      multi.to_simple_graph(mg, fn a, b -> min(a, b) end)
  """
  @spec to_simple_graph(t(), (any(), any() -> any())) :: Yog.graph()
  def to_simple_graph(graph, combine_fn) do
    base_graph =
      Enum.reduce(graph.nodes, Yog.Model.new(graph.kind), fn {id, data}, g ->
        Yog.Model.add_node(g, id, data)
      end)

    Enum.reduce(graph.edges, base_graph, fn {_eid, {src, dst, data}}, current_graph ->
      Yog.Model.add_edge_with_combine!(current_graph, src, dst, data, combine_fn)
    end)
  end

  @doc """
  Converts the multigraph to a simple graph.
  When there are parallel edges, only the first edge is kept.
  """
  @spec to_simple_graph(t()) :: Yog.graph()
  def to_simple_graph(graph) do
    base_graph =
      Enum.reduce(graph.nodes, Yog.Model.new(graph.kind), fn {id, data}, g ->
        Yog.Model.add_node(g, id, data)
      end)

    seen = MapSet.new()

    Enum.reduce(graph.edges, {base_graph, seen}, fn {_eid, {src, dst, data}}, {g, seen_acc} ->
      key = if graph.kind == :undirected and src > dst, do: {dst, src}, else: {src, dst}

      if MapSet.member?(seen_acc, key) do
        {g, seen_acc}
      else
        new_g = Yog.Model.add_edge!(g, src, dst, data)
        {new_g, MapSet.put(seen_acc, key)}
      end
    end)
    |> elem(0)
  end

  @doc """
  Collapses parallel edges, keeping the minimum weight.
  """
  @spec to_simple_graph_min_edges(t()) :: Yog.graph()
  def to_simple_graph_min_edges(graph) do
    to_simple_graph(graph, fn a, b ->
      if is_number(a) and is_number(b), do: min(a, b), else: a
    end)
  end

  @doc """
  Collapses parallel edges, summing weights.
  """
  @spec to_simple_graph_sum_edges(t(), (any(), any() -> any())) :: Yog.graph()
  def to_simple_graph_sum_edges(graph, add) do
    to_simple_graph(graph, add)
  end

  @doc """
  Backward compatibility: convert from legacy map format.
  """
  @spec from_map(map()) :: t()
  def from_map(%{kind: k, nodes: n, edges: e} = map) do
    next_id = Map.get(map, :next_edge_id, 0)

    %Graph{
      kind: k,
      nodes: n,
      edges: e,
      out_edge_ids: Map.get(map, :out_edge_ids, %{}),
      in_edge_ids: Map.get(map, :in_edge_ids, %{}),
      next_edge_id: next_id
    }
  end

  @doc """
  Convert to legacy map format.
  """
  @spec to_map(t()) :: map()
  def to_map(%Graph{} = graph) do
    %{
      kind: graph.kind,
      nodes: graph.nodes,
      edges: graph.edges,
      out_edge_ids: graph.out_edge_ids,
      in_edge_ids: graph.in_edge_ids,
      next_edge_id: graph.next_edge_id
    }
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp do_remove_edge(graph, eid) do
    case Map.fetch(graph.edges, eid) do
      :error ->
        graph

      {:ok, {src, dst, _}} ->
        new_edges = Map.delete(graph.edges, eid)

        remove_id = fn maybe_ids ->
          MapSet.delete(maybe_ids || MapSet.new(), eid)
        end

        new_out = Map.update(graph.out_edge_ids, src, MapSet.new(), remove_id)
        new_in = Map.update(graph.in_edge_ids, dst, MapSet.new(), remove_id)

        {new_out2, new_in2} =
          case graph.kind do
            :directed ->
              {new_out, new_in}

            :undirected ->
              rev_out = Map.update(new_out, dst, MapSet.new(), remove_id)
              rev_in = Map.update(new_in, src, MapSet.new(), remove_id)
              {rev_out, rev_in}
          end

        %{
          graph
          | edges: new_edges,
            out_edge_ids: new_out2,
            in_edge_ids: new_in2
        }
    end
  end
end
