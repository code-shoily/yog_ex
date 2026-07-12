defmodule Yog.Functional.Transform do
  @moduledoc """
  Higher-order transformations for inductive graphs — map, filter, fold, and
  direction changes.

  This module provides whole-graph transformations for `Yog.Functional.Model`.
  The functions are intentionally small and explicit: they transform existing
  contexts, remove nodes through `Model.remove_node/2`, or reinterpret/symmetrize
  graph direction.

  ## Available Transformations

  | Transformation | Function | Description |
  |----------------|----------|-------------|
  | Map Nodes | `map_nodes/2` | Transform node contexts |
  | Map Labels | `map_labels/2` | Transform node labels |
  | Map Edge Labels | `map_edge_labels/2` | Transform edge labels |
  | Filter | `filter_nodes/2` | Remove nodes whose context does not satisfy a predicate |
  | Fold | `fold_nodes/3` | Accumulate over all node contexts |
  | Reverse | `reverse/1` | Flip edge directions in a directed graph |
  | To Directed | `to_directed/1` | Reinterpret a graph as directed |
  | To Undirected | `to_undirected/1` | Symmetrize directed edges and mark the graph undirected |

  ## Caveats

  - `map_nodes/2` is a low-level context transform. Prefer `map_labels/2` when
    changing only labels. If a `map_nodes/2` callback changes a context's `id` or
    edge maps directly, the caller is responsible for preserving graph invariants.
  - `to_directed/1` only changes the graph direction flag. It does not remove
    symmetric edge entries that may already exist in an undirected graph.
  - `to_undirected/1` symmetrizes every existing directed edge by inserting both
    directions. If both directions already exist with different labels, the final
    label is whichever edge is processed last by map iteration order; avoid relying
    on that case unless labels are identical.

  ## Complexity

  Most transformations are `O(V + E)` where `V` is the number of nodes and `E` is
  the number of stored edge entries. `fold_nodes/3` is `O(V)`.
  """

  alias Yog.Functional.Model

  @doc """
  Performs a map operation over all node contexts in the graph.

  This is the most general node transform. The returned context is stored under
  the original node key, so callbacks should normally preserve `ctx.id` and should
  avoid editing `in_edges` / `out_edges` unless they intentionally maintain those
  invariants themselves. For label-only updates, prefer `map_labels/2`.

  ## Examples

      iex> alias Yog.Functional.{Model, Transform}
      iex> graph = Model.empty() |> Model.put_node(1, "A")
      iex> graph = Transform.map_nodes(graph, fn ctx -> %{ctx | label: "B"} end)
      iex> {:ok, ctx} = Model.get_node(graph, 1)
      iex> ctx.label
      "B"
  """
  @spec map_nodes(Model.t(), (Model.Context.t() -> Model.Context.t())) :: Model.t()
  def map_nodes(%Model{nodes: nodes} = graph, fun) do
    new_nodes = Map.new(nodes, fn {id, ctx} -> {id, fun.(ctx)} end)
    %{graph | nodes: new_nodes}
  end

  @doc """
  Filters nodes in the graph based on a predicate function.

  Contexts for which the predicate returns `true` are kept. Removed nodes are
  deleted via `Model.remove_node/2`, so incident edge references are also removed
  from surviving nodes. The graph direction is preserved.
  """
  @spec filter_nodes(Model.t(), (Model.Context.t() -> boolean())) :: Model.t()
  def filter_nodes(%Model{nodes: nodes} = graph, fun) do
    nodes_to_remove =
      nodes
      |> Enum.reject(fn {_id, ctx} -> fun.(ctx) end)
      |> Enum.map(fn {id, _ctx} -> id end)

    Enum.reduce(nodes_to_remove, graph, fn id, acc ->
      {:ok, new_graph} = Model.remove_node(acc, id)
      new_graph
    end)
  end

  @doc """
  Folds over all node contexts in the graph.

  The iteration order follows map iteration order and should be treated as
  unspecified. Use this for order-independent reductions or normalize the result
  afterwards if order matters.
  """
  @spec fold_nodes(Model.t(), acc, (Model.Context.t(), acc -> acc)) :: acc when acc: any()
  def fold_nodes(%Model{nodes: nodes}, initial, fun) do
    Enum.reduce(nodes, initial, fn {_id, ctx}, acc -> fun.(ctx, acc) end)
  end

  @doc "Transforms the labels of all nodes using the given function, preserving IDs and edges."
  @spec map_labels(Model.t(), (Model.node_label() -> Model.node_label())) :: Model.t()
  def map_labels(graph, fun) do
    map_nodes(graph, fn ctx -> %{ctx | label: fun.(ctx.label)} end)
  end

  @doc """
  Transforms the labels of all stored edge entries using the given function.

  In undirected graphs, edges are represented symmetrically, so both stored
  directions are transformed. The graph direction is preserved.

  ## Examples

      iex> alias Yog.Functional.{Model, Transform}
      iex> graph = Model.empty() |> Model.put_node(1, "A") |> Model.put_node(2, "B")
      ...> |> Model.add_edge!(1, 2, 10)
      iex> graph = Transform.map_edge_labels(graph, fn label -> label * 2 end)
      iex> Model.get_edge(graph, 1, 2)
      {:ok, 20}
  """
  @spec map_edge_labels(Model.t(), (Model.edge_label() -> Model.edge_label())) :: Model.t()
  def map_edge_labels(graph, fun) do
    map_nodes(graph, fn ctx ->
      %{
        ctx
        | in_edges: Map.new(ctx.in_edges, fn {id, label} -> {id, fun.(label)} end),
          out_edges: Map.new(ctx.out_edges, fn {id, label} -> {id, fun.(label)} end)
      }
    end)
  end

  @doc """
  Reverses the direction of all edges in a directed graph.

  For undirected graphs, reversing is an identity operation because both
  directions are already represented. The graph direction is preserved.

  ## Examples

      iex> alias Yog.Functional.{Model, Transform}
      iex> graph = Model.empty() |> Model.put_node(1, "A") |> Model.put_node(2, "B")
      ...> |> Model.add_edge!(1, 2)
      iex> graph = Transform.reverse(graph)
      iex> Model.has_edge?(graph, 2, 1)
      true
      iex> Model.has_edge?(graph, 1, 2)
      false
  """
  @spec reverse(Model.t()) :: Model.t()
  def reverse(%Model{direction: :directed} = graph) do
    map_nodes(graph, fn ctx ->
      %{ctx | in_edges: ctx.out_edges, out_edges: ctx.in_edges}
    end)
  end

  def reverse(%Model{direction: :undirected} = graph), do: graph

  @doc """
  Reinterprets a graph as directed.

  This changes only the `direction` field. It does not remove any symmetric edge
  entries that may exist because the graph used to be undirected.
  """
  @spec to_directed(Model.t()) :: Model.t()
  def to_directed(%Model{} = graph) do
    %{graph | direction: :directed}
  end

  @doc """
  Converts a directed graph to an undirected one by symmetrizing edges.

  Every stored directed edge `u -> v` becomes an undirected connection represented
  internally as both `u -> v` and `v -> u`. If opposite directed edges already
  exist with different labels, the final undirected label depends on map iteration
  order; use identical labels when deterministic conflict resolution matters.
  """
  @spec to_undirected(Model.t()) :: Model.t()
  def to_undirected(%Model{direction: :undirected} = graph), do: graph

  def to_undirected(%Model{direction: :directed} = graph) do
    new_graph = %{graph | direction: :undirected}

    fold_nodes(graph, new_graph, fn ctx, acc ->
      Enum.reduce(ctx.out_edges, acc, fn {neighbor_id, label}, inner_acc ->
        Model.add_undirected_edge!(inner_acc, ctx.id, neighbor_id, label)
      end)
    end)
  end
end
