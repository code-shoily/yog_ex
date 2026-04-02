defmodule Yog.DAG.Graph do
  @moduledoc """
  Internal implementation of the Directed Acyclic Graph (DAG) structure.

  This module defines the `%Yog.DAG.Graph{}` struct and implements the
  core graph protocols.
  """

  @type t :: %__MODULE__{
          graph: Yog.Graph.t()
        }

  @enforce_keys [:graph]
  defstruct [:graph]
end

defimpl Yog.Queryable, for: Yog.DAG.Graph do
  def successors(dag, id), do: Yog.Queryable.successors(dag.graph, id)
  def predecessors(dag, id), do: Yog.Queryable.predecessors(dag.graph, id)
  def neighbors(dag, id), do: Yog.Queryable.neighbors(dag.graph, id)
  def successor_ids(dag, id), do: Yog.Queryable.successor_ids(dag.graph, id)
  def predecessor_ids(dag, id), do: Yog.Queryable.predecessor_ids(dag.graph, id)
  def neighbor_ids(dag, id), do: Yog.Queryable.neighbor_ids(dag.graph, id)
  def all_nodes(dag), do: Yog.Queryable.all_nodes(dag.graph)
  def order(dag), do: Yog.Queryable.order(dag.graph)
  def node_count(dag), do: Yog.Queryable.node_count(dag.graph)
  def edge_count(dag), do: Yog.Queryable.edge_count(dag.graph)
  def out_degree(dag, id), do: Yog.Queryable.out_degree(dag.graph, id)
  def in_degree(dag, id), do: Yog.Queryable.in_degree(dag.graph, id)
  def degree(dag, id), do: Yog.Queryable.degree(dag.graph, id)
  def has_node?(dag, id), do: Yog.Queryable.has_node?(dag.graph, id)
  def has_edge?(dag, src, dst), do: Yog.Queryable.has_edge?(dag.graph, src, dst)
  def node(dag, id), do: Yog.Queryable.node(dag.graph, id)
  def nodes(dag), do: Yog.Queryable.nodes(dag.graph)
  def edge_data(dag, src, dst), do: Yog.Queryable.edge_data(dag.graph, src, dst)
  def all_edges(dag), do: Yog.Queryable.all_edges(dag.graph)
  def type(dag), do: Yog.Queryable.type(dag.graph)
end

defimpl Yog.Modifiable, for: Yog.DAG.Graph do
  alias Yog.DAG.Model

  def add_node(dag, id, data), do: Model.add_node(dag, id, data)
  def remove_node(dag, id), do: Model.remove_node(dag, id)
  def add_edge(dag, src, dst, weight), do: Model.add_edge(dag, src, dst, weight)
  def add_edges(dag, edges), do: Model.add_edges(dag, edges)
  def remove_edge(dag, src, dst), do: Model.remove_edge(dag, src, dst)

  def add_edge_ensure(dag, src, dst, weight, default_data),
    do: Model.add_edge_ensure(dag, src, dst, weight, default_data)

  def add_edge_with_combine(dag, src, dst, weight, with_combine),
    do: Model.add_edge_with_combine(dag, src, dst, weight, with_combine)
end

defimpl Enumerable, for: Yog.DAG.Graph do
  def count(%Yog.DAG.Graph{graph: graph}), do: Enumerable.count(graph)
  def member?(%Yog.DAG.Graph{graph: graph}, element), do: Enumerable.member?(graph, element)
  def reduce(%Yog.DAG.Graph{graph: graph}, acc, fun), do: Enumerable.reduce(graph, acc, fun)
  def slice(%Yog.DAG.Graph{graph: graph}), do: Enumerable.slice(graph)
end

defimpl Yog.Transformable, for: Yog.DAG.Graph do
  alias Yog.DAG.Model

  def empty(%Yog.DAG.Graph{graph: graph}) do
    %Yog.DAG.Graph{graph: Yog.Transformable.empty(graph)}
  end

  def empty(%Yog.DAG.Graph{graph: graph}, kind) do
    %Yog.DAG.Graph{graph: Yog.Transformable.empty(graph, kind)}
  end

  @doc """
  Transpose reverses all edges. For a DAG, this maintains acyclicity
  (the transpose of a DAG is still a DAG, just with reversed edges).
  """
  def transpose(%Yog.DAG.Graph{graph: graph}) do
    %Yog.DAG.Graph{graph: Yog.Transformable.transpose(graph)}
  end

  def map_nodes(%Yog.DAG.Graph{graph: graph}, fun) do
    %Yog.DAG.Graph{graph: Yog.Transformable.map_nodes(graph, fun)}
  end

  def map_edges(%Yog.DAG.Graph{graph: graph}, fun) do
    %Yog.DAG.Graph{graph: Yog.Transformable.map_edges(graph, fun)}
  end
end

defimpl Inspect, for: Yog.DAG.Graph do
  import Inspect.Algebra

  alias Yog.Queryable, as: QueryModel

  def inspect(%Yog.DAG.Graph{graph: graph}, _opts) do
    node_count = QueryModel.node_count(graph)
    edge_count = QueryModel.edge_count(graph)

    node_str = if node_count == 1, do: "node", else: "nodes"
    edge_str = if edge_count == 1, do: "edge", else: "edges"

    concat([
      "#Yog.DAG.Graph<",
      "#{node_count} #{node_str}, ",
      "#{edge_count} #{edge_str}",
      ">"
    ])
  end
end
