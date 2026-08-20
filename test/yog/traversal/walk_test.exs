defmodule Yog.Traversal.WalkTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Yog.Traversal.Walk

  alias Yog.Traversal.Walk

  describe "walk/1 and walk/3" do
    test "traverses connected nodes in BFS order" do
      g = Yog.from_edges(:directed, [{1, 2, 1}, {1, 3, 1}, {2, 4, 1}])
      assert Walk.walk(in: g, from: 1, using: :breadth_first) == [1, 2, 3, 4]
      assert Walk.walk(g, 1, :breadth_first) == [1, 2, 3, 4]
    end

    test "handles unindexed starting node by visiting start node" do
      g = Yog.directed() |> Yog.add_node(1, nil)
      assert Walk.walk(in: g, from: 999, using: :breadth_first) == [999]
    end

    test "raises ArgumentError on invalid options or graph" do
      assert_raise ArgumentError, ~r/expected a Yog.Graph or Yog.DAG struct/, fn ->
        Walk.walk(in: :invalid, from: 1, using: :breadth_first)
      end

      assert_raise ArgumentError, ~r/expected traversal order to be/, fn ->
        Walk.walk(in: Yog.directed(), from: 1, using: :invalid_order)
      end

      assert_raise ArgumentError, ~r/expected opts to be a keyword list/, fn ->
        Walk.walk(:invalid)
      end
    end
  end

  describe "find_path/3 and reachable?/3" do
    test "finds path between reachable nodes" do
      g = Yog.from_edges(:directed, [{1, 2, 1}, {2, 3, 1}])
      assert Walk.find_path(g, 1, 3) == [1, 2, 3]
      assert Walk.reachable?(g, 1, 3) == true
      assert Walk.find_path(g, 3, 1) == nil
      assert Walk.reachable?(g, 3, 1) == false
    end

    test "returns nil for non-existent node IDs" do
      g = Yog.directed() |> Yog.add_node(1, nil)
      assert Walk.find_path(g, 1, 99) == nil
      assert Walk.reachable?(g, 1, 99) == false
    end
  end

  describe "random_walk/3" do
    test "walks random path up to requested steps" do
      g = Yog.from_edges(:directed, [{1, 2, 1}, {2, 1, 1}])
      res = Walk.random_walk(g, 1, 3)
      assert length(res) == 4
      assert hd(res) == 1
    end

    test "returns start node if steps <= 0 or start node has no edges" do
      g = Yog.directed()
      assert Walk.random_walk(g, 99, 3) == [99]
      assert Walk.random_walk(g, 1, 0) == [1]
      assert Walk.random_walk(g, 1, -5) == [1]
    end

    test "raises ArgumentError for non-integer steps" do
      g = Yog.directed() |> Yog.add_node(1, nil)

      assert_raise ArgumentError, ~r/expected steps to be an integer/, fn ->
        Walk.random_walk(g, 1, :invalid)
      end
    end
  end

  describe "property tests for Walk" do
    property "find_path returned path is always valid and connected" do
      check all(
              n <- StreamData.integer(2..10),
              raw_edges <-
                StreamData.list_of(
                  StreamData.tuple({StreamData.integer(1..n), StreamData.integer(1..n)})
                )
            ) do
        g =
          Enum.reduce(raw_edges, Yog.directed(), fn {u, v}, acc ->
            Yog.add_edge_ensure(acc, u, v, 1)
          end)

        from = 1
        to = n

        case Walk.find_path(g, from, to) do
          nil ->
            refute Walk.reachable?(g, from, to)

          path ->
            assert Walk.reachable?(g, from, to)
            assert hd(path) == from
            assert List.last(path) == to

            # Every adjacent pair in path must be an edge in g
            Enum.chunk_every(path, 2, 1, :discard)
            |> Enum.each(fn [u, v] ->
              assert Yog.has_edge?(g, u, v)
            end)
        end
      end
    end
  end
end
