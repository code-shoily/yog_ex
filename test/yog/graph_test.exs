defmodule Yog.GraphTest do
  use ExUnit.Case

  doctest Yog.Graph
  doctest Enumerable.Yog.Graph
  doctest Inspect.Yog.Graph

  alias Yog.Graph
  alias Yog.Model

  test "edge_count with self-loops (directed)" do
    graph =
      Graph.new(:directed)
      |> Model.add_node(1, "A")
      |> Model.add_edge!(1, 1, 10)

    # 1 directed self-loop = 1 edge
    assert Graph.edge_count(graph) == 1
  end

  test "edge_count with self-loops (undirected)" do
    graph =
      Graph.new(:undirected)
      |> Model.add_node(1, "A")
      |> Model.add_edge!(1, 1, 10)

    # 1 undirected self-loop = 1 edge
    assert Graph.edge_count(graph) == 1
  end

  test "edge_count complex with self-loops (undirected)" do
    # 2 nodes, 1 normal edge, 1 self-loop = 2 edges
    graph =
      Graph.new(:undirected)
      |> Model.add_node(1, "A")
      |> Model.add_node(2, "B")
      |> Model.add_edge!(1, 2, 10)
      |> Model.add_edge!(1, 1, 5)

    assert Graph.edge_count(graph) == 2
  end
end
