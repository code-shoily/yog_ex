defmodule Yog.Layout.GridTest do
  use ExUnit.Case, async: true

  doctest Yog.Layout.Grid

  alias Yog.Layout.Grid

  describe "layout/2" do
    test "positions nodes in rows" do
      graph = Yog.undirected() |> Yog.add_nodes_from([:client, :api, :worker, :db, :cache])

      pos =
        Grid.layout(graph,
          rows: [[:client], [:api, :worker], [:db, :cache]],
          cell: {100.0, 50.0},
          origin: {10.0, 20.0}
        )

      assert pos[:client] == {10.0, 20.0}
      assert pos[:api] == {10.0, 70.0}
      assert pos[:worker] == {110.0, 70.0}
      assert pos[:db] == {10.0, 120.0}
      assert pos[:cache] == {110.0, 120.0}
    end

    test "positions nodes in columns" do
      graph = Yog.undirected() |> Yog.add_nodes_from([:client, :api, :worker, :db, :cache])

      pos =
        Grid.layout(graph,
          columns: [[:client], [:api, :worker], [:db, :cache]],
          cell: {100.0, 50.0},
          origin: {10.0, 20.0}
        )

      assert pos[:client] == {10.0, 20.0}
      assert pos[:api] == {110.0, 20.0}
      assert pos[:worker] == {110.0, 70.0}
      assert pos[:db] == {210.0, 20.0}
      assert pos[:cache] == {210.0, 70.0}
    end

    test "skips placeholders nil and :_" do
      graph = Yog.undirected() |> Yog.add_nodes_from([:client, :api, :db])

      pos =
        Grid.layout(graph,
          rows: [[:client, nil], [:api, :_], [nil, :db]],
          cell: {10.0, 10.0},
          origin: {0.0, 0.0}
        )

      assert pos[:client] == {0.0, 0.0}
      assert pos[:api] == {0.0, 10.0}
      assert pos[:db] == {10.0, 20.0}
      refute Map.has_key?(pos, nil)
      refute Map.has_key?(pos, :_)
    end

    test "raises ArgumentError when both or neither rows and columns are given" do
      graph = Yog.undirected() |> Yog.add_nodes_from([1, 2])

      assert_raise ArgumentError, ~r/Must specify either :rows or :columns, not both/, fn ->
        Grid.layout(graph, rows: [[1]], columns: [[2]])
      end

      assert_raise ArgumentError, ~r/Must specify either :rows or :columns/, fn ->
        Grid.layout(graph, [])
      end
    end

    test "raises ArgumentError on duplicate node IDs" do
      graph = Yog.undirected() |> Yog.add_nodes_from([1, 2])

      assert_raise ArgumentError, ~r/Grid contains duplicate node IDs/, fn ->
        Grid.layout(graph, rows: [[1, 2, 1]])
      end
    end

    test "raises ArgumentError on extra node IDs" do
      graph = Yog.undirected() |> Yog.add_nodes_from([1, 2])

      assert_raise ArgumentError, ~r/Grid contains node IDs not present in the graph/, fn ->
        Grid.layout(graph, rows: [[1, 2, 99]])
      end
    end

    test "raises ArgumentError on missing node IDs" do
      graph = Yog.undirected() |> Yog.add_nodes_from([1, 2, 3])

      assert_raise ArgumentError, ~r/Graph contains node IDs missing from the grid/, fn ->
        Grid.layout(graph, rows: [[1, 2]])
      end
    end
  end
end
