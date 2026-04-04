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

      updated_edges =
        Map.update(edges, edge_key, [new_edge], fn existing -> [new_edge | existing] end)

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

    updated_edges =
      Map.update(edges, edge_key, [], fn edge_list ->
        Enum.reject(edge_list, fn {eid, _} -> eid == edge_id end)
      end)
      |> remove_empty_edge_list(edge_key)

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
    base_graph =
      case kind do
        :directed -> Yog.directed()
        :undirected -> Yog.undirected()
      end

    graph_with_nodes =
      Enum.reduce(nodes, base_graph, fn {node_id, data}, g ->
        Yog.add_node(g, node_id, data)
      end)

    Enum.reduce(edges, graph_with_nodes, fn {{from, to}, edge_list}, g ->
      case edge_list do
        [] ->
          g

        [{_edge_id, weight} | _rest] ->
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
    base_graph =
      case kind do
        :directed -> Yog.directed()
        :undirected -> Yog.undirected()
      end

    graph_with_nodes =
      Enum.reduce(nodes, base_graph, fn {node_id, data}, g ->
        Yog.add_node(g, node_id, data)
      end)

    Enum.reduce(edges, graph_with_nodes, fn {{from, to}, edge_list}, g ->
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
      iex> multi = Yog.Multi.Graph.add_node(multi, 1, nil)
      iex> multi = Yog.Multi.Graph.add_node(multi, 2, nil)
      iex> count = Yog.Multi.Graph.node_count(multi)
      iex> count
      2
  """
  @spec node_count(t()) :: non_neg_integer()
  def node_count(%__MODULE__{nodes: nodes}) do
    map_size(nodes)
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
