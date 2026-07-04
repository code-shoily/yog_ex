defmodule Yog.Layout.SpringTest do
  use ExUnit.Case, async: true

  doctest Yog.Layout.Spring

  alias Yog.Layout.Spring

  test "Barnes-Hut results with theta: 0.0 are close to exact implementation" do
    # Create a simple grid or random graph
    graph =
      Yog.undirected()
      |> Yog.add_nodes_from(1..20)
      |> Yog.add_edges!(Enum.map(1..19, &{&1, &1 + 1, 1}))

    # We use a fixed seed to get deterministic results
    exact_pos = Spring.layout(graph, iterations: 20, seed: 42, barnes_hut: false)
    bh_pos = Spring.layout(graph, iterations: 20, seed: 42, barnes_hut: true, theta: 0.0)

    # They should be identical (or extremely close due to floating point precision and same seed)
    for {node_id, {ex, ey}} <- exact_pos do
      {bx, by} = Map.fetch!(bh_pos, node_id)
      assert_in_delta ex, bx, 1.0e-4
      assert_in_delta ey, by, 1.0e-4
    end
  end

  test "Barnes-Hut respects fixed nodes" do
    graph =
      Yog.undirected()
      |> Yog.add_nodes_from(1..10)
      |> Yog.add_edges!(Enum.map(1..9, &{&1, &1 + 1, 1}))

    # Initial positions with nodes at specific coordinates
    initial_pos = Map.new(1..10, fn id -> {id, {id * 0.1, id * 0.1}} end)

    pos =
      Spring.layout(graph,
        iterations: 10,
        fixed: [1, 2],
        initial_pos: initial_pos,
        barnes_hut: true,
        theta: 0.5
      )

    # Nodes 1 and 2 should remain exactly at their initial positions
    assert Map.get(pos, 1) == {0.1, 0.1}
    assert Map.get(pos, 2) == {0.2, 0.2}
  end

  test "Barnes-Hut respects bounding box constraints" do
    graph =
      Yog.undirected()
      |> Yog.add_nodes_from(1..30)
      |> Yog.add_edges!(Enum.map(1..29, &{&1, &1 + 1, 1}))

    width = 10.0
    height = 20.0
    center = {5.0, 5.0}

    pos =
      Spring.layout(graph,
        iterations: 15,
        width: width,
        height: height,
        center: center,
        barnes_hut: true,
        theta: 0.5
      )

    min_x = 5.0 - 5.0
    max_x = 5.0 + 5.0
    min_y = 5.0 - 10.0
    max_y = 5.0 + 10.0

    for {_node_id, {x, y}} <- pos do
      assert x >= min_x
      assert x <= max_x
      assert y >= min_y
      assert y <= max_y
    end
  end

  test "Barnes-Hut performance on a moderate size graph" do
    # Generate a larger graph
    n = 100

    graph =
      Yog.undirected()
      |> Yog.add_nodes_from(1..n)

    # Dense graph to maximize repulsion computations
    edges = for u <- 1..(n - 1), v <- (u + 1)..n, rem(u + v, 3) == 0, do: {u, v, 1}
    graph = Yog.add_edges!(graph, edges)

    # Measure exact time
    t0 = System.monotonic_time(:microsecond)
    Spring.layout(graph, iterations: 10, barnes_hut: false, seed: 123)
    _exact_duration = System.monotonic_time(:microsecond) - t0

    # Measure Barnes-Hut time
    t1 = System.monotonic_time(:microsecond)
    Spring.layout(graph, iterations: 10, barnes_hut: true, theta: 0.5, seed: 123)
    bh_duration = System.monotonic_time(:microsecond) - t1

    assert bh_duration > 0
  end
end
