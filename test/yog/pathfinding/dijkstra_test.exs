defmodule Yog.Pathfinding.DijkstraTest do
  use ExUnit.Case
  alias Yog.Pathfinding.Dijkstra

  doctest Dijkstra

  # Helper functions for algorithms
  defp compare(a, b), do: if(a < b, do: :lt, else: if(a > b, do: :gt, else: :eq))
  defp add(a, b), do: a + b

  # ============= Basic Shortest Path Tests =============

  test "shortest_path_linear_test" do
    # 1 -> 2 -> 3
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)

    result = Dijkstra.shortest_path(graph, 1, 3, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    assert path.nodes == [1, 2, 3]
    assert path.weight == 15
  end

  test "shortest_path_direct_connection_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

    result = Dijkstra.shortest_path(graph, 1, 2, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    assert path.nodes == [1, 2]
    assert path.weight == 10
  end

  test "shortest_path_same_start_and_goal_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")

    result = Dijkstra.shortest_path(graph, 1, 1, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    assert path.nodes == [1]
    assert path.weight == 0
  end

  test "shortest_path_no_path_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    result = Dijkstra.shortest_path(graph, 1, 2, 0, &add/2, &compare/2)

    assert result == :error
  end

  test "shortest_path_invalid_start_test" do
    graph = Yog.directed()

    result = Dijkstra.shortest_path(graph, 99, 1, 0, &add/2, &compare/2)

    assert result == :error
  end

  test "shortest_path_invalid_goal_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")

    result = Dijkstra.shortest_path(graph, 1, 99, 0, &add/2, &compare/2)

    assert result == :error
  end

  # ============= Multiple Path Tests =============

  test "shortest_path_two_routes_test" do
    # Two routes from 1 to 3:
    # Route 1: 1 -> 2 -> 3 (cost 15)
    # Route 2: 1 -> 3 (cost 100)
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 100)

    result = Dijkstra.shortest_path(graph, 1, 3, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    assert path.weight == 15
  end

  test "shortest_path_direct_vs_indirect_test" do
    # Direct: 1 -> 3 (cost 100)
    # Indirect: 1 -> 2 -> 3 (cost 10)
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 5)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 100)

    result = Dijkstra.shortest_path(graph, 1, 3, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    assert path.nodes == [1, 2, 3]
    assert path.weight == 10
  end

  # ============= Diamond Graph Tests =============

  test "shortest_path_diamond_test" do
    # Diamond shape:
    #     1
    #    / \
    #   2   3
    #    \ /
    #     4
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Top")
      |> Yog.add_node(2, "Left")
      |> Yog.add_node(3, "Right")
      |> Yog.add_node(4, "Bottom")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 4)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 2)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 1)

    result = Dijkstra.shortest_path(graph, 1, 4, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    # Should take path 1 -> 2 -> 4 (cost 3) not 1 -> 3 -> 4 (cost 5)
    assert path.weight == 3
  end

  # ============= Cycle Tests =============

  test "shortest_path_with_cycle_test" do
    # Graph with cycle: 1 -> 2 -> 3 -> 1
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

    result = Dijkstra.shortest_path(graph, 1, 3, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    assert path.nodes == [1, 2, 3]
    assert path.weight == 15
  end

  # ============= Undirected Graph Tests =============

  test "shortest_path_undirected_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)

    result = Dijkstra.shortest_path(graph, 1, 3, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    assert path.weight == 15
  end

  # ============= Weight Variation Tests =============

  test "shortest_path_int_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)

    result = Dijkstra.shortest_path(graph, 1, 3)

    assert {:ok, path} = result
    assert path.nodes == [1, 2, 3]
    assert path.weight == 15
  end

  test "shortest_path_float_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5.5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10.5)

    result = Dijkstra.shortest_path(graph, 1, 3)

    assert {:ok, path} = result
    assert path.nodes == [1, 2, 3]
    assert path.weight == 16.0
  end

  test "shortest_path_zero_weights_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 0)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 0)

    result = Dijkstra.shortest_path(graph, 1, 3, 0, &add/2, &compare/2)

    assert {:ok, path} = result
    assert path.weight == 0
  end

  # ============= Single Source Distance Tests =============

  test "single_source_distances_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)

    distances = Dijkstra.single_source_distances(graph, 1, 0, &add/2, &compare/2)

    assert distances[1] == 0
    assert distances[2] == 5
    assert distances[3] == 15
  end

  test "single_source_distances_unreachable_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

    distances = Dijkstra.single_source_distances(graph, 1, 0, &add/2, &compare/2)

    assert distances[1] == 0
    assert distances[2] == 5
    # Node 3 is unreachable, so it won't be in the map
    assert Map.has_key?(distances, 3) == false
  end

  test "single_source_distances_complete_graph_test" do
    # Complete graph with 4 nodes
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 3)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 4)
      |> Yog.add_edge_ensure(from: 2, to: 4, with: 5)
      |> Yog.add_edge_ensure(from: 3, to: 4, with: 6)

    distances = Dijkstra.single_source_distances(graph, 1, 0, &add/2, &compare/2)

    assert distances[1] == 0
    assert distances[2] == 1
    assert distances[3] == 2
    assert distances[4] == 3
  end

  test "single_source_distances_isolated_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")

    distances = Dijkstra.single_source_distances(graph, 1, 0, &add/2, &compare/2)

    assert distances[1] == 0
    assert map_size(distances) == 1
  end

  test "single_source_distances_with_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)
      |> Yog.add_edge_ensure(from: 3, to: 1, with: 1)

    distances = Dijkstra.single_source_distances(graph, 1, 0, &add/2, &compare/2)

    assert distances[1] == 0
    assert distances[2] == 5
    assert distances[3] == 15
  end

  test "single_source_distances_undirected_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)

    distances = Dijkstra.single_source_distances(graph, 2, 0, &add/2, &compare/2)

    assert distances[1] == 5
    assert distances[2] == 0
    assert distances[3] == 10
  end

  test "single_source_distances_float_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5.5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10.5)

    compare_float = fn a, b -> if(a < b, do: :lt, else: if(a > b, do: :gt, else: :eq)) end

    distances = Dijkstra.single_source_distances(graph, 1, 0.0, &add/2, compare_float)

    assert distances[1] == 0.0
    assert distances[2] == 5.5
    assert distances[3] == 16.0
  end

  test "single_source_distances_star_graph_test" do
    # Star graph: 1 is center connected to 2, 3, 4, 5
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Center")
      |> Yog.add_node(2, "A")
      |> Yog.add_node(3, "B")
      |> Yog.add_node(4, "C")
      |> Yog.add_node(5, "D")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
      |> Yog.add_edge_ensure(from: 1, to: 3, with: 2)
      |> Yog.add_edge_ensure(from: 1, to: 4, with: 3)
      |> Yog.add_edge_ensure(from: 1, to: 5, with: 4)

    distances = Dijkstra.single_source_distances(graph, 1, 0, &add/2, &compare/2)

    assert distances[1] == 0
    assert distances[2] == 1
    assert distances[3] == 2
    assert distances[4] == 3
    assert distances[5] == 4
  end

  # ============= Implicit Dijkstra Tests =============

  test "implicit_dijkstra_linear_test" do
    # Linear chain: 1 -> 2 -> 3 -> 4
    successors = fn
      1 -> [{2, 1}]
      2 -> [{3, 2}]
      3 -> [{4, 3}]
      _ -> []
    end

    result =
      Dijkstra.implicit_dijkstra(
        1,
        successors,
        fn x -> x == 4 end,
        0,
        &add/2,
        &compare/2
      )

    assert {:ok, 6} = result
  end

  test "implicit_dijkstra_multiple_paths_test" do
    # Two paths from 1 to 3:
    # 1 -> 2 -> 3 (cost 15)
    # 1 -> 3 (cost 100)
    successors = fn
      1 -> [{2, 5}, {3, 100}]
      2 -> [{3, 10}]
      _ -> []
    end

    result =
      Dijkstra.implicit_dijkstra(
        1,
        successors,
        fn x -> x == 3 end,
        0,
        &add/2,
        &compare/2
      )

    assert {:ok, 15} = result
  end

  test "implicit_dijkstra_grid_test" do
    # 3x3 grid pathfinding
    successors = fn {x, y} ->
      [
        {{x + 1, y}, 1},
        {{x - 1, y}, 1},
        {{x, y + 1}, 1},
        {{x, y - 1}, 1}
      ]
      |> Enum.filter(fn {{nx, ny}, _} -> nx >= 0 and ny >= 0 and nx <= 2 and ny <= 2 end)
    end

    result =
      Dijkstra.implicit_dijkstra(
        {0, 0},
        successors,
        fn {x, y} -> x == 2 and y == 2 end,
        0,
        &add/2,
        &compare/2
      )

    # Manhattan distance from (0,0) to (2,2) is 4
    assert {:ok, 4} = result
  end

  test "implicit_dijkstra_unreachable_test" do
    successors = fn
      1 -> [{2, 1}]
      2 -> [{3, 2}]
      _ -> []
    end

    result =
      Dijkstra.implicit_dijkstra(
        1,
        successors,
        fn x -> x == 99 end,
        0,
        &add/2,
        &compare/2
      )

    assert result == :error
  end

  test "implicit_dijkstra_weighted_edges_test" do
    successors = fn
      1 -> [{2, 5}, {3, 100}]
      2 -> [{3, 10}]
      _ -> []
    end

    result =
      Dijkstra.implicit_dijkstra(
        1,
        successors,
        fn x -> x == 3 end,
        0,
        &add/2,
        &compare/2
      )

    # Should take path 1 -> 2 -> 3 (cost 15) not 1 -> 3 (cost 100)
    assert {:ok, 15} = result
  end

  test "implicit_dijkstra_by_test" do
    # Test with state deduplication using key function
    # States are {position, keys_collected}
    successors = fn {pos, keys} ->
      case pos do
        1 -> [{{2, keys}, 1}, {{3, MapSet.put(keys, :key_a)}, 1}]
        2 -> [{{4, keys}, 1}]
        3 -> [{{4, keys}, 1}]
        _ -> []
      end
    end

    key_fn = fn {pos, _keys} -> pos end

    result =
      Dijkstra.implicit_dijkstra_by(
        {1, MapSet.new()},
        successors,
        key_fn,
        fn {pos, _keys} -> pos == 4 end,
        0,
        &add/2,
        &compare/2
      )

    assert {:ok, 2} = result
  end

  # ============= Keyword API Tests =============

  test "shortest_path_keyword_api_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      |> Yog.add_edge_ensure(from: 2, to: 3, with: 10)

    result =
      Dijkstra.shortest_path(
        in: graph,
        from: 1,
        to: 3,
        zero: 0,
        add: &add/2,
        compare: &compare/2
      )

    assert {:ok, path} = result
    assert path.weight == 15
  end

  test "single_source_distances_keyword_api_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

    distances =
      Dijkstra.single_source_distances(
        in: graph,
        from: 1,
        zero: 0,
        add: &add/2,
        compare: &compare/2
      )

    assert distances[1] == 0
    assert distances[2] == 5
  end

  test "implicit_dijkstra_keyword_api_test" do
    successors = fn n -> if n < 5, do: [{n + 1, 1}], else: [] end

    result =
      Dijkstra.implicit_dijkstra(
        from: 1,
        successors_with_cost: successors,
        is_goal: fn n -> n == 5 end,
        zero: 0,
        add: &add/2,
        compare: &compare/2
      )

    assert {:ok, 4} = result
  end
end
