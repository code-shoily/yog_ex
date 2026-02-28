defmodule YogMaxFlowTest do
  use ExUnit.Case

  alias Yog.MaxFlow

  # Helper functions for algorithms
  defp add(a, b), do: a + b
  defp subtract(a, b), do: a - b
  defp compare(a, b), do: if(a < b, do: :lt, else: if(a > b, do: :gt, else: :eq))
  defp min_fn(a, b), do: min(a, b)

  # Debug test: check if residual graph construction works
  test "residual_graph_construction_test" do
    _network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 10)

    # Manually build residual graph to test
    residual =
      Yog.new(:directed)
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_edge(from: 0, to: 1, weight: 10)
      |> Yog.add_edge(from: 1, to: 0, weight: 0)

    successors_0 = Yog.successors(residual, 0)
    successors_1 = Yog.successors(residual, 1)

    assert length(successors_0) == 1
    assert length(successors_1) == 1
  end

  # Basic test: simple network with one bottleneck
  test "simple_flow_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 10)
      |> Yog.add_edge(from: 1, to: 2, weight: 5)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 2,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    assert result.max_flow == 5
  end

  # Two parallel paths with different capacities
  test "parallel_paths_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 10)
      |> Yog.add_edge(from: 0, to: 2, weight: 10)
      |> Yog.add_edge(from: 1, to: 3, weight: 4)
      |> Yog.add_edge(from: 2, to: 3, weight: 9)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 3,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    # Flow limited by smaller path capacities: 4 + 9 = 13
    assert result.max_flow == 13
  end

  # Network with multiple paths and intermediate connections
  test "complex_network_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 10)
      |> Yog.add_edge(from: 0, to: 2, weight: 10)
      |> Yog.add_edge(from: 1, to: 2, weight: 2)
      |> Yog.add_edge(from: 1, to: 3, weight: 4)
      |> Yog.add_edge(from: 1, to: 4, weight: 8)
      |> Yog.add_edge(from: 2, to: 4, weight: 9)
      |> Yog.add_edge(from: 3, to: 5, weight: 10)
      |> Yog.add_edge(from: 4, to: 3, weight: 6)
      |> Yog.add_edge(from: 4, to: 5, weight: 10)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 5,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    assert result.max_flow == 19
  end

  # Classic textbook example
  test "textbook_example_test" do
    # From Cormen et al. "Introduction to Algorithms"
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 16)
      |> Yog.add_edge(from: 0, to: 2, weight: 13)
      |> Yog.add_edge(from: 1, to: 2, weight: 10)
      |> Yog.add_edge(from: 1, to: 3, weight: 12)
      |> Yog.add_edge(from: 2, to: 1, weight: 4)
      |> Yog.add_edge(from: 2, to: 4, weight: 14)
      |> Yog.add_edge(from: 3, to: 2, weight: 9)
      |> Yog.add_edge(from: 3, to: 5, weight: 20)
      |> Yog.add_edge(from: 4, to: 3, weight: 7)
      |> Yog.add_edge(from: 4, to: 5, weight: 4)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 5,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    assert result.max_flow == 23
  end

  # No path from source to sink
  test "no_path_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 10)
      |> Yog.add_edge(from: 2, to: 3, weight: 10)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 3,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    assert result.max_flow == 0
  end

  # Single edge network
  test "single_edge_test" do
    network = Yog.directed() |> Yog.add_edge(from: 0, to: 1, weight: 42)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 1,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    assert result.max_flow == 42
  end

  # Source equals sink (should be 0)
  test "source_equals_sink_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 10)
      |> Yog.add_edge(from: 1, to: 2, weight: 10)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 1,
        to: 1,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    assert result.max_flow == 0
  end

  # Zero capacity edges should be ignored
  test "zero_capacity_edges_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 0)
      |> Yog.add_edge(from: 0, to: 2, weight: 10)
      |> Yog.add_edge(from: 2, to: 1, weight: 10)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 1,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    assert result.max_flow == 10
  end

  # Bipartite matching as max flow
  test "bipartite_matching_test" do
    # Model bipartite matching as max flow:
    # Source (0) -> left partition (1,2) -> right partition (3,4) -> sink (5)
    # All edges have capacity 1
    network =
      Yog.directed()
      # Source to left partition
      |> Yog.add_edge(from: 0, to: 1, weight: 1)
      |> Yog.add_edge(from: 0, to: 2, weight: 1)
      # Left to right edges (potential matches)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 1, to: 4, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      # Right partition to sink
      |> Yog.add_edge(from: 3, to: 5, weight: 1)
      |> Yog.add_edge(from: 4, to: 5, weight: 1)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 5,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    # Maximum matching is 2
    assert result.max_flow == 2
  end

  # Min-cut extraction - simple case
  test "min_cut_simple_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 10)
      |> Yog.add_edge(from: 0, to: 2, weight: 10)
      |> Yog.add_edge(from: 1, to: 3, weight: 4)
      |> Yog.add_edge(from: 2, to: 3, weight: 9)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 3,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    cut = MaxFlow.min_cut(result: result, zero: 0, compare: &compare/2)

    # Source side should contain source
    assert MapSet.member?(cut.source_side, 0)
    # Sink side should contain sink
    assert MapSet.member?(cut.sink_side, 3)

    # All nodes should be in one side or the other
    total_size = MapSet.size(cut.source_side) + MapSet.size(cut.sink_side)
    assert total_size == 4
  end

  # Min-cut extraction - verify partitioning
  test "min_cut_partitioning_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 10)
      |> Yog.add_edge(from: 1, to: 2, weight: 5)
      |> Yog.add_edge(from: 2, to: 3, weight: 15)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 3,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    cut = MaxFlow.min_cut(result: result, zero: 0, compare: &compare/2)

    # Source and sink should be in different partitions
    assert MapSet.member?(cut.source_side, 0)
    assert MapSet.member?(cut.sink_side, 3)

    # Partitions should not overlap
    intersection = MapSet.intersection(cut.source_side, cut.sink_side)
    assert MapSet.size(intersection) == 0
  end

  # Triangle network with cycle
  test "triangle_with_cycle_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 10)
      |> Yog.add_edge(from: 1, to: 2, weight: 10)
      |> Yog.add_edge(from: 0, to: 2, weight: 5)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 2,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    # Direct path has capacity 5, path through 1 has capacity 10
    # Total flow should be 15
    assert result.max_flow == 15
  end

  # Multiple bottlenecks
  test "multiple_bottlenecks_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 100)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 100)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 3,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    # Bottleneck is the edge 1->2 with capacity 1
    assert result.max_flow == 1
  end

  # Diamond network
  test "diamond_network_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 10)
      |> Yog.add_edge(from: 0, to: 2, weight: 10)
      |> Yog.add_edge(from: 1, to: 3, weight: 10)
      |> Yog.add_edge(from: 2, to: 3, weight: 10)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 3,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    assert result.max_flow == 20
  end

  # Network with intermediate node having limited outgoing capacity
  test "limited_intermediate_capacity_test" do
    network =
      Yog.directed()
      |> Yog.add_edge(from: 0, to: 1, weight: 100)
      |> Yog.add_edge(from: 0, to: 2, weight: 100)
      |> Yog.add_edge(from: 1, to: 3, weight: 5)
      |> Yog.add_edge(from: 2, to: 3, weight: 7)
      |> Yog.add_edge(from: 3, to: 4, weight: 8)

    result =
      MaxFlow.edmonds_karp(
        in: network,
        from: 0,
        to: 4,
        zero: 0,
        add: &add/2,
        subtract: &subtract/2,
        compare: &compare/2,
        min: &min_fn/2
      )

    # Node 3 can receive 5+7=12 but can only send 8
    assert result.max_flow == 8
  end
end
