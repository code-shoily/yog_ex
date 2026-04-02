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

  @doc """
  Returns the out_edges map from the graph.

  ## Example

      iex> graph = Yog.directed() |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      iex> Yog.Graph.out_edges(graph)
      %{1 => %{2 => 5}}
  """
  @spec out_edges(t()) :: %{node_id() => %{node_id() => number()}}
  def out_edges(%__MODULE__{} = graph) do
    graph.out_edges
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
  # Direct struct access for maximum performance (no delegation to Model/Defaults)

  # Core required functions - direct field access
  def successors(%Yog.Graph{out_edges: out_edges}, id) do
    case Map.fetch(out_edges, id) do
      {:ok, inner} -> Map.to_list(inner)
      :error -> []
    end
  end

  def predecessors(%Yog.Graph{in_edges: in_edges}, id) do
    case Map.fetch(in_edges, id) do
      {:ok, inner} -> Map.to_list(inner)
      :error -> []
    end
  end

  def type(%Yog.Graph{kind: kind}), do: kind
  def node(%Yog.Graph{nodes: nodes}, id), do: Map.get(nodes, id)
  def all_nodes(%Yog.Graph{nodes: nodes}), do: Map.keys(nodes)
  def order(%Yog.Graph{nodes: nodes}), do: map_size(nodes)

  def edge_count(%Yog.Graph{kind: :directed, out_edges: out_edges}) do
    Enum.reduce(out_edges, 0, fn {_src, targets}, acc ->
      acc + map_size(targets)
    end)
  end

  def edge_count(%Yog.Graph{kind: :undirected, out_edges: out_edges}) do
    {total, self_loops} =
      Enum.reduce(out_edges, {0, 0}, fn {src, targets}, {acc_total, acc_self} ->
        new_total = acc_total + map_size(targets)
        new_self = if Map.has_key?(targets, src), do: acc_self + 1, else: acc_self
        {new_total, new_self}
      end)

    div(total - self_loops, 2) + self_loops
  end

  # O(1) degree lookups - direct field access
  def out_degree(%Yog.Graph{out_edges: out_edges}, id) do
    case Map.fetch(out_edges, id) do
      {:ok, inner} -> map_size(inner)
      :error -> 0
    end
  end

  def in_degree(%Yog.Graph{in_edges: in_edges}, id) do
    case Map.fetch(in_edges, id) do
      {:ok, inner} -> map_size(inner)
      :error -> 0
    end
  end

  def degree(%Yog.Graph{kind: :undirected, out_edges: out_edges}, id) do
    case Map.fetch(out_edges, id) do
      {:ok, targets} ->
        # Self-loops count as 2 in undirected graphs
        base = map_size(targets)
        if Map.has_key?(targets, id), do: base + 1, else: base

      :error ->
        0
    end
  end

  def degree(%Yog.Graph{} = graph, id) do
    out_degree(graph, id) + in_degree(graph, id)
  end

  # Fast lookups - direct field access
  def has_node?(%Yog.Graph{nodes: nodes}, id), do: Map.has_key?(nodes, id)

  def has_edge?(%Yog.Graph{out_edges: out_edges}, src, dst) do
    case Map.fetch(out_edges, src) do
      {:ok, inner} -> Map.has_key?(inner, dst)
      :error -> false
    end
  end

  def edge_data(%Yog.Graph{out_edges: out_edges}, src, dst) do
    case Map.fetch(out_edges, src) do
      {:ok, inner} -> Map.get(inner, dst)
      :error -> nil
    end
  end

  def nodes(%Yog.Graph{nodes: nodes}), do: nodes

  def all_edges(%Yog.Graph{kind: :undirected, out_edges: out_edges}) do
    # For undirected graphs, edges are stored in both directions.
    # Only return edges where src <= dst to avoid duplicates.
    out_edges
    |> Enum.flat_map(fn {src, inner} ->
      inner
      |> Enum.filter(fn {dst, _weight} -> src <= dst end)
      |> Enum.map(fn {dst, weight} -> {src, dst, weight} end)
    end)
  end

  def all_edges(%Yog.Graph{out_edges: out_edges}) do
    out_edges
    |> Enum.flat_map(fn {src, inner} ->
      Enum.map(inner, fn {dst, weight} -> {src, dst, weight} end)
    end)
  end

  # Derived functions - direct implementation (not via Defaults module)
  def successor_ids(%Yog.Graph{out_edges: out_edges}, id) do
    case Map.fetch(out_edges, id) do
      {:ok, inner} -> Map.keys(inner)
      :error -> []
    end
  end

  def predecessor_ids(%Yog.Graph{in_edges: in_edges}, id) do
    case Map.fetch(in_edges, id) do
      {:ok, inner} -> Map.keys(inner)
      :error -> []
    end
  end

  def neighbors(%Yog.Graph{kind: :undirected} = graph, id) do
    successors(graph, id)
  end

  def neighbors(%Yog.Graph{out_edges: out_edges, in_edges: in_edges}, id) do
    outgoing =
      case Map.fetch(out_edges, id) do
        {:ok, inner} -> inner
        :error -> %{}
      end

    case Map.fetch(in_edges, id) do
      {:ok, inner} ->
        # Merge, with outgoing taking precedence
        Map.merge(inner, outgoing) |> Map.to_list()

      :error ->
        Map.to_list(outgoing)
    end
  end

  def neighbor_ids(%Yog.Graph{kind: :undirected} = graph, id) do
    successor_ids(graph, id)
  end

  def neighbor_ids(%Yog.Graph{out_edges: out_edges, in_edges: in_edges}, id) do
    out =
      case Map.fetch(out_edges, id) do
        {:ok, inner} -> Map.keys(inner)
        :error -> []
      end

    in_keys =
      case Map.fetch(in_edges, id) do
        {:ok, inner} -> Map.keys(inner)
        :error -> []
      end

    Enum.uniq(out ++ in_keys)
  end

  def node_count(%Yog.Graph{nodes: nodes}), do: map_size(nodes)
end

defimpl Yog.Modifiable, for: Yog.Graph do
  def add_node(graph, id, data), do: Yog.Model.add_node(graph, id, data)
  def remove_node(graph, id), do: Yog.Model.remove_node(graph, id)
  def add_edge(graph, src, dst, weight), do: Yog.Model.add_edge(graph, src, dst, weight)
  def add_edges(graph, edges), do: Yog.Model.add_edges(graph, edges)
  def remove_edge(graph, src, dst), do: Yog.Model.remove_edge(graph, src, dst)

  def add_edge_ensure(graph, src, dst, weight, default_data),
    do: Yog.Model.add_edge_ensure(graph, src, dst, weight, default_data)

  def add_edge_with_combine(graph, src, dst, weight, with_combine),
    do: Yog.Model.add_edge_with_combine(graph, src, dst, weight, with_combine)
end

defimpl Yog.Transformable, for: Yog.Graph do
  def empty(graph), do: Yog.Graph.new(graph.kind)
  def empty(_graph, kind), do: Yog.Graph.new(kind)

  def transpose(graph) do
    %{graph | out_edges: graph.in_edges, in_edges: graph.out_edges}
  end

  def map_nodes(graph, fun) do
    new_nodes = Map.new(graph.nodes, fn {id, data} -> {id, fun.(data)} end)
    %{graph | nodes: new_nodes}
  end

  def map_edges(graph, fun) do
    transform_inner = fn inner_map ->
      Map.new(inner_map, fn {dst, weight} -> {dst, fun.(weight)} end)
    end

    transform_outer = fn outer_map ->
      Map.new(outer_map, fn {src, inner_map} -> {src, transform_inner.(inner_map)} end)
    end

    %{
      graph
      | out_edges: transform_outer.(graph.out_edges),
        in_edges: transform_outer.(graph.in_edges)
    }
  end
end
