defmodule Yog.Multi.Model do
  @moduledoc """
  Core multigraph data model and primitive operations.

  A multigraph allows multiple (parallel) edges between the same pair of nodes.
  Both directed and undirected variants are supported.

  The internal representation maintains three synchronized indexes:
  - `nodes`: NodeId → Data
  - `edges`: EdgeId → {from, to, data} — canonical edge store
  - `out_edge_ids`: NodeId → MapSet[EdgeId] — outgoing edge IDs per node
  - `in_edge_ids`: NodeId → MapSet[EdgeId] — incoming edge IDs per node

  All operations in this module operate on `%Yog.Multi.Graph{}` structs.

  ## Edge IDs

  Every edge added to a multigraph is assigned a unique, sequential non-negative integer
  `EdgeId` (starting from `0`). For undirected graphs, a single `EdgeId` is generated, and
  the edge is indexed in both directions.

  ## Complexity Summary

  - Node additions / queries / lookups: $\\mathcal{O}(1)$ time.
  - Edge additions / removals: $\\mathcal{O}(1)$ time.
  - Successors / predecessors / edges between nodes: $\\mathcal{O}(\\text{deg}(v))$ time.
  - Collapsing multigraph to simple graph: $\\mathcal{O}(V + E \\log E)$ time.
  """

  alias Yog.Multi.Graph

  @type t :: Graph.t()
  @type edge_id :: Graph.edge_id()

  # ============================================================
  # Construction
  # ============================================================

  @doc """
  Creates a new, empty multigraph of the given type (`:directed` or `:undirected`).

  **Time Complexity:** $\\mathcal{O}(1)$

  ## Examples

      iex> graph = Yog.Multi.Model.new(:directed)
      iex> Yog.Multi.Model.type(graph)
      :directed

      iex> graph = Yog.Multi.Model.new(:undirected)
      iex> Yog.Multi.Model.type(graph)
      :undirected

  ## Errors

  - Raises `ArgumentError` if `graph_type` is not `:directed` or `:undirected`.
  """
  @spec new(Yog.graph_type()) :: t()
  def new(graph_type) do
    unless graph_type in [:directed, :undirected] do
      raise ArgumentError,
            "Invalid graph type: #{inspect(graph_type)}. Expected :directed or :undirected"
    end

    Graph.new(graph_type)
  end

  @doc """
  Creates a new, empty directed multigraph.

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec directed() :: t()
  def directed, do: Graph.directed()

  @doc """
  Creates a new, empty undirected multigraph.

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec undirected() :: t()
  def undirected, do: Graph.undirected()

  @doc """
  Returns the type of the multigraph (`:directed` or `:undirected`).

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec type(t()) :: Yog.graph_type()
  def type(graph) do
    validate_graph!(graph)
    graph.kind
  end

  @doc """
  Synonym for `type/1`. Returns the graph kind (`:directed` or `:undirected`).
  """
  @spec kind(t()) :: Yog.graph_type()
  def kind(graph), do: type(graph)

  # ============================================================
  # Node Operations
  # ============================================================

  @doc """
  Adds a node with the given ID and data.
  If the node already exists, its data is updated while preserving all incident edges.

  **Time Complexity:** $\\mathcal{O}(1)$

  ## Parameters

  - `graph` - Multigraph struct
  - `id` - Node ID
  - `data` - Custom data associated with the node (default: `nil`)

  ## Errors

  - Raises `ArgumentError` if `graph` is not a `%Yog.Multi.Graph{}` struct.
  """
  @spec add_node(t(), Yog.Model.node_id(), any()) :: t()
  def add_node(graph, id, data \\ nil) do
    validate_graph!(graph)
    %{graph | nodes: Map.put(graph.nodes, id, data)}
  end

  @doc """
  Returns `true` if the node exists in the multigraph.

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec has_node?(t(), Yog.Model.node_id()) :: boolean()
  def has_node?(graph, id) do
    validate_graph!(graph)
    Map.has_key?(graph.nodes, id)
  end

  @doc """
  Returns the data associated with a node, or `nil` if the node does not exist.

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec node(t(), Yog.Model.node_id()) :: any()
  def node(graph, id) do
    validate_graph!(graph)
    Map.get(graph.nodes, id)
  end

  @doc """
  Fetches node data for the given node ID.
  Returns `{:ok, data}` if the node exists, or `:error` otherwise.

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec fetch_node(t(), Yog.Model.node_id()) :: {:ok, any()} | :error
  def fetch_node(graph, id) do
    validate_graph!(graph)
    Map.fetch(graph.nodes, id)
  end

  @doc """
  Synonym for `node/2`. Returns data associated with the given node.
  """
  @spec node_data(t(), Yog.Model.node_id()) :: any()
  def node_data(graph, id), do: node(graph, id)

  @doc """
  Removes a node and all incident edges connected to it.

  **Time Complexity:** $\\mathcal{O}(\\text{deg}(v))$

  ## Examples

      iex> multi = Yog.Multi.directed() |> Yog.Multi.add_node(1, "A")
      iex> multi = Yog.Multi.remove_node(multi, 1)
      iex> Yog.Multi.order(multi)
      0
  """
  @spec remove_node(t(), Yog.Model.node_id()) :: t()
  def remove_node(graph, id) do
    validate_graph!(graph)

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

  **Time Complexity:** $\\mathcal{O}(V)$
  """
  @spec all_nodes(t()) :: [Yog.Model.node_id()]
  def all_nodes(graph) do
    validate_graph!(graph)
    Map.keys(graph.nodes)
  end

  @doc """
  Returns the number of nodes in the multigraph (graph order).

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec order(t()) :: non_neg_integer()
  def order(graph) do
    validate_graph!(graph)
    map_size(graph.nodes)
  end

  @doc """
  Synonym for `order/1`. Returns the number of nodes in the multigraph.

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec node_count(t()) :: non_neg_integer()
  def node_count(graph), do: order(graph)

  # ============================================================
  # Edge Operations
  # ============================================================

  @doc """
  Adds an edge from `from` to `to` with the given data payload.

  Returns `{updated_graph, new_edge_id}`.

  If `from` or `to` nodes do not already exist in the graph, they are created automatically
  with `nil` default data.

  For undirected graphs, a single `EdgeId` is generated and indexed for both directions.

  **Time Complexity:** $\\mathcal{O}(1)$

  ## Examples

      iex> multi = Yog.Multi.directed()
      iex> {multi, eid} = Yog.Multi.Model.add_edge(multi, 1, 2, "link")
      iex> eid
      0
      iex> Yog.Multi.Model.has_edge(multi, 0)
      true
  """
  @spec add_edge(t(), Yog.Model.node_id(), Yog.Model.node_id(), any()) :: {t(), edge_id()}
  def add_edge(graph, from, to, data) do
    validate_graph!(graph)

    eid = graph.next_edge_id

    # Automatically ensure endpoint nodes exist
    nodes =
      graph.nodes
      |> Map.put_new(from, nil)
      |> Map.put_new(to, nil)

    new_edges = Map.put(graph.edges, eid, {from, to, data})

    new_out =
      Map.update(graph.out_edge_ids, from, MapSet.new([eid]), fn ids -> MapSet.put(ids, eid) end)

    new_in =
      Map.update(graph.in_edge_ids, to, MapSet.new([eid]), fn ids -> MapSet.put(ids, eid) end)

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
      | nodes: nodes,
        edges: new_edges,
        out_edge_ids: new_out2,
        in_edge_ids: new_in2,
        next_edge_id: eid + 1
    }

    {updated, eid}
  end

  @doc """
  Removes a single edge by its `EdgeId`.

  If the edge ID does not exist, the graph is returned unchanged.
  For undirected graphs, both direction indexes are cleaned up.

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec remove_edge(t(), edge_id()) :: t()
  def remove_edge(graph, edge_id) do
    validate_graph!(graph)
    do_remove_edge(graph, edge_id)
  end

  @doc """
  Returns `true` if an edge with the specified `EdgeId` exists.

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec has_edge(t(), edge_id()) :: boolean()
  def has_edge(graph, edge_id) do
    validate_graph!(graph)
    Map.has_key?(graph.edges, edge_id)
  end

  @doc """
  Predicate synonym for `has_edge/2`. Returns `true` if edge ID exists.
  """
  @spec has_edge?(t(), edge_id()) :: boolean()
  def has_edge?(graph, edge_id), do: has_edge(graph, edge_id)

  @doc """
  Fetches details for the specified `EdgeId`.
  Returns `{:ok, {from, to, data}}` if found, or `:error` otherwise.

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec fetch_edge(t(), edge_id()) ::
          {:ok, {Yog.Model.node_id(), Yog.Model.node_id(), any()}} | :error
  def fetch_edge(graph, edge_id) do
    validate_graph!(graph)
    Map.fetch(graph.edges, edge_id)
  end

  @doc """
  Returns the `{from, to, data}` tuple for the specified `EdgeId`, or `nil` if not found.

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec edge(t(), edge_id()) :: {Yog.Model.node_id(), Yog.Model.node_id(), any()} | nil
  def edge(graph, edge_id) do
    case fetch_edge(graph, edge_id) do
      {:ok, info} -> info
      :error -> nil
    end
  end

  @doc """
  Returns edge data for the specified `EdgeId`, or `nil` if not found.

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec edge_data(t(), edge_id()) :: any()
  def edge_data(graph, edge_id) do
    case fetch_edge(graph, edge_id) do
      {:ok, {_from, _to, data}} -> data
      :error -> nil
    end
  end

  @doc """
  Returns `true` if there is at least one edge between `from` and `to`.

  **Time Complexity:** $\\mathcal{O}(\\text{deg}(from))$
  """
  @spec has_edge_between?(t(), Yog.Model.node_id(), Yog.Model.node_id()) :: boolean()
  def has_edge_between?(graph, from, to) do
    edge_count(graph, from, to) > 0
  end

  @doc """
  Synonym for `has_edge_between?/3`.
  """
  @spec has_edge_between(t(), Yog.Model.node_id(), Yog.Model.node_id()) :: boolean()
  def has_edge_between(graph, from, to), do: has_edge_between?(graph, from, to)

  @doc """
  Returns all edge IDs in the multigraph.

  **Time Complexity:** $\\mathcal{O}(E)$
  """
  @spec all_edge_ids(t()) :: [edge_id()]
  def all_edge_ids(graph) do
    validate_graph!(graph)
    Map.keys(graph.edges)
  end

  @doc """
  Returns all edges in the multigraph as `[{edge_id, from, to, data}]` sorted by `edge_id`.

  **Time Complexity:** $\\mathcal{O}(E \\log E)$

  ## Examples

      iex> multi = Yog.Multi.directed()
      ...> {multi, _e1} = Yog.Multi.Model.add_edge(multi, 1, 2, "a")
      iex> Yog.Multi.Model.all_edges(multi)
      [{0, 1, 2, "a"}]
  """
  @spec all_edges(t()) :: [{edge_id(), Yog.Model.node_id(), Yog.Model.node_id(), any()}]
  def all_edges(graph) do
    validate_graph!(graph)

    graph.edges
    |> Enum.sort_by(fn {eid, _} -> eid end)
    |> Enum.map(fn {eid, {from, to, data}} -> {eid, from, to, data} end)
  end

  @doc """
  Returns the total number of physical edges in the multigraph (graph size).

  **Time Complexity:** $\\mathcal{O}(1)$
  """
  @spec size(t()) :: non_neg_integer()
  def size(graph) do
    validate_graph!(graph)
    map_size(graph.edges)
  end

  @doc """
  Synonym for `size/1`. Returns total number of edges in the multigraph.
  """
  @spec edge_count(t()) :: non_neg_integer()
  def edge_count(graph), do: size(graph)

  @doc """
  Returns all parallel edges between `from` and `to` as `[{edge_id, edge_data}]`.

  **Time Complexity:** $\\mathcal{O}(\\text{deg}(from))$
  """
  @spec edges_between(t(), Yog.Model.node_id(), Yog.Model.node_id()) :: [{edge_id(), any()}]
  def edges_between(graph, from, to) do
    validate_graph!(graph)

    edge_ids = Map.get(graph.out_edge_ids, from, MapSet.new())

    Enum.reduce(edge_ids, [], fn eid, acc ->
      case Map.fetch(graph.edges, eid) do
        {:ok, {^from, ^to, data}} ->
          [{eid, data} | acc]

        {:ok, {^to, ^from, data}} when graph.kind == :undirected ->
          [{eid, data} | acc]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Returns the number of parallel edges between two nodes.

  **Time Complexity:** $\\mathcal{O}(\\text{deg}(from))$
  """
  @spec edge_count(t(), Yog.Model.node_id(), Yog.Model.node_id()) :: non_neg_integer()
  def edge_count(graph, from, to) do
    validate_graph!(graph)

    graph
    |> edges_between(from, to)
    |> Kernel.length()
  end

  @doc """
  Returns all outgoing edges from `id` as `[{to_node, edge_id, edge_data}]`.

  **Time Complexity:** $\\mathcal{O}(\\text{deg}(id))$
  """
  @spec successors(t(), Yog.Model.node_id()) :: [{Yog.Model.node_id(), edge_id(), any()}]
  def successors(graph, id) do
    validate_graph!(graph)

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

  **Time Complexity:** $\\mathcal{O}(\\text{deg}(id))$
  """
  @spec predecessors(t(), Yog.Model.node_id()) :: [{Yog.Model.node_id(), edge_id(), any()}]
  def predecessors(graph, id) do
    validate_graph!(graph)

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
  For undirected graphs, self-loops contribute 2 to degree.

  **Time Complexity:** $\\mathcal{O}(\\text{deg}(id))$
  """
  @spec out_degree(t(), Yog.Model.node_id()) :: non_neg_integer()
  def out_degree(graph, id) do
    validate_graph!(graph)

    base = MapSet.size(Map.get(graph.out_edge_ids, id, MapSet.new()))

    case graph.kind do
      :undirected -> base + count_self_loops(graph, id)
      :directed -> base
    end
  end

  @doc """
  Returns the in-degree of a node (number of incoming edges).
  For undirected graphs, self-loops contribute 2 to degree.

  **Time Complexity:** $\\mathcal{O}(\\text{deg}(id))$
  """
  @spec in_degree(t(), Yog.Model.node_id()) :: non_neg_integer()
  def in_degree(graph, id) do
    validate_graph!(graph)

    base = MapSet.size(Map.get(graph.in_edge_ids, id, MapSet.new()))

    case graph.kind do
      :undirected -> base + count_self_loops(graph, id)
      :directed -> base
    end
  end

  @doc """
  Returns the total degree of a node.

  - For directed graphs: `in_degree + out_degree`.
  - For undirected graphs: same as `out_degree`.

  Self-loops contribute 2 to degree in undirected graphs (standard graph theory convention)
  and 1 to each of in-degree and out-degree in directed graphs.

  **Time Complexity:** $\\mathcal{O}(\\text{deg}(id))$
  """
  @spec degree(t(), Yog.Model.node_id()) :: non_neg_integer()
  def degree(graph, id) do
    validate_graph!(graph)

    if graph.kind == :undirected do
      out_degree(graph, id)
    else
      in_degree(graph, id) + out_degree(graph, id)
    end
  end

  # ============================================================
  # Conversion / Collapsing
  # ============================================================

  @doc """
  Collapses the multigraph into a simple `Yog.graph()` by combining
  parallel edges with `combine_fn(existing_data, new_data)`.

  **Time Complexity:** $\\mathcal{O}(V + E)$

  ## Errors

  - Raises `ArgumentError` if `combine_fn` is not an arity-2 function.

  ## Example

  Keep minimum weight among parallel edges:

      to_simple_graph(mg, fn a, b -> min(a, b) end)
  """
  @spec to_simple_graph(t(), (any(), any() -> any())) :: Yog.graph()
  def to_simple_graph(graph, combine_fn) do
    validate_graph!(graph)

    if not is_function(combine_fn, 2) do
      raise ArgumentError,
            "expected combine_fn to be an arity-2 function, got: #{inspect(combine_fn)}"
    end

    base_graph =
      Enum.reduce(graph.nodes, Yog.Model.new(graph.kind), fn {id, data}, g ->
        Yog.Model.add_node(g, id, data)
      end)

    Enum.reduce(graph.edges, base_graph, fn {_eid, {src, dst, data}}, current_graph ->
      Yog.Model.add_edge_with_combine!(current_graph, src, dst, data, combine_fn)
    end)
  end

  @doc """
  Converts the multigraph to a simple graph deterministically.

  When there are parallel edges, the edge with the lowest `edge_id` (the first added edge)
  is preserved.

  **Time Complexity:** $\\mathcal{O}(V + E \\log E)$
  """
  @spec to_simple_graph(t()) :: Yog.graph()
  def to_simple_graph(graph) do
    validate_graph!(graph)

    base_graph =
      Enum.reduce(graph.nodes, Yog.Model.new(graph.kind), fn {id, data}, g ->
        Yog.Model.add_node(g, id, data)
      end)

    seen = MapSet.new()

    graph.edges
    |> Enum.sort_by(fn {eid, _} -> eid end)
    |> Enum.reduce({base_graph, seen}, fn {_eid, {src, dst, data}}, {g, seen_acc} ->
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
  Collapses parallel edges, keeping the minimum numerical weight.

  **Time Complexity:** $\\mathcal{O}(V + E)$
  """
  @spec to_simple_graph_min_edges(t()) :: Yog.graph()
  def to_simple_graph_min_edges(graph) do
    to_simple_graph(graph, fn a, b ->
      if is_number(a) and is_number(b), do: min(a, b), else: a
    end)
  end

  @doc """
  Collapses parallel edges, summing weights using `&Kernel.+/2`.

  **Time Complexity:** $\\mathcal{O}(V + E)$
  """
  @spec to_simple_graph_sum_edges(t()) :: Yog.graph()
  def to_simple_graph_sum_edges(graph) do
    to_simple_graph(graph, &Kernel.+/2)
  end

  @doc """
  Collapses parallel edges, combining weights with the provided `add` function.

  **Time Complexity:** $\\mathcal{O}(V + E)$
  """
  @spec to_simple_graph_sum_edges(t(), (any(), any() -> any())) :: Yog.graph()
  def to_simple_graph_sum_edges(graph, add) do
    to_simple_graph(graph, add)
  end

  @doc """
  Collapses parallel edges, keeping the maximum numerical weight.

  **Time Complexity:** $\\mathcal{O}(V + E)$
  """
  @spec to_simple_graph_max_edges(t()) :: Yog.graph()
  def to_simple_graph_max_edges(graph) do
    to_simple_graph(graph, fn a, b ->
      if is_number(a) and is_number(b), do: max(a, b), else: a
    end)
  end

  @doc """
  Backward compatibility helper: converts legacy map representation to `%Yog.Multi.Graph{}`.
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
  Converts `%Yog.Multi.Graph{}` to legacy map representation.
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

  defp validate_graph!(%Graph{}), do: :ok

  defp validate_graph!(other) do
    raise ArgumentError, "expected a Yog.Multi.Graph struct, got: #{inspect(other)}"
  end

  defp count_self_loops(graph, id) do
    graph.out_edge_ids
    |> Map.get(id, MapSet.new())
    |> Enum.count(fn eid ->
      case Map.fetch(graph.edges, eid) do
        {:ok, {^id, ^id, _}} -> true
        _ -> false
      end
    end)
  end

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
