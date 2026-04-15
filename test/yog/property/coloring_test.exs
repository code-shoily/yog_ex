defmodule Yog.Property.ColoringTest do
  use ExUnit.Case

  alias Yog.Property.Coloring
  alias Yog.Generator.Classic

  doctest Yog.Property.Coloring

  # ============= Validation Helpers =============

  defp valid_coloring?(graph, colors) do
    Enum.all?(Yog.Model.all_nodes(graph), fn node ->
      node_color = Map.get(colors, node)

      is_integer(node_color) and node_color >= 1 and
        Enum.all?(Yog.Model.neighbor_ids(graph, node), fn neighbor ->
          neighbor_color = Map.get(colors, neighbor)
          is_nil(neighbor_color) or node_color != neighbor_color
        end)
    end)
  end

  # ============= Greedy Coloring Tests =============

  test "greedy colors empty graph with 0 colors" do
    graph = Classic.empty(0)
    {upper, colors} = Coloring.coloring_greedy(graph)
    assert upper == 0
    assert colors == %{}
  end

  test "greedy colors isolated nodes with 1 color" do
    graph = Classic.empty(5)
    {upper, colors} = Coloring.coloring_greedy(graph)
    assert upper == 1
    assert valid_coloring?(graph, colors)
    assert map_size(colors) == 5
  end

  test "greedy colors complete graph K_n with n colors" do
    for n <- 1..6 do
      graph = Classic.complete(n)
      {upper, colors} = Coloring.coloring_greedy(graph)
      assert upper == n, "K_#{n} should need #{n} colors, got #{upper}"
      assert valid_coloring?(graph, colors)
    end
  end

  test "greedy colors bipartite graph with 2 colors" do
    graph = Classic.complete_bipartite(3, 4)
    {upper, colors} = Coloring.coloring_greedy(graph)
    assert upper == 2
    assert valid_coloring?(graph, colors)
  end

  test "greedy colors even cycle with 2 colors" do
    graph = Classic.cycle(6)
    {upper, colors} = Coloring.coloring_greedy(graph)
    assert upper == 2
    assert valid_coloring?(graph, colors)
  end

  test "greedy colors odd cycle with 3 colors" do
    graph = Classic.cycle(5)
    {upper, colors} = Coloring.coloring_greedy(graph)
    assert upper == 3
    assert valid_coloring?(graph, colors)
  end

  # ============= DSatur Tests =============

  test "dsatur colors empty graph with 0 colors" do
    graph = Classic.empty(0)
    {upper, colors} = Coloring.coloring_dsatur(graph)
    assert upper == 0
    assert colors == %{}
  end

  test "dsatur colors isolated nodes with 1 color" do
    graph = Classic.empty(5)
    {upper, colors} = Coloring.coloring_dsatur(graph)
    assert upper == 1
    assert valid_coloring?(graph, colors)
  end

  test "dsatur colors complete graph K_n with n colors" do
    for n <- 1..6 do
      graph = Classic.complete(n)
      {upper, colors} = Coloring.coloring_dsatur(graph)
      assert upper == n, "K_#{n} should need #{n} colors, got #{upper}"
      assert valid_coloring?(graph, colors)
    end
  end

  test "dsatur colors bipartite graph with 2 colors" do
    graph = Classic.complete_bipartite(3, 4)
    {upper, colors} = Coloring.coloring_dsatur(graph)
    assert upper == 2
    assert valid_coloring?(graph, colors)
  end

  test "dsatur matches or beats greedy on various graphs" do
    graphs = [
      Classic.complete(5),
      Classic.cycle(5),
      Classic.cycle(6),
      Classic.complete_bipartite(3, 3),
      Classic.path(10),
      Classic.star(6),
      Classic.wheel(6),
      Classic.petersen()
    ]

    for graph <- graphs do
      {greedy_upper, _} = Coloring.coloring_greedy(graph)
      {dsatur_upper, dsatur_colors} = Coloring.coloring_dsatur(graph)

      assert valid_coloring?(graph, dsatur_colors)

      assert dsatur_upper <= greedy_upper,
             "DSatur should beat or match greedy"
    end
  end

  test "dsatur colors petersen graph with 3 colors" do
    graph = Classic.petersen()
    {upper, colors} = Coloring.coloring_dsatur(graph)
    assert upper == 3
    assert valid_coloring?(graph, colors)
  end

  # ============= Exact Coloring Tests =============

  test "exact coloring finds optimal for empty graph" do
    graph = Classic.empty(0)
    assert {:ok, 0, %{}} = Coloring.coloring_exact(graph)
  end

  test "exact coloring finds optimal for isolated nodes" do
    graph = Classic.empty(5)
    assert {:ok, 1, colors} = Coloring.coloring_exact(graph)
    assert valid_coloring?(graph, colors)
  end

  test "exact coloring finds optimal for complete graph" do
    for n <- 1..6 do
      graph = Classic.complete(n)
      assert {:ok, chi, colors} = Coloring.coloring_exact(graph)
      assert chi == n, "K_#{n} chromatic number should be #{n}, got #{chi}"
      assert valid_coloring?(graph, colors)
    end
  end

  test "exact coloring finds optimal for bipartite graph" do
    graph = Classic.complete_bipartite(3, 4)
    assert {:ok, 2, colors} = Coloring.coloring_exact(graph)
    assert valid_coloring?(graph, colors)
  end

  test "exact coloring finds optimal for cycles" do
    even_cycle = Classic.cycle(6)
    assert {:ok, 2, colors} = Coloring.coloring_exact(even_cycle)
    assert valid_coloring?(even_cycle, colors)

    odd_cycle = Classic.cycle(5)
    assert {:ok, 3, colors} = Coloring.coloring_exact(odd_cycle)
    assert valid_coloring?(odd_cycle, colors)
  end

  test "exact coloring finds optimal for petersen graph" do
    graph = Classic.petersen()
    assert {:ok, 3, colors} = Coloring.coloring_exact(graph)
    assert valid_coloring?(graph, colors)
  end

  test "exact coloring finds optimal for path graph" do
    graph = Classic.path(10)
    assert {:ok, 2, colors} = Coloring.coloring_exact(graph)
    assert valid_coloring?(graph, colors)
  end

  test "exact coloring finds optimal for star graph" do
    graph = Classic.star(6)
    assert {:ok, 2, colors} = Coloring.coloring_exact(graph)
    assert valid_coloring?(graph, colors)
  end

  test "exact coloring finds optimal for wheel graph" do
    # W_6 (6 rim nodes + 1 hub) = 7 nodes total, odd cycle rim -> chromatic number 4
    graph = Classic.wheel(6)
    assert {:ok, 4, colors} = Coloring.coloring_exact(graph)
    assert valid_coloring?(graph, colors)

    # W_5 (5 rim nodes + 1 hub) = 6 nodes total, even cycle rim -> chromatic number 3
    graph = Classic.wheel(5)
    assert {:ok, 3, colors} = Coloring.coloring_exact(graph)
    assert valid_coloring?(graph, colors)
  end

  test "exact coloring returns consistent colors for disconnected graph" do
    # Two disconnected triangles
    graph =
      Yog.undirected()
      |> Yog.add_edge_ensure(1, 2, 1, nil)
      |> Yog.add_edge_ensure(2, 3, 1, nil)
      |> Yog.add_edge_ensure(3, 1, 1, nil)
      |> Yog.add_edge_ensure(4, 5, 1, nil)
      |> Yog.add_edge_ensure(5, 6, 1, nil)
      |> Yog.add_edge_ensure(6, 4, 1, nil)

    assert {:ok, 3, colors} = Coloring.coloring_exact(graph)
    assert valid_coloring?(graph, colors)
  end

  test "exact coloring respects timeout" do
    # Large complete graph should still be fast, but we can test the API
    graph = Classic.complete(20)
    assert {:ok, 20, _colors} = Coloring.coloring_exact(graph, 100)
  end
end
