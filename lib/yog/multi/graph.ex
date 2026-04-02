defmodule Yog.Multi.Graph do
  @moduledoc """
  Multigraph with support for parallel edges.

  A multigraph allows multiple edges between the same pair of nodes,
  which is useful for modeling real-world networks like transportation
  systems (multiple routes between cities) or social networks (multiple
  types of relationships).

  ## Fields

  - `kind` - Either `:directed` or `:undirected`
  - `nodes` - Map from node ID to node data
  - `edges` - Map from `{from, to}` to list of edges (parallel edge support)
  - `next_edge_id` - Counter for generating unique edge IDs

  ## Edge Storage

  Each edge in the edges map is stored as a tuple:
  `{edge_id, weight}` where `edge_id` is a unique identifier.

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:undirected)
      iex> multi.kind
      :undirected
      iex> multi.next_edge_id
      0
  """

  @enforce_keys [:kind, :nodes, :edges, :next_edge_id]
  defstruct [:kind, :nodes, :edges, :next_edge_id]

  @type edge_id :: non_neg_integer()
  @type edge_data :: {edge_id(), number()}
  @type edge_key :: {Yog.Model.node_id(), Yog.Model.node_id()}

  @type t :: %__MODULE__{
          kind: :directed | :undirected,
          nodes: %{Yog.Model.node_id() => term()},
          edges: %{edge_key() => [edge_data()]},
          next_edge_id: non_neg_integer()
        }

  @doc """
  Creates a new empty multigraph.

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:directed)
      iex> multi.kind
      :directed
      iex> Enum.count(multi.nodes)
      0

      iex> multi = Yog.Multi.Graph.new(:undirected)
      iex> multi.kind
      :undirected
  """
  @spec new(:directed | :undirected) :: t()
  def new(kind) when kind in [:directed, :undirected] do
    %__MODULE__{
      kind: kind,
      nodes: %{},
      edges: %{},
      next_edge_id: 0
    }
  end

  @doc """
  Adds a node to the multigraph.

  If the node already exists, updates its data.

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:undirected)
      iex> multi = Yog.Multi.Graph.add_node(multi, 1, "node_data")
      iex> Map.has_key?(multi.nodes, 1)
      true
  """
  @spec add_node(t(), Yog.Model.node_id(), term()) :: t()
  def add_node(%__MODULE__{nodes: nodes} = multi, node_id, data) do
    %{multi | nodes: Map.put(nodes, node_id, data)}
  end

  @doc """
  Adds an edge to the multigraph.

  Returns `{:ok, updated_multi, edge_id}` on success.
  Returns `{:error, reason}` if nodes don't exist.

  Parallel edges are allowed - multiple edges can exist between
  the same pair of nodes.

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:undirected)
      iex> multi = Yog.Multi.Graph.add_node(multi, 1, nil)
      iex> multi = Yog.Multi.Graph.add_node(multi, 2, nil)
      iex> {:ok, _multi, edge_id} = Yog.Multi.Graph.add_edge(multi, 1, 2, 10)
      iex> is_integer(edge_id)
      true
  """
  @spec add_edge(t(), Yog.Model.node_id(), Yog.Model.node_id(), number()) ::
          {:ok, t(), edge_id()} | {:error, term()}
  def add_edge(
        %__MODULE__{nodes: nodes, edges: edges, next_edge_id: next_id, kind: kind} = multi,
        from,
        to,
        weight
      ) do
    # Verify both nodes exist
    if Map.has_key?(nodes, from) and Map.has_key?(nodes, to) do
      edge_id = next_id
      edge_key = {from, to}
      new_edge = {edge_id, weight}

      # Add edge to the edges map
      updated_edges =
        Map.update(edges, edge_key, [new_edge], fn existing -> [new_edge | existing] end)

      # For undirected graphs, also add reverse edge
      final_edges =
        if kind == :undirected and from != to do
          reverse_key = {to, from}

          Map.update(updated_edges, reverse_key, [new_edge], fn existing ->
            [new_edge | existing]
          end)
        else
          updated_edges
        end

      updated_multi = %{multi | edges: final_edges, next_edge_id: next_id + 1}
      {:ok, updated_multi, edge_id}
    else
      {:error, :node_not_found}
    end
  end

  @doc """
  Removes a specific edge by its edge ID.

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:undirected)
      iex> multi = Yog.Multi.Graph.add_node(multi, 1, nil)
      iex> multi = Yog.Multi.Graph.add_node(multi, 2, nil)
      iex> {:ok, multi, edge_id} = Yog.Multi.Graph.add_edge(multi, 1, 2, 10)
      iex> multi = Yog.Multi.Graph.remove_edge(multi, 1, 2, edge_id)
      iex> Yog.Multi.Graph.edge_count(multi, 1, 2)
      0
  """
  @spec remove_edge(t(), Yog.Model.node_id(), Yog.Model.node_id(), edge_id()) :: t()
  def remove_edge(%__MODULE__{edges: edges, kind: kind} = multi, from, to, edge_id) do
    edge_key = {from, to}

    # Remove from forward direction
    updated_edges =
      Map.update(edges, edge_key, [], fn edge_list ->
        Enum.reject(edge_list, fn {eid, _} -> eid == edge_id end)
      end)
      |> remove_empty_edge_list(edge_key)

    # For undirected, also remove from reverse direction
    final_edges =
      if kind == :undirected and from != to do
        reverse_key = {to, from}

        Map.update(updated_edges, reverse_key, [], fn edge_list ->
          Enum.reject(edge_list, fn {eid, _} -> eid == edge_id end)
        end)
        |> remove_empty_edge_list(reverse_key)
      else
        updated_edges
      end

    %{multi | edges: final_edges}
  end

  @doc """
  Gets all parallel edges between two nodes.

  Returns a list of `{edge_id, weight}` tuples.

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:undirected)
      iex> multi = Yog.Multi.Graph.add_node(multi, 1, nil)
      iex> multi = Yog.Multi.Graph.add_node(multi, 2, nil)
      iex> {:ok, multi, _} = Yog.Multi.Graph.add_edge(multi, 1, 2, 10)
      iex> edges = Yog.Multi.Graph.get_edges(multi, 1, 2)
      iex> length(edges) >= 1
      true
  """
  @spec get_edges(t(), Yog.Model.node_id(), Yog.Model.node_id()) :: [edge_data()]
  def get_edges(%__MODULE__{edges: edges}, from, to) do
    Map.get(edges, {from, to}, [])
  end

  @doc """
  Counts the number of parallel edges between two nodes.

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:undirected)
      iex> multi = Yog.Multi.Graph.add_node(multi, 1, nil)
      iex> multi = Yog.Multi.Graph.add_node(multi, 2, nil)
      iex> {:ok, multi, _} = Yog.Multi.Graph.add_edge(multi, 1, 2, 10)
      iex> count = Yog.Multi.Graph.edge_count(multi, 1, 2)
      iex> count >= 1
      true
  """
  @spec edge_count(t(), Yog.Model.node_id(), Yog.Model.node_id()) :: non_neg_integer()
  def edge_count(multi, from, to) do
    multi
    |> get_edges(from, to)
    |> Kernel.length()
  end

  @doc """
  Converts the multigraph to a simple graph.

  When there are parallel edges, only the first edge is kept.
  This allows compatibility with algorithms that don't support
  parallel edges.

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:undirected)
      iex> multi = Yog.Multi.Graph.add_node(multi, 1, nil)
      iex> multi = Yog.Multi.Graph.add_node(multi, 2, nil)
      iex> {:ok, multi, _} = Yog.Multi.Graph.add_edge(multi, 1, 2, 10)
      iex> {:ok, multi, _} = Yog.Multi.Graph.add_edge(multi, 1, 2, 20)
      iex> _simple = Yog.Multi.Graph.to_simple_graph(multi)
      iex> # simple graph will have only one edge between 1 and 2
  """
  @spec to_simple_graph(t()) :: Yog.graph()
  def to_simple_graph(%__MODULE__{kind: kind, nodes: nodes, edges: edges}) do
    # Create base graph
    base_graph =
      case kind do
        :directed -> Yog.directed()
        :undirected -> Yog.undirected()
      end

    # Add all nodes
    graph_with_nodes =
      Enum.reduce(nodes, base_graph, fn {node_id, data}, g ->
        Yog.add_node(g, node_id, data)
      end)

    # Add edges (keeping only first edge for each pair)
    Enum.reduce(edges, graph_with_nodes, fn {{from, to}, edge_list}, g ->
      case edge_list do
        [] ->
          g

        [{_edge_id, weight} | _rest] ->
          # For undirected graphs, only process edge once (from <= to)
          if kind == :undirected and from > to do
            g
          else
            case Yog.Model.add_edge(g, from, to, weight) do
              {:ok, new_g} -> new_g
              {:error, _} -> g
            end
          end
      end
    end)
  end

  @doc """
  Converts to a simple graph, aggregating parallel edges using a combining function.

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:undirected)
      iex> multi = Yog.Multi.Graph.add_node(multi, 1, nil)
      iex> multi = Yog.Multi.Graph.add_node(multi, 2, nil)
      iex> {:ok, multi, _} = Yog.Multi.Graph.add_edge(multi, 1, 2, 10)
      iex> {:ok, multi, _} = Yog.Multi.Graph.add_edge(multi, 1, 2, 20)
      iex> simple = Yog.Multi.Graph.to_simple_graph_with(multi, &Kernel.+/2)
      iex> Yog.Model.has_edge?(simple, 1, 2)
      true
  """
  @spec to_simple_graph_with(t(), (number(), number() -> number())) :: Yog.graph()
  def to_simple_graph_with(%__MODULE__{kind: kind, nodes: nodes, edges: edges}, combine_fn)
      when is_function(combine_fn, 2) do
    # Create base graph
    base_graph =
      case kind do
        :directed -> Yog.directed()
        :undirected -> Yog.undirected()
      end

    # Add all nodes
    graph_with_nodes =
      Enum.reduce(nodes, base_graph, fn {node_id, data}, g ->
        Yog.add_node(g, node_id, data)
      end)

    # Add edges, combining weights
    Enum.reduce(edges, graph_with_nodes, fn {{from, to}, edge_list}, g ->
      # For undirected graphs, only process edge once (from <= to)
      if kind == :undirected and from > to do
        g
      else
        combined_weight =
          edge_list
          |> Enum.map(fn {_id, weight} -> weight end)
          |> Enum.reduce(&combine_fn.(&1, &2))

        case Yog.Model.add_edge(g, from, to, combined_weight) do
          {:ok, new_g} -> new_g
          {:error, _} -> g
        end
      end
    end)
  end

  @doc """
  Returns the total number of edges (including parallel edges).

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:undirected)
      iex> multi = Yog.Multi.Graph.add_node(multi, 1, nil)
      iex> multi = Yog.Multi.Graph.add_node(multi, 2, nil)
      iex> {:ok, multi, _} = Yog.Multi.Graph.add_edge(multi, 1, 2, 10)
      iex> total = Yog.Multi.Graph.total_edge_count(multi)
      iex> total >= 1
      true
  """
  @spec total_edge_count(t()) :: non_neg_integer()
  def total_edge_count(%__MODULE__{edges: edges, kind: kind}) do
    edges
    |> Enum.reduce(0, fn {{from, to}, edge_list}, acc ->
      # For undirected, only count once per unique pair
      if kind == :undirected and from > to do
        acc
      else
        acc + Kernel.length(edge_list)
      end
    end)
  end

  @doc """
  Returns the number of nodes in the multigraph.

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:undirected)
      iex> Yog.Multi.Graph.node_count(multi)
      0
  """
  @spec node_count(t()) :: non_neg_integer()
  def node_count(multi), do: Yog.Model.node_count(multi)

  @doc """
  Alias for `node_count/1`.
  """
  @spec order(t()) :: non_neg_integer()
  def order(multi), do: Yog.Model.order(multi)

  @doc """
  Checks if the multigraph contains a node with the given ID.
  """
  @spec has_node?(t(), Yog.Model.node_id()) :: boolean()
  def has_node?(multi, id), do: Yog.Model.has_node?(multi, id)

  @doc """
  Checks if the multigraph contains an edge between `src` and `dst`.
  """
  @spec has_edge?(t(), Yog.Model.node_id(), Yog.Model.node_id()) :: boolean()
  def has_edge?(%__MODULE__{edges: edges}, src, dst), do: Map.has_key?(edges, {src, dst})

  @doc """
  Gets the data associated with a node.
  """
  @spec node(t(), Yog.Model.node_id()) :: term() | nil
  def node(multi, id), do: Yog.Model.node(multi, id)

  @doc """
  Returns the graph type (:directed or :undirected).
  """
  @spec type(t()) :: :directed | :undirected
  def type(multi), do: Yog.Model.type(multi)

  @doc """
  Returns all node IDs in the multigraph.
  """
  @spec all_nodes(t()) :: [Yog.Model.node_id()]
  def all_nodes(multi), do: Yog.Model.all_nodes(multi)

  @doc """
  Returns all edges in the graph as triplets `{from, to, weight}`.
  """
  @spec all_edges(t()) :: [{Yog.Model.node_id(), Yog.Model.node_id(), number()}]
  def all_edges(%__MODULE__{edges: edges, kind: kind}) do
    if kind == :directed do
      for {{from, to}, edge_list} <- edges,
          {_id, weight} <- edge_list do
        {from, to, weight}
      end
    else
      for {{from, to}, edge_list} <- edges,
          from <= to,
          {_id, weight} <- edge_list do
        {from, to, weight}
      end
    end
  end

  @doc """
  Returns the out-degree of a node (total count of all parallel outgoing edges).
  """
  @spec out_degree(t(), Yog.Model.node_id()) :: non_neg_integer()
  def out_degree(%__MODULE__{edges: edges}, id) do
    Enum.reduce(edges, 0, fn {{from, _to}, edge_list}, acc ->
      if from == id, do: acc + length(edge_list), else: acc
    end)
  end

  @doc """
  Returns the in-degree of a node (total count of all parallel incoming edges).
  """
  @spec in_degree(t(), Yog.Model.node_id()) :: non_neg_integer()
  def in_degree(%__MODULE__{edges: edges}, id) do
    Enum.reduce(edges, 0, fn {{_from, to}, edge_list}, acc ->
      if to == id, do: acc + length(edge_list), else: acc
    end)
  end

  @doc """
  Returns the total degree of a node.
  """
  @spec degree(t(), Yog.Model.node_id()) :: non_neg_integer()
  def degree(multi, id) do
    case multi.kind do
      :directed -> out_degree(multi, id) + in_degree(multi, id)
      :undirected -> out_degree(multi, id)
    end
  end

  @doc """
  Removes a node and all its connected parallel edges.
  """
  @spec remove_node(t(), Yog.Model.node_id()) :: t()
  def remove_node(%__MODULE__{nodes: nodes, edges: edges} = multi, id) do
    new_nodes = Map.delete(nodes, id)

    new_edges =
      for {{from, to}, edge_list} <- edges,
          from != id and to != id,
          into: %{} do
        {{from, to}, edge_list}
      end

    %{multi | nodes: new_nodes, edges: new_edges}
  end

  @doc """
  Removes all parallel edges between `from` and `to`.
  """
  @spec remove_edges_between(t(), Yog.Model.node_id(), Yog.Model.node_id()) :: t()
  def remove_edges_between(%__MODULE__{edges: edges, kind: kind} = multi, from, to) do
    updated_edges = Map.delete(edges, {from, to})

    final_edges =
      if kind == :undirected and from != to do
        Map.delete(updated_edges, {to, from})
      else
        updated_edges
      end

    %{multi | edges: final_edges}
  end

  @doc """
  Backward compatibility: convert from legacy map format.
  """
  @spec from_map(map()) :: t()
  def from_map(%{kind: k, nodes: n, edges: e} = map) do
    next_id = Map.get(map, :next_edge_id, 0)

    %__MODULE__{
      kind: k,
      nodes: n,
      edges: e,
      next_edge_id: next_id
    }
  end

  @doc """
  Convert to legacy map format.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{kind: kind, nodes: nodes, edges: edges, next_edge_id: next_id}) do
    %{
      kind: kind,
      nodes: nodes,
      edges: edges,
      next_edge_id: next_id
    }
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp remove_empty_edge_list(edges_map, edge_key) do
    case Map.get(edges_map, edge_key) do
      [] -> Map.delete(edges_map, edge_key)
      _ -> edges_map
    end
  end
end

defimpl Yog.Queryable, for: Yog.Multi.Graph do
  def successors(graph, id) do
    for {{from, to}, edge_list} <- graph.edges,
        from == id,
        {_eid, weight} <- edge_list do
      {to, weight}
    end
  end

  def predecessors(graph, id) do
    for {{from, to}, edge_list} <- graph.edges,
        to == id,
        {_eid, weight} <- edge_list do
      {from, weight}
    end
  end

  def neighbors(graph, id) do
    successors(graph, id) ++ predecessors(graph, id)
  end

  def successor_ids(graph, id) do
    for {{from, to}, _} <- graph.edges, from == id, do: to
  end

  def predecessor_ids(graph, id) do
    for {{from, to}, _} <- graph.edges, to == id, do: from
  end

  def neighbor_ids(graph, id) do
    (successor_ids(graph, id) ++ predecessor_ids(graph, id)) |> Enum.uniq()
  end

  def all_nodes(graph), do: Yog.Model.all_nodes(graph)
  def order(graph), do: Yog.Model.order(graph)
  def node_count(graph), do: Yog.Model.node_count(graph)
  def edge_count(graph), do: Yog.Multi.Graph.total_edge_count(graph)
  def out_degree(graph, id), do: Yog.Multi.Graph.out_degree(graph, id)
  def in_degree(graph, id), do: Yog.Multi.Graph.in_degree(graph, id)
  def degree(graph, id), do: Yog.Multi.Graph.degree(graph, id)
  def has_node?(graph, id), do: Yog.Model.has_node?(graph, id)
  def has_edge?(graph, src, dst), do: Yog.Multi.Graph.has_edge?(graph, src, dst)
  def node(graph, id), do: Yog.Model.node(graph, id)
  def nodes(graph), do: Yog.Model.nodes(graph)
  def edge_data(graph, src, dst), do: Yog.Multi.Graph.get_edges(graph, src, dst)
  def all_edges(graph), do: Yog.Multi.Graph.all_edges(graph)
  def type(graph), do: Yog.Model.type(graph)
end

defimpl Yog.Modifiable, for: Yog.Multi.Graph do
  alias Yog.Multi.Graph

  def add_node(graph, id, data), do: Yog.Model.add_node(graph, id, data)
  def remove_node(graph, id), do: Graph.remove_node(graph, id)

  def add_edge(graph, src, dst, weight) do
    case Graph.add_edge(graph, src, dst, weight) do
      {:ok, updated_multi, _edge_id} -> {:ok, updated_multi}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  def add_edge(graph, opts) do
    src = Keyword.fetch!(opts, :from)
    dst = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    add_edge(graph, src, dst, weight)
  end

  def remove_edge(graph, src, dst), do: Graph.remove_edges_between(graph, src, dst)

  def add_edge_ensure(graph, src, dst, weight, default) do
    graph
    |> ensure_node(src, default)
    |> ensure_node(dst, default)
    |> then(fn g ->
      {:ok, updated} = add_edge(g, src, dst, weight)
      updated
    end)
  end

  def add_edge_ensure(graph, opts) do
    src = Keyword.fetch!(opts, :from)
    dst = Keyword.fetch!(opts, :to)
    weight = Keyword.fetch!(opts, :with)
    default = Keyword.get(opts, :default)
    add_edge_ensure(graph, src, dst, weight, default)
  end

  def add_edge_with(graph, src, dst, weight, make_fn) do
    graph
    |> ensure_node_with(src, make_fn)
    |> ensure_node_with(dst, make_fn)
    |> then(fn g ->
      {:ok, updated} = add_edge(g, src, dst, weight)
      updated
    end)
  end

  def add_unweighted_edge(graph, opts) do
    src = Keyword.fetch!(opts, :from)
    dst = Keyword.fetch!(opts, :to)
    add_edge(graph, src, dst, nil)
  end

  def add_edges(graph, edges) do
    Enum.reduce_while(edges, {:ok, graph}, fn {src, dst, weight}, {:ok, g} ->
      case add_edge(g, src, dst, weight) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def add_simple_edges(graph, edges) do
    Enum.reduce_while(edges, {:ok, graph}, fn {src, dst}, {:ok, g} ->
      case add_edge(g, src, dst, 1) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def add_unweighted_edges(graph, edges) do
    Enum.reduce_while(edges, {:ok, graph}, fn {src, dst}, {:ok, g} ->
      case add_edge(g, src, dst, nil) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def add_edge_with_combine(graph, src, dst, weight, with_combine) do
    case Graph.get_edges(graph, src, dst) do
      [] ->
        add_edge(graph, src, dst, weight)

      [{edge_id, existing_weight} | _rest] ->
        # Combine with first found weight and update it
        new_weight = with_combine.(existing_weight, weight)
        # We need an internal update_edge_weight or similar.
        # For multigraph, this is tricky. We'll remove the old and add new or replace.
        graph
        |> Graph.remove_edge(src, dst, edge_id)
        |> Graph.add_edge(src, dst, new_weight)
        |> then(fn {:ok, g, _} -> {:ok, g} end)
    end
  end

  # --- Internal Helpers for ensure ---

  defp ensure_node(graph, id, data) do
    if Graph.has_node?(graph, id), do: graph, else: Graph.add_node(graph, id, data)
  end

  defp ensure_node_with(graph, id, make_fn) do
    if Graph.has_node?(graph, id), do: graph, else: Graph.add_node(graph, id, make_fn.(id))
  end
end
