defmodule Yog.Graph do
  @moduledoc """
  Core graph data structure.

  A graph is represented as a struct with four fields:
  - `kind`: Either `:directed` or `:undirected`
  - `nodes`: Map of node_id => node_data
  - `out_edges`: Map of node_id => %{neighbor_id => weight}
  - `in_edges`: Map of node_id => %{neighbor_id => weight}

  The dual-map representation (storing both out_edges and in_edges) enables:
  - O(1) graph transpose (just swap out_edges ↔ in_edges)
  - Efficient predecessor queries without traversing the entire graph
  - Fast bidirectional edge lookups

  ## Examples

      iex> %Yog.Graph{
      ...>   kind: :directed,
      ...>   nodes: %{1 => "A", 2 => "B"},
      ...>   out_edges: %{1 => %{2 => 10}},
      ...>   in_edges: %{2 => %{1 => 10}}
      ...> }

  ## Protocols

  `Yog.Graph` implements the `Enumerable` and `Inspect` protocols:

  - **Enumerable**: Iterates over nodes as `{id, data}` tuples
  - **Inspect**: Compact representation showing graph type and statistics
  - **Yog.Queryable**: Standard interface for read-only graph operations
  - **Yog.Modifiable**: Standard interface for graph modification operations
  """

  @type node_id :: term()
  @type kind :: :directed | :undirected

  @type t :: %__MODULE__{
          kind: kind(),
          nodes: %{node_id() => any()},
          out_edges: %{node_id() => %{node_id() => number()}},
          in_edges: %{node_id() => %{node_id() => number()}}
        }

  @enforce_keys [:kind, :nodes, :out_edges, :in_edges]
  defstruct [:kind, :nodes, :out_edges, :in_edges]

  @doc """
  Creates a new empty graph of the given type.
  """
  @spec new(kind()) :: t()
  def new(kind) when kind in [:directed, :undirected] do
    %__MODULE__{
      kind: kind,
      nodes: %{},
      out_edges: %{},
      in_edges: %{}
    }
  end

  @doc """
  Returns the total number of edges in the graph.

  For undirected graphs, this counts each edge once (not twice).

  ## Performance Note

  This function traverses all nodes' outgoing edges, making it O(V) where V is
  the number of vertices. If you need the edge count multiple times, consider
  caching the result:

      edge_count = Yog.Graph.edge_count(graph)
      # Use edge_count in subsequent calculations...
  """
  @spec edge_count(t()) :: non_neg_integer()
  def edge_count(%__MODULE__{} = graph) do
    count =
      graph.out_edges
      |> Map.values()
      |> Enum.map(&map_size/1)
      |> Enum.sum()

    case graph.kind do
      :directed -> count
      :undirected -> div(count, 2)
    end
  end

  @doc """
  Returns the number of nodes in the graph.
  """
  @spec node_count(t()) :: non_neg_integer()
  def node_count(%__MODULE__{} = graph) do
    map_size(graph.nodes)
  end
end

defimpl Enumerable, for: Yog.Graph do
  @moduledoc """
  Enumerable implementation for `Yog.Graph`.

  Iterates over nodes as `{id, data}` tuples, similar to `Map.to_list/1`.

  ## Examples

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, "A")
      ...>   |> Yog.add_node(2, "B")
      iex> Enum.to_list(graph)
      [{1, "A"}, {2, "B"}]

      iex> Enum.count(graph)
      2

      iex> Enum.map(graph, fn {_id, data} -> data end)
      ["A", "B"]
  """

  def count(%Yog.Graph{nodes: nodes}) do
    {:ok, map_size(nodes)}
  end

  def member?(%Yog.Graph{nodes: nodes}, {id, data}) do
    {:ok, Map.get(nodes, id) == data}
  end

  def member?(%Yog.Graph{}, _) do
    {:ok, false}
  end

  def reduce(%Yog.Graph{nodes: nodes}, acc, fun) do
    Enumerable.reduce(nodes, acc, fun)
  end

  def slice(%Yog.Graph{nodes: nodes}) do
    {:ok, map_size(nodes),
     fn start, length ->
       nodes
       |> :maps.to_list()
       |> Enum.slice(start, length)
     end}
  end
end

defimpl Inspect, for: Yog.Graph do
  @moduledoc """
  Inspect implementation for `Yog.Graph`.

  Provides a compact representation showing graph type, node count, and edge count.

  ## Examples

      iex> graph = Yog.directed() |> Yog.add_node(1, "A")
      iex> inspect(graph)
      "#Yog.Graph<:directed, 1 node, 0 edges>"

      iex> graph = Yog.undirected() |> Yog.add_node(1, "A") |> Yog.add_node(2, "B")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      iex> inspect(graph)
      "#Yog.Graph<:undirected, 2 nodes, 1 edge>"

  """

  import Inspect.Algebra

  def inspect(%Yog.Graph{} = graph, opts) do
    node_count = map_size(graph.nodes)
    edge_count = Yog.Graph.edge_count(graph)

    node_str = if node_count == 1, do: "node", else: "nodes"
    edge_str = if edge_count == 1, do: "edge", else: "edges"

    concat([
      "#Yog.Graph<",
      to_doc(graph.kind, opts),
      ", ",
      "#{node_count} #{node_str}, ",
      "#{edge_count} #{edge_str}",
      ">"
    ])
  end
end

defimpl Yog.Queryable, for: Yog.Graph do
  def successors(graph, id), do: Yog.Model.successors(graph, id)
  def predecessors(graph, id), do: Yog.Model.predecessors(graph, id)
  def neighbors(graph, id), do: Yog.Model.neighbors(graph, id)
  def successor_ids(graph, id), do: Yog.Model.successor_ids(graph, id)
  def predecessor_ids(graph, id), do: Yog.Model.predecessor_ids(graph, id)
  def neighbor_ids(graph, id), do: Yog.Model.neighbor_ids(graph, id)
  def all_nodes(graph), do: Yog.Model.all_nodes(graph)
  def order(graph), do: Yog.Model.order(graph)
  def node_count(graph), do: Yog.Model.node_count(graph)
  def edge_count(graph), do: Yog.Model.edge_count(graph)
  def out_degree(graph, id), do: Yog.Model.out_degree(graph, id)
  def in_degree(graph, id), do: Yog.Model.in_degree(graph, id)
  def degree(graph, id), do: Yog.Model.degree(graph, id)
  def has_node?(graph, id), do: Yog.Model.has_node?(graph, id)
  def has_edge?(graph, src, dst), do: Yog.Model.has_edge?(graph, src, dst)
  def node(graph, id), do: Yog.Model.node(graph, id)
  def nodes(graph), do: Yog.Model.nodes(graph)
  def edge_data(graph, src, dst), do: Yog.Model.edge_data(graph, src, dst)
  def all_edges(graph), do: Yog.Model.all_edges(graph)
  def type(graph), do: Yog.Model.type(graph)
end

defimpl Yog.Modifiable, for: Yog.Graph do
  def add_node(graph, id, data), do: Yog.Model.add_node(graph, id, data)
  def remove_node(graph, id), do: Yog.Model.remove_node(graph, id)
  def add_edge(graph, src, dst, weight), do: Yog.Model.add_edge(graph, src, dst, weight)
  def add_edge(graph, opts), do: Yog.Model.add_edge(graph, opts)
  def remove_edge(graph, src, dst), do: Yog.Model.remove_edge(graph, src, dst)

  def add_edge_ensure(graph, src, dst, weight, default),
    do: Yog.Model.add_edge_ensure(graph, src, dst, weight, default)

  def add_edge_ensure(graph, opts), do: Yog.Model.add_edge_ensure(graph, opts)

  def add_edge_with(graph, src, dst, weight, make_fn),
    do: Yog.Model.add_edge_with(graph, src, dst, weight, make_fn)

  def add_unweighted_edge(graph, opts), do: Yog.Model.add_unweighted_edge(graph, opts)
  def add_edges(graph, edges), do: Yog.Model.add_edges(graph, edges)
  def add_simple_edges(graph, edges), do: Yog.Model.add_simple_edges(graph, edges)
  def add_unweighted_edges(graph, edges), do: Yog.Model.add_unweighted_edges(graph, edges)

  def add_edge_with_combine(graph, src, dst, weight, with_combine),
    do: Yog.Model.add_edge_with_combine(graph, src, dst, weight, with_combine)
end
