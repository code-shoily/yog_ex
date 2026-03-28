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
  """

  @type node_id :: integer()
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
    edge_count = edge_count(graph)

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

  defp edge_count(%{kind: :directed, out_edges: out_edges}) do
    out_edges
    |> Map.values()
    |> Enum.map(&map_size/1)
    |> Enum.sum()
  end

  defp edge_count(%{kind: :undirected, out_edges: out_edges}) do
    count =
      out_edges
      |> Map.values()
      |> Enum.map(&map_size/1)
      |> Enum.sum()

    div(count, 2)
  end
end
