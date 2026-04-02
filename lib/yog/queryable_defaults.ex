defmodule Yog.Queryable.Defaults do
  @moduledoc """
  Default implementations for `Yog.Queryable` functions.

  These implementations derive functionality from the core query functions:
  - `successors/2`
  - `predecessors/2`
  - `type/1`
  - `node/2`
  - `all_nodes/1`
  - `order/1`
  - `edge_count/1`

  Graph implementations can use these defaults or override for efficiency.
  For example, `out_degree/2` defaults to `length(successors(graph, id))`,
  but implementations with O(1) degree tracking should override it.
  """

  alias Yog.Queryable, as: Model

  @doc "Default: out_degree is length of successors"
  def out_degree(graph, id) do
    length(Model.successors(graph, id))
  end

  @doc "Default: in_degree is length of predecessors"
  def in_degree(graph, id) do
    length(Model.predecessors(graph, id))
  end

  @doc "Default: degree is out + in"
  def degree(graph, id) do
    Model.out_degree(graph, id) + Model.in_degree(graph, id)
  end

  @doc "Default: extract IDs from successors"
  def successor_ids(graph, id) do
    graph
    |> Model.successors(id)
    |> Enum.map(&elem(&1, 0))
  end

  @doc "Default: extract IDs from predecessors"
  def predecessor_ids(graph, id) do
    graph
    |> Model.predecessors(id)
    |> Enum.map(&elem(&1, 0))
  end

  @doc "Default: merge successors and predecessors (successors win on conflict)"
  def neighbors(graph, id) do
    succs = Model.successors(graph, id) |> Map.new()
    preds = Model.predecessors(graph, id) |> Map.new()

    Map.merge(preds, succs) |> Map.to_list()
  end

  @doc "Default: unique union of successor and predecessor IDs"
  def neighbor_ids(graph, id) do
    succs = Model.successor_ids(graph, id) |> MapSet.new()
    preds = Model.predecessor_ids(graph, id) |> MapSet.new()

    MapSet.union(succs, preds) |> MapSet.to_list()
  end

  @doc "Default: check membership in all_nodes"
  def has_node?(graph, id) do
    id in Model.all_nodes(graph)
  end

  @doc "Default: search for dst in successors of src"
  def has_edge?(graph, src, dst) do
    graph
    |> Model.successors(src)
    |> Enum.any?(fn {id, _} -> id == dst end)
  end

  @doc "Default: build map from all_nodes and their data"
  def nodes(graph) do
    graph
    |> Model.all_nodes()
    |> Map.new(fn id -> {id, Model.node(graph, id)} end)
  end

  @doc "Default: iterate all nodes and their successors"
  def all_edges(graph) do
    graph
    |> Model.all_nodes()
    |> Enum.flat_map(fn src ->
      graph
      |> Model.successors(src)
      |> Enum.map(fn {dst, weight} -> {src, dst, weight} end)
    end)
  end

  @doc "Default: find weight in successors of src"
  def edge_data(graph, src, dst) do
    graph
    |> Model.successors(src)
    |> Enum.find_value(fn {id, weight} -> if id == dst, do: weight end)
  end

  @doc "Default: node_count is alias for order"
  def node_count(graph) do
    Model.order(graph)
  end
end
