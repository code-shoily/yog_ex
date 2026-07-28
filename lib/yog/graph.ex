defmodule Yog.Graph do
  @moduledoc """
  Core graph data structure and protocols.

  A graph is represented as a `%Yog.Graph{}` struct with four primary fields:
  - `kind`: Either `:directed` or `:undirected`
  - `nodes`: Map of `node_id => node_data`
  - `out_edges`: Map of `node_id => %{neighbor_id => weight}`
  - `in_edges`: Map of `node_id => %{neighbor_id => weight}`

  ## Dual-Map Representation

  The dual-map design (storing both `out_edges` and `in_edges`) enables:
  - **$\\mathcal{O}(1)$ Graph Transpose:** Transposing a graph is a simple pointer swap (`out_edges ↔ in_edges`).
  - **Fast Predecessor Queries:** Finding incoming edges to a node runs in $\\mathcal{O}(\\text{in-degree})$ time without scanning the entire graph.
  - **Fast Bidirectional Lookups:** Instant checking for reverse edges or symmetrical relationships.

  ## Constructor & Mutation Guidelines

  Direct struct instantiation (`%Yog.Graph{...}`) or raw field mutation should generally
  be avoided in application code to prevent index desynchronization between `nodes`,
  `out_edges`, and `in_edges`. Use the primary `Yog` facade or `Yog.Model` functions to
  build and manipulate graphs safely.

  ## Protocols

  `Yog.Graph` implements the `Enumerable` and `Inspect` protocols:
  - **Enumerable:** Iterates over nodes as `{id, data}` tuples.
  - **Inspect:** Compact representation showing graph kind, node count, and edge count.

  ## Visual Showcase

  <div class="graphviz">
  digraph G {
    rankdir=LR;
    bgcolor="transparent";
    node [fontname="inherit", shape=box, style=rounded, penwidth=1.5];
    edge [fontname="inherit", fontsize=10, penwidth=1.2];

    subsystem [label="Core System", shape=hexagon, color="#6366f1"];
    node1 [label="Logic A", color="#10b981"];
    node2 [label="Logic B", color="#10b981"];
    node3 [label="Logic C", color="#10b981"];
    storage [label="Storage", shape=cylinder, color="#f59e0b"];
    user [label="User", shape=doublecircle, color="#ef4444"];

    subsystem -> node1 [label="invokes", color="#6366f1"];
    subsystem -> node2 [label="invokes", color="#6366f1"];
    node1 -> node3 [label="calls", style=dashed, color="#10b981"];
    node2 -> node3 [label="calls", style=dashed, color="#10b981"];
    node3 -> storage [label="writes", color="#f59e0b"];
    user -> subsystem [label="triggers", color="#ef4444", penwidth=2.5];
  }
  </div>

  ## Examples

      iex> graph = Yog.Graph.new(:directed)
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      iex> Yog.Graph.node_count(graph)
      2
      iex> Yog.Graph.edge_count(graph)
      1
  """

  @typedoc "Type representing the unique identifier for a node."
  @type node_id :: term()

  @typedoc "Type representing whether a graph is directed or undirected."
  @type kind :: :directed | :undirected

  @typedoc "Type representing the Yog.Graph structure."
  @type t :: %__MODULE__{
          kind: kind(),
          nodes: %{node_id() => any()},
          out_edges: %{node_id() => %{node_id() => number()}},
          in_edges: %{node_id() => %{node_id() => number()}}
        }

  @enforce_keys [:kind, :nodes, :out_edges, :in_edges]
  defstruct [:kind, :nodes, :out_edges, :in_edges]

  @doc """
  Creates a new empty graph of the given kind (`:directed` or `:undirected`).

  ## Errors

  - Raises `ArgumentError` if `kind` is not `:directed` or `:undirected`.

  ## Examples

      iex> Yog.Graph.new(:directed)
      %Yog.Graph{kind: :directed, in_edges: %{}, nodes: %{}, out_edges: %{}}

      iex> Yog.Graph.new(:undirected)
      %Yog.Graph{kind: :undirected, in_edges: %{}, nodes: %{}, out_edges: %{}}
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

  def new(invalid_kind) do
    raise ArgumentError,
          "expected kind to be :directed or :undirected, got: #{inspect(invalid_kind)}"
  end

  @doc """
  Returns the total number of edges in the graph.

  For undirected graphs, each edge is counted once (excluding duplicate mirroring).
  Self-loops are counted as single edges.

  **Time Complexity:** $\\mathcal{O}(V)$

  ## Errors

  - Raises `ArgumentError` if passed a non-`Yog.Graph` term.

  ## Examples

      iex> graph = Yog.Graph.new(:directed)
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      ...> |> Yog.add_edge_ensure(from: 1, to: 3, with: 20)
      iex> Yog.Graph.edge_count(graph)
      2
  """
  @spec edge_count(t()) :: non_neg_integer()
  def edge_count(%__MODULE__{} = graph) do
    case graph.kind do
      :directed ->
        Enum.reduce(graph.out_edges, 0, fn {_src, targets}, acc ->
          acc + map_size(targets)
        end)

      :undirected ->
        {total, self_loops} =
          Enum.reduce(graph.out_edges, {0, 0}, fn {src, targets}, {acc_total, acc_self} ->
            new_total = acc_total + map_size(targets)
            new_self = if Map.has_key?(targets, src), do: acc_self + 1, else: acc_self
            {new_total, new_self}
          end)

        div(total - self_loops, 2) + self_loops
    end
  end

  def edge_count(other) do
    raise ArgumentError, "expected a Yog.Graph struct, got: #{inspect(other)}"
  end

  @doc """
  Returns the number of nodes in the graph.

  **Time Complexity:** $\\mathcal{O}(1)$

  ## Errors

  - Raises `ArgumentError` if passed a non-`Yog.Graph` term.

  ## Examples

      iex> graph = Yog.Graph.new(:directed)
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      iex> Yog.Graph.node_count(graph)
      2
  """
  @spec node_count(t()) :: non_neg_integer()
  def node_count(%__MODULE__{} = graph) do
    map_size(graph.nodes)
  end

  def node_count(other) do
    raise ArgumentError, "expected a Yog.Graph struct, got: #{inspect(other)}"
  end
end

defimpl Enumerable, for: Yog.Graph do
  @moduledoc """
  Enumerable protocol implementation for `Yog.Graph`.

  Iterates over graph nodes as `{id, data}` tuples.
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
     fn start, length, _step ->
       nodes
       |> :maps.to_list()
       |> Enum.slice(start, length)
     end}
  end
end

defimpl Inspect, for: Yog.Graph do
  @moduledoc """
  Inspect protocol implementation for `Yog.Graph`.

  Provides a compact, human-readable summary: `#Yog.Graph<:kind, N nodes, M edges>`.
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
