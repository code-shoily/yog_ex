defmodule Yog.Builder.Zog do
  @moduledoc """
  Build graphs for the native Zog (Zig) backend using arbitrary labels.

  This module provides the same ergonomic label-based API as
  `Yog.Builder.Labeled`, but accumulates data into flat arrays that are
  ready to pass to Zigler NIFs — no intermediate `Yog.Graph` conversion.

  ## Example

      builder = Yog.Builder.Zog.directed()
        |> Yog.Builder.Zog.add_edge("A", "B", 1.0)
        |> Yog.Builder.Zog.add_edge("B", "C", 2.0)

      # Pass directly to a native algorithm
      scores = Yog.Zog.Centrality.betweenness_unweighted(builder)
      # => %{"A" => 0.0, "B" => 1.0, "C" => 0.0}

  ## Converting from existing Yog structures

      # From a Yog.Graph
      builder = Yog.Builder.Zog.from_graph(my_graph)

      # From a Yog.Builder.Labeled
      builder = Yog.Builder.Zog.from_labeled(labeled_builder)

  """

  alias Yog.Model

  @enforce_keys [:kind]
  defstruct [
    :kind,
    label_to_id: %{},
    id_to_label: %{},
    nodes: [],
    edges: [],
    next_id: 0
  ]

  @typedoc "Zog builder struct"
  @type t :: %__MODULE__{
          kind: Model.graph_type(),
          label_to_id: %{label() => id()},
          id_to_label: %{id() => label()},
          nodes: [label()],
          edges: [{id(), id(), float()}],
          next_id: non_neg_integer()
        }

  @typedoc "Any type can be used as a label"
  @type label :: term()

  @typedoc "Internal integer node id (maps to Zog's u32 index)"
  @type id :: non_neg_integer()

  # ============= Constructors =============

  @doc """
  Creates a new directed Zog builder.
  """
  @spec directed() :: t()
  def directed, do: new(:directed)

  @doc """
  Creates a new undirected Zog builder.
  """
  @spec undirected() :: t()
  def undirected, do: new(:undirected)

  @doc """
  Creates a new Zog builder of the specified type.
  """
  @spec new(Model.graph_type()) :: t()
  def new(graph_type) do
    %__MODULE__{
      kind: graph_type
    }
  end

  # ============= Node Operations =============

  @doc """
  Adds a node with the given label.

  If the label already exists, returns the builder unchanged.
  """
  @spec add_node(t(), label()) :: t()
  def add_node(builder, label) do
    {new_builder, _id} = ensure_node(builder, label)
    new_builder
  end

  @doc """
  Gets or creates a node for the given label.

  Returns `{builder, id}` where `id` is the integer index assigned to
  this label.
  """
  @spec ensure_node(t(), label()) :: {t(), id()}
  def ensure_node(%__MODULE__{label_to_id: label_to_id} = builder, label) do
    case Map.fetch(label_to_id, label) do
      {:ok, id} ->
        {builder, id}

      :error ->
        id = builder.next_id

        # credo:disable-for-this-file Credo.Check.Refactor.AppendSingleItem
        new_builder = %{
          builder
          | label_to_id: Map.put(label_to_id, label, id),
            id_to_label: Map.put(builder.id_to_label, id, label),
            nodes: [label | builder.nodes],
            next_id: id + 1
        }

        {new_builder, id}
    end
  end

  # ============= Edge Operations =============

  @doc """
  Adds an edge between two labeled nodes with a weight.

  Nodes are created automatically if they do not exist.

  For undirected builders, the reverse edge is also added.
  """
  @spec add_edge(t(), label(), label(), term()) :: t()
  def add_edge(builder, from, to, weight) do
    {builder_with_src, src_id} = ensure_node(builder, from)
    {builder_with_both, dst_id} = ensure_node(builder_with_src, to)

    w = to_float(weight)

    directed_edge = {src_id, dst_id, w}

    new_edges =
      if builder_with_both.kind == :undirected do
        reverse_edge = {dst_id, src_id, w}
        [reverse_edge, directed_edge | builder_with_both.edges]
      else
        [directed_edge | builder_with_both.edges]
      end

    %{builder_with_both | edges: new_edges}
  end

  @doc """
  Adds an unweighted edge (weight defaults to `1.0`).
  """
  @spec add_unweighted_edge(t(), label(), label()) :: t()
  def add_unweighted_edge(builder, from, to) do
    add_edge(builder, from, to, 1.0)
  end

  @doc """
  Adds a simple edge with weight `1` between two labeled nodes.

  Alias for `add_unweighted_edge/3`.
  """
  @spec add_simple_edge(t(), label(), label()) :: t()
  def add_simple_edge(builder, from, to) do
    add_unweighted_edge(builder, from, to)
  end

  # ============= Batch Construction =============

  @doc """
  Creates a builder from a list of labeled edges.

  Each edge is a `{from_label, to_label, weight}` tuple.
  """
  @spec from_list(Model.graph_type(), [{label(), label(), term()}]) :: t()
  def from_list(graph_type, edges) do
    Enum.reduce(edges, new(graph_type), fn {src, dst, weight}, builder ->
      add_edge(builder, src, dst, weight)
    end)
  end

  @doc """
  Creates a builder from a list of unweighted labeled edges.
  """
  @spec from_unweighted_list(Model.graph_type(), [{label(), label()}]) :: t()
  def from_unweighted_list(graph_type, edges) do
    Enum.reduce(edges, new(graph_type), fn {src, dst}, builder ->
      add_unweighted_edge(builder, src, dst)
    end)
  end

  # ============= Conversion from existing structures =============

  @doc """
  Converts a `Yog.Graph` into a `Zog` builder.

  This is useful when you want to run native algorithms on an existing
  graph that was built with the standard API.
  """
  @spec from_graph(Yog.graph()) :: t()
  def from_graph(%Yog.Graph{kind: kind, nodes: nodes, out_edges: out_edges}) do
    node_ids = nodes |> Map.keys() |> Enum.sort()
    label_to_id = node_ids |> Enum.with_index() |> Map.new()

    edges =
      for {src, dsts} <- out_edges,
          {dst, weight} <- dsts,
          reduce: [] do
        acc ->
          src_idx = Map.fetch!(label_to_id, src)
          dst_idx = Map.fetch!(label_to_id, dst)
          [{src_idx, dst_idx, to_float(weight)} | acc]
      end

    %__MODULE__{
      kind: kind,
      label_to_id: label_to_id,
      id_to_label: invert_map(label_to_id),
      nodes: Enum.reverse(node_ids),
      edges: Enum.reverse(edges),
      next_id: length(node_ids)
    }
  end

  @doc """
  Converts a `Yog.Builder.Labeled` into a `Zog` builder.

  Preserves the label-to-id mapping and edges.
  """
  @spec from_labeled(Yog.Builder.Labeled.t()) :: t()
  def from_labeled(%Yog.Builder.Labeled{
        kind: kind,
        graph: graph,
        label_to_id: label_to_id,
        next_id: next_id
      }) do
    edges =
      for {src, dsts} <- graph.out_edges,
          {dst, weight} <- dsts,
          reduce: [] do
        acc ->
          [{src, dst, to_float(weight)} | acc]
      end

    %__MODULE__{
      kind: kind,
      label_to_id: label_to_id,
      id_to_label: invert_map(label_to_id),
      nodes: Enum.reverse(labels_in_order(graph.nodes, next_id)),
      edges: Enum.reverse(edges),
      next_id: next_id
    }
  end

  # ============= Conversion to Yog.Graph =============

  @doc """
  Converts the builder back to a standard `Yog.Graph`.

  Node IDs in the resulting graph are the integer indices; node data
  is the original label.
  """
  @spec to_graph(t()) :: Yog.graph()
  def to_graph(%__MODULE__{kind: kind, nodes: nodes, edges: edges}) do
    base = Yog.new(kind)

    graph_with_nodes =
      Enum.reduce(Enum.with_index(Enum.reverse(nodes)), base, fn {label, idx}, g ->
        Yog.add_node(g, idx, label)
      end)

    Enum.reduce(edges, graph_with_nodes, fn {from, to, weight}, g ->
      case Yog.add_edge(g, from, to, weight) do
        {:ok, new_g} -> new_g
        {:error, _} -> g
      end
    end)
  end

  # ============= Queries =============

  @doc """
  Returns the number of nodes.
  """
  @spec node_count(t()) :: non_neg_integer()
  def node_count(%__MODULE__{next_id: next_id}), do: next_id

  @doc """
  Returns the number of directed edges stored.

  For undirected graphs this counts both directions.
  """
  @spec edge_count(t()) :: non_neg_integer()
  def edge_count(%__MODULE__{edges: edges}), do: length(edges)

  @doc """
  Returns the label for a given internal id.
  """
  @spec id_to_label(t(), id()) :: label() | nil
  def id_to_label(%__MODULE__{id_to_label: id_to_label}, id) do
    Map.get(id_to_label, id)
  end

  @doc """
  Returns the internal id for a given label.
  """
  @spec label_to_id(t(), label()) :: id() | nil
  def label_to_id(%__MODULE__{label_to_id: label_to_id}, label) do
    Map.get(label_to_id, label)
  end

  @doc """
  Returns all labels in insertion order (index = node id).
  """
  @spec all_labels(t()) :: [label()]
  def all_labels(%__MODULE__{nodes: nodes}), do: Enum.reverse(nodes)

  @doc """
  Returns all edges as `{from_id, to_id, weight}` tuples.
  """
  @spec all_edges(t()) :: [{id(), id(), float()}]
  def all_edges(%__MODULE__{edges: edges}), do: Enum.reverse(edges)

  @doc """
  Extracts edges as parallel arrays suitable for NIF passing.

  Returns `{[from_ids], [to_ids], [weights]}`.
  """
  @spec to_edge_arrays(t()) :: {[id()], [id()], [float()]}
  def to_edge_arrays(%__MODULE__{edges: edges}) do
    ordered = Enum.reverse(edges)
    froms = for {f, _, _} <- ordered, do: f
    tos = for {_, t, _} <- ordered, do: t
    weights = for {_, _, w} <- ordered, do: w
    {froms, tos, weights}
  end

  # ============= Private Helpers =============

  defp to_float(nil), do: 1.0
  defp to_float(n) when is_integer(n), do: n / 1.0
  defp to_float(n) when is_float(n), do: n
  defp to_float(_), do: 1.0

  defp invert_map(map) do
    Map.new(map, fn {k, v} -> {v, k} end)
  end

  defp labels_in_order(nodes, next_id) do
    0..(next_id - 1)
    |> Enum.map(&Map.get(nodes, &1))
  end
end
