defmodule Yog.Multi.Model do
  @moduledoc """
  Core multigraph type and basic operations.

  A multigraph allows multiple (parallel) edges between the same pair of nodes.
  Both directed and undirected variants are supported.

  The internal representation keeps three indices:
  - `edges`: EdgeId → {from, to, data} — canonical edge store
  - `out_edge_ids`: NodeId → [EdgeId] — outgoing edges per node
  - `in_edge_ids`: NodeId → [EdgeId] — incoming edges per node
  """

  @typedoc "Unique identifier for an edge in a multigraph"
  @type edge_id :: integer()

  @typedoc """
  A multigraph that can hold multiple (parallel) edges between nodes.

  - `kind`: Graph type (:directed or :undirected)
  - `nodes`: Map of node_id => node_data
  - `edges`: Map of edge_id => {from, to, edge_data}
  - `out_edge_ids`: Map of node_id => [edge_id]
  - `in_edge_ids`: Map of node_id => [edge_id]
  - `next_edge_id`: Next edge ID to assign
  """
  @type t :: %{
          kind: Yog.graph_type(),
          nodes: %{Yog.node_id() => any()},
          edges: %{edge_id() => {Yog.node_id(), Yog.node_id(), any()}},
          out_edge_ids: %{Yog.node_id() => [edge_id()]},
          in_edge_ids: %{Yog.node_id() => [edge_id()]},
          next_edge_id: edge_id()
        }

  # ============================================================
  # Construction
  # ============================================================

  @doc """
  Creates a new, empty multigraph of the given type.
  """
  @spec new(Yog.graph_type()) :: t()
  def new(graph_type) do
    %{
      kind: graph_type,
      nodes: %{},
      edges: %{},
      out_edge_ids: %{},
      in_edge_ids: %{},
      next_edge_id: 0
    }
  end

  @doc """
  Creates a new, empty directed multigraph.
  """
  @spec directed() :: t()
  def directed, do: new(:directed)

  @doc """
  Creates a new, empty undirected multigraph.
  """
  @spec undirected() :: t()
  def undirected, do: new(:undirected)

  # ============================================================
  # Node Operations
  # ============================================================

  @doc """
  Adds a node with the given ID and data.
  If the node already exists, its data is replaced (edges are unaffected).
  """
  @spec add_node(t(), Yog.node_id(), any()) :: t()
  def add_node(graph, id, data) do
    %{graph | nodes: Map.put(graph.nodes, id, data)}
  end

  @doc """
  Removes a node and all edges connected to it.
  """
  @spec remove_node(t(), Yog.node_id()) :: t()
  def remove_node(graph, id) do
    out_ids = Map.get(graph.out_edge_ids, id, [])
    in_ids = Map.get(graph.in_edge_ids, id, [])
    ids_to_remove = Enum.uniq(out_ids ++ in_ids)

    # Use proper accumulator ordering for reduce
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
  @spec all_nodes(t()) :: [Yog.node_id()]
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
  @spec add_edge(t(), Yog.node_id(), Yog.node_id(), any()) :: {t(), edge_id()}
  def add_edge(graph, from, to, data) do
    eid = graph.next_edge_id
    new_edges = Map.put(graph.edges, eid, {from, to, data})

    new_out =
      Map.update(graph.out_edge_ids, from, [eid], fn ids -> [eid | ids] end)

    new_in =
      Map.update(graph.in_edge_ids, to, [eid], fn ids -> [eid | ids] end)

    # For undirected graphs, also index the reverse direction
    {new_out2, new_in2} =
      case graph.kind do
        :directed ->
          {new_out, new_in}

        :undirected ->
          rev_out =
            Map.update(new_out, to, [eid], fn ids -> [eid | ids] end)

          rev_in =
            Map.update(new_in, from, [eid], fn ids -> [eid | ids] end)

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
  @spec edges_between(t(), Yog.node_id(), Yog.node_id()) :: [{edge_id(), any()}]
  def edges_between(graph, from, to) do
    edge_ids = Map.get(Map.get(graph, :out_edge_ids, %{}), from, [])

    for eid <- edge_ids,
        {:ok, {_, ^to, data}} <- [Map.fetch(graph.edges, eid)],
        do: {eid, data}
  end

  @doc """
  Returns all outgoing edges from `id` as `[{to_node, edge_id, edge_data}]`.
  """
  @spec successors(t(), Yog.node_id()) :: [{Yog.node_id(), edge_id(), any()}]
  def successors(graph, id) do
    edge_ids = Map.get(Map.get(graph, :out_edge_ids, %{}), id, [])

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
  @spec predecessors(t(), Yog.node_id()) :: [{Yog.node_id(), edge_id(), any()}]
  def predecessors(graph, id) do
    edge_ids = Map.get(Map.get(graph, :in_edge_ids, %{}), id, [])

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
  @spec out_degree(t(), Yog.node_id()) :: integer()
  def out_degree(graph, id) do
    length(successors(graph, id))
  end

  @doc """
  Returns the in-degree of a node (number of incoming edges).
  """
  @spec in_degree(t(), Yog.node_id()) :: integer()
  def in_degree(graph, id) do
    length(predecessors(graph, id))
  end

  # ============================================================
  # Conversion
  # ============================================================

  @doc """
  Collapses the multigraph into a simple `Yog.graph()` by combining
  parallel edges with `combine_fn(existing, new)`.

  ## Example

      # Keep minimum weight among parallel edges
      multi.to_simple_graph(mg, fn a, b -> min(a, b) end)
  """
  @spec to_simple_graph(t(), (any(), any() -> any())) :: Yog.graph()
  def to_simple_graph(graph, combine_fn) do
    base =
      Enum.reduce(graph.nodes, %{}, fn {id, data}, g ->
        Map.put(g, id, data)
      end)

    # Build edges map, combining parallel edges
    edges =
      Enum.reduce(graph.edges, %{}, fn {_eid, {src, dst, data}}, acc ->
        key = {src, dst}

        existing = Map.get(acc, key)

        new_data =
          if existing != nil do
            combine_fn.(existing, data)
          else
            data
          end

        Map.put(acc, key, new_data)
      end)

    # Convert to simple graph format
    forward_edges =
      Enum.reduce(edges, %{}, fn {{src, dst}, data}, acc ->
        Map.update(acc, src, %{dst => data}, fn existing ->
          Map.put(existing, dst, data)
        end)
      end)

    reverse_edges =
      Enum.reduce(edges, %{}, fn {{src, dst}, data}, acc ->
        Map.update(acc, dst, %{src => data}, fn existing ->
          Map.put(existing, src, data)
        end)
      end)

    # Return in Erlang-compatible tuple format
    {:graph, graph.kind, base, forward_edges, reverse_edges}
  end

  @doc """
  Collapses parallel edges, keeping the minimum weight.
  """
  @spec to_simple_graph_min_edges(t()) :: Yog.graph()
  def to_simple_graph_min_edges(graph) do
    to_simple_graph(graph, fn a, b ->
      cond do
        is_number(a) and is_number(b) -> min(a, b)
        true -> a
      end
    end)
  end

  @doc """
  Collapses parallel edges, summing weights.
  """
  @spec to_simple_graph_sum_edges(t(), (any(), any() -> any())) :: Yog.graph()
  def to_simple_graph_sum_edges(graph, add) do
    to_simple_graph(graph, add)
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
          List.delete(maybe_ids || [], eid)
        end

        new_out = Map.update(graph.out_edge_ids, src, [], remove_id)
        new_in = Map.update(graph.in_edge_ids, dst, [], remove_id)

        {new_out2, new_in2} =
          case graph.kind do
            :directed ->
              {new_out, new_in}

            :undirected ->
              rev_out = Map.update(new_out, dst, [], remove_id)
              rev_in = Map.update(new_in, src, [], remove_id)
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
