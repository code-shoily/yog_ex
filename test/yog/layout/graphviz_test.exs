defmodule Yog.Layout.GraphVizTest do
  use ExUnit.Case, async: true

  doctest Yog.Layout.GraphViz

  alias Yog.Layout.GraphViz

  @dot_available System.find_executable("dot") != nil
  @neato_available System.find_executable("neato") != nil

  describe "layout/2" do
    @tag if @dot_available, do: :graphviz, else: [skip: "GraphViz 'dot' executable not found"]
    test "positions nodes in a simple graph using dot engine" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: "1")

      # Since GraphViz is installed on this test machine, we expect coordinates to be computed
      pos = GraphViz.layout(graph, engine: :dot, position_scale: 10.0)

      assert Map.has_key?(pos, 1)
      assert Map.has_key?(pos, 2)

      {x1, y1} = pos[1]
      {x2, y2} = pos[2]

      assert is_float(x1) and is_float(y1)
      assert is_float(x2) and is_float(y2)
    end

    @tag if @neato_available, do: :graphviz, else: [skip: "GraphViz 'neato' executable not found"]
    test "positions nodes in a multigraph using neato engine" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(:server, "Server")
        |> Yog.Multi.add_node(:db, "Database")

      {multi, _} = Yog.Multi.add_edge(multi, :server, :db, 5.0)

      pos = GraphViz.layout(multi, engine: :neato)

      assert Map.has_key?(pos, :server)
      assert Map.has_key?(pos, :db)

      {x1, y1} = pos[:server]
      {x2, y2} = pos[:db]

      assert is_float(x1) and is_float(y1)
      assert is_float(x2) and is_float(y2)
    end

    test "raises RuntimeError on missing graphviz engine executable" do
      graph = Yog.directed() |> Yog.add_nodes_from([1, 2])

      assert_raise RuntimeError, ~r/GraphViz executable 'non_existent_engine' not found/, fn ->
        GraphViz.layout(graph, engine: :non_existent_engine)
      end
    end
  end
end
