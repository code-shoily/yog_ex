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

  # =============================================================================
  # Yog.Model Protocol Implementation
  # =============================================================================

  defimpl Yog.Model.Protocol do
    alias Yog.Graph

    @spec type(Graph.t()) :: :directed | :undirected
    def type(%Graph{kind: kind}), do: kind

    @spec node_count(Graph.t()) :: non_neg_integer()
    def node_count(%Graph{nodes: nodes}), do: map_size(nodes)

    @spec order(Graph.t()) :: non_neg_integer()
    def order(%Graph{nodes: nodes}), do: map_size(nodes)

    @spec edge_count(Graph.t()) :: non_neg_integer()
    def edge_count(%Graph{kind: :directed, out_edges: out_edges}) do
      Enum.reduce(out_edges, 0, fn {_src, targets}, acc ->
        acc + map_size(targets)
      end)
    end

    def edge_count(%Graph{kind: :undirected, out_edges: out_edges}) do
      {total, self_loops} =
        Enum.reduce(out_edges, {0, 0}, fn {src, targets}, {acc_total, acc_self} ->
          new_total = acc_total + map_size(targets)
          new_self = if Map.has_key?(targets, src), do: acc_self + 1, else: acc_self
          {new_total, new_self}
        end)

      div(total - self_loops, 2) + self_loops
    end

    @spec all_nodes(Graph.t()) :: [Graph.node_id()]
    def all_nodes(%Graph{nodes: nodes}), do: Map.keys(nodes)

    @spec nodes(Graph.t()) :: %{Graph.node_id() => any()}
    def nodes(%Graph{nodes: nodes}), do: nodes

    @spec node(Graph.t(), Graph.node_id()) :: any() | nil
    def node(%Graph{nodes: nodes}, id), do: Map.get(nodes, id)

    @spec has_node?(Graph.t(), Graph.node_id()) :: boolean()
    def has_node?(%Graph{nodes: nodes}, id), do: Map.has_key?(nodes, id)

    @spec successors(Graph.t(), Graph.node_id()) :: [{Graph.node_id(), any()}]
    def successors(%Graph{out_edges: out_edges}, id) do
      case Map.fetch(out_edges, id) do
        {:ok, targets} -> Map.to_list(targets)
        :error -> []
      end
    end

    @spec predecessors(Graph.t(), Graph.node_id()) :: [{Graph.node_id(), any()}]
    def predecessors(%Graph{in_edges: in_edges}, id) do
      case Map.fetch(in_edges, id) do
        {:ok, sources} -> Map.to_list(sources)
        :error -> []
      end
    end

    @spec successor_ids(Graph.t(), Graph.node_id()) :: [Graph.node_id()]
    def successor_ids(%Graph{out_edges: out_edges}, id) do
      case Map.fetch(out_edges, id) do
        {:ok, targets} -> Map.keys(targets)
        :error -> []
      end
    end

    @spec predecessor_ids(Graph.t(), Graph.node_id()) :: [Graph.node_id()]
    def predecessor_ids(%Graph{in_edges: in_edges}, id) do
      case Map.fetch(in_edges, id) do
        {:ok, sources} -> Map.keys(sources)
        :error -> []
      end
    end

    @spec neighbors(Graph.t(), Graph.node_id()) :: [{Graph.node_id(), any()}]
    def neighbors(%Graph{kind: :undirected} = graph, id) do
      successors(graph, id)
    end

    def neighbors(%Graph{kind: :directed, in_edges: in_edges} = graph, id) do
      outgoing = successors(graph, id)

      case Map.fetch(in_edges, id) do
        {:ok, inner} ->
          out_ids = successor_ids(graph, id)
          incoming_to_add = inner |> Map.drop(out_ids) |> Map.to_list()
          outgoing ++ incoming_to_add

        :error ->
          outgoing
      end
    end

    @spec neighbor_ids(Graph.t(), Graph.node_id()) :: [Graph.node_id()]
    def neighbor_ids(%Graph{kind: :undirected} = graph, id) do
      successor_ids(graph, id)
    end

    def neighbor_ids(%Graph{kind: :directed, in_edges: in_edges} = graph, id) do
      out_ids = successor_ids(graph, id)

      case Map.fetch(in_edges, id) do
        {:ok, inner} ->
          in_ids = Map.keys(inner)
          Enum.uniq(out_ids ++ in_ids)

        :error ->
          out_ids
      end
    end

    @spec has_edge?(Graph.t(), Graph.node_id(), Graph.node_id()) :: boolean()
    def has_edge?(%Graph{out_edges: out_edges}, src, dst) do
      case Map.fetch(out_edges, src) do
        {:ok, targets} -> Map.has_key?(targets, dst)
        :error -> false
      end
    end

    @spec edge_data(Graph.t(), Graph.node_id(), Graph.node_id()) :: any() | nil
    def edge_data(%Graph{out_edges: out_edges}, src, dst) do
      case Map.fetch(out_edges, src) do
        {:ok, targets} -> Map.get(targets, dst)
        :error -> nil
      end
    end

    @spec all_edges(Graph.t()) :: [{Graph.node_id(), Graph.node_id(), any()}]
    def all_edges(%Graph{kind: :directed, out_edges: out_edges}) do
      for {from, dests} <- out_edges,
          {to, weight} <- dests do
        {from, to, weight}
      end
    end

    def all_edges(%Graph{kind: :undirected, out_edges: out_edges}) do
      for {from, dests} <- out_edges,
          {to, weight} <- dests,
          from <= to do
        {from, to, weight}
      end
    end

    @spec out_degree(Graph.t(), Graph.node_id()) :: non_neg_integer()
    def out_degree(%Graph{out_edges: out_edges}, id) do
      case Map.fetch(out_edges, id) do
        {:ok, targets} -> map_size(targets)
        :error -> 0
      end
    end

    @spec in_degree(Graph.t(), Graph.node_id()) :: non_neg_integer()
    def in_degree(%Graph{in_edges: in_edges}, id) do
      case Map.fetch(in_edges, id) do
        {:ok, sources} -> map_size(sources)
        :error -> 0
      end
    end

    @spec degree(Graph.t(), Graph.node_id()) :: non_neg_integer()
    def degree(%Graph{kind: :undirected, out_edges: out_edges}, id) do
      case Map.fetch(out_edges, id) do
        {:ok, targets} ->
          base = map_size(targets)
          if Map.has_key?(targets, id), do: base + 1, else: base

        :error ->
          0
      end
    end

    def degree(%Graph{kind: :directed} = graph, id) do
      in_degree(graph, id) + out_degree(graph, id)
    end
  end

  # =============================================================================
  # Public API
  # =============================================================================

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
