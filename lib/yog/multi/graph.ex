defmodule Yog.Multi.Graph do
  @moduledoc """
  Core multigraph data structure.

  A multigraph allows multiple (parallel) edges between the same pair of nodes.
  Both directed and undirected variants are supported.

  The internal representation keeps three indexes:
  - `edges`: EdgeId → {from, to, data} — canonical edge store
  - `out_edge_ids`: NodeId → [EdgeId] — outgoing edges per node
  - `in_edge_ids`: NodeId → [EdgeId] — incoming edges per node

  ## Fields

  - `kind` - Either `:directed` or `:undirected`
  - `nodes` - Map from node ID to node data
  - `edges` - Map from edge ID to `{from, to, data}`
  - `out_edge_ids` - Map from node ID to MapSet of edge IDs
  - `in_edge_ids` - Map from node ID to MapSet of edge IDs
  - `next_edge_id` - Counter for generating unique edge IDs

  ## Examples

      iex> multi = Yog.Multi.Graph.new(:directed)
      iex> multi.kind
      :directed
      iex> multi.next_edge_id
      0
  """

  @enforce_keys [:kind, :nodes, :edges, :out_edge_ids, :in_edge_ids, :next_edge_id]
  defstruct [:kind, :nodes, :edges, :out_edge_ids, :in_edge_ids, :next_edge_id]

  @type edge_id :: non_neg_integer()
  @type t :: %__MODULE__{
          kind: :directed | :undirected,
          nodes: %{Yog.Model.node_id() => term()},
          edges: %{edge_id() => {Yog.Model.node_id(), Yog.Model.node_id(), term()}},
          out_edge_ids: %{Yog.Model.node_id() => MapSet.t(edge_id())},
          in_edge_ids: %{Yog.Model.node_id() => MapSet.t(edge_id())},
          next_edge_id: non_neg_integer()
        }

  @doc """
  Creates a new empty multigraph of the given type.

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
      out_edge_ids: %{},
      in_edge_ids: %{},
      next_edge_id: 0
    }
  end

  @doc """
  Creates a new empty directed multigraph.
  """
  @spec directed() :: t()
  def directed, do: new(:directed)

  @doc """
  Creates a new empty undirected multigraph.
  """
  @spec undirected() :: t()
  def undirected, do: new(:undirected)

  @doc """
  Returns the total number of edges (including parallel edges).
  """
  @spec edge_count(t()) :: non_neg_integer()
  def edge_count(%__MODULE__{edges: edges}), do: map_size(edges)
end

defimpl Enumerable, for: Yog.Multi.Graph do
  @moduledoc """
  Enumerable implementation for `Yog.Multi.Graph`.

  Iterates over nodes as `{id, data}` tuples, similar to `Map.to_list/1`.
  """

  def count(%Yog.Multi.Graph{nodes: nodes}) do
    {:ok, map_size(nodes)}
  end

  def member?(%Yog.Multi.Graph{nodes: nodes}, {id, data}) do
    {:ok, Map.get(nodes, id) == data}
  end

  def member?(%Yog.Multi.Graph{}, _) do
    {:ok, false}
  end

  def reduce(%Yog.Multi.Graph{nodes: nodes}, acc, fun) do
    Enumerable.List.reduce(Map.to_list(nodes), acc, fun)
  end

  def slice(%Yog.Multi.Graph{nodes: nodes}) do
    {:ok, map_size(nodes),
     fn start, length, _step ->
       nodes |> Map.to_list() |> Enum.slice(start, length)
     end}
  end
end

defimpl Inspect, for: Yog.Multi.Graph do
  @moduledoc """
  Inspect implementation for `Yog.Multi.Graph`.

  Provides a compact representation showing graph type, node count, and edge count.
  """

  import Inspect.Algebra

  def inspect(%Yog.Multi.Graph{} = graph, opts) do
    node_count = map_size(graph.nodes)
    edge_count = Yog.Multi.Graph.edge_count(graph)

    node_str = if node_count == 1, do: "node", else: "nodes"
    edge_str = if edge_count == 1, do: "edge", else: "edges"

    concat([
      "#Yog.Multi.Graph<",
      to_doc(graph.kind, opts),
      ", ",
      "#{node_count} #{node_str}, ",
      "#{edge_count} #{edge_str}",
      ">"
    ])
  end
end
