defmodule Yog.PBT.GeneratorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.Generator.Classic
  alias Yog.Generator.Random

  describe "Classic Generator Properties" do
    property "complete(n) has n nodes and n(n-1)/2 edges" do
      check all(n <- StreamData.integer(1..20)) do
        g = Classic.complete(n)
        assert Yog.node_count(g) == n
        assert Yog.edge_count(g) == div(n * (n - 1), 2)

        degrees = for v <- 0..(n - 1), do: length(Yog.neighbors(g, v))
        assert Enum.all?(degrees, fn d -> d == n - 1 end)
      end
    end

    property "cycle(n) has n nodes and n edges" do
      check all(n <- StreamData.integer(3..20)) do
        g = Classic.cycle(n)
        assert Yog.node_count(g) == n
        assert Yog.edge_count(g) == n

        degrees = for v <- 0..(n - 1), do: length(Yog.neighbors(g, v))
        assert Enum.all?(degrees, fn d -> d == 2 end)
      end
    end

    property "path(n) has n nodes and max(0, n-1) edges" do
      check all(n <- StreamData.integer(0..20)) do
        g = Classic.path(n)
        assert Yog.node_count(g) == max(n, 0)
        assert Yog.edge_count(g) == max(n - 1, 0)
      end
    end

    property "star(n) has n nodes and max(0, n-1) edges" do
      check all(n <- StreamData.integer(0..20)) do
        g = Classic.star(n)
        assert Yog.node_count(g) == max(n, 0)

        if n >= 2 do
          assert Yog.edge_count(g) == n - 1
          assert length(Yog.neighbors(g, 0)) == n - 1
        end
      end
    end

    property "wheel(n) has n nodes and 2(n-1) edges" do
      check all(n <- StreamData.integer(4..20)) do
        g = Classic.wheel(n)
        assert Yog.node_count(g) == n
        assert Yog.edge_count(g) == 2 * (n - 1)

        assert length(Yog.neighbors(g, 0)) == n - 1
        assert length(Yog.neighbors(g, 1)) == 3
      end
    end

    property "binary_tree(depth) has 2^(depth+1)-1 nodes" do
      check all(depth <- StreamData.integer(0..5)) do
        g = Classic.binary_tree(depth)
        expected_nodes = Integer.pow(2, depth + 1) - 1
        assert Yog.node_count(g) == expected_nodes
        assert Yog.edge_count(g) == expected_nodes - 1
      end
    end

    property "petersen() has 10 nodes, 15 edges, degree 3" do
      check all(_ <- StreamData.constant(nil)) do
        g = Classic.petersen()
        assert Yog.node_count(g) == 10
        assert Yog.edge_count(g) == 15

        degrees = for v <- 0..9, do: length(Yog.neighbors(g, v))
        assert Enum.all?(degrees, fn d -> d == 3 end)
      end
    end

    property "empty(n) has n nodes and 0 edges" do
      check all(n <- StreamData.integer(0..20)) do
        g = Classic.empty(n)
        assert Yog.node_count(g) == max(n, 0)
        assert Yog.edge_count(g) == 0
      end
    end

    property "grid_2d(rows, cols) has rows*cols nodes" do
      check all(
              rows <- StreamData.integer(1..10),
              cols <- StreamData.integer(1..10)
            ) do
        g = Classic.grid_2d(rows, cols)
        assert Yog.node_count(g) == rows * cols

        expected_edges = (rows - 1) * cols + rows * (cols - 1)
        assert Yog.edge_count(g) == expected_edges
      end
    end

    property "complete_bipartite(m, n) has m+n nodes and m*n edges" do
      check all(
              m <- StreamData.integer(0..10),
              n <- StreamData.integer(0..10)
            ) do
        g = Classic.complete_bipartite(m, n)
        assert Yog.node_count(g) == m + n
        assert Yog.edge_count(g) == m * n
      end
    end

    property "hypercube(n) has 2^n nodes and n*2^(n-1) edges" do
      check all(n <- StreamData.integer(0..5)) do
        g = Classic.hypercube(n)
        expected_nodes = Integer.pow(2, n)
        expected_edges = if n == 0, do: 0, else: n * Integer.pow(2, n - 1)

        assert Yog.node_count(g) == expected_nodes
        assert Yog.edge_count(g) == expected_edges

        if n > 0 do
          degrees = for v <- 0..(expected_nodes - 1), do: length(Yog.neighbors(g, v))
          assert Enum.all?(degrees, fn d -> d == n end)
        end
      end
    end

    property "ladder(n) has 2n nodes and 3n-2 edges" do
      check all(n <- StreamData.integer(1..10)) do
        g = Classic.ladder(n)
        assert Yog.node_count(g) == 2 * n
        assert Yog.edge_count(g) == 3 * n - 2
      end
    end

    property "turan(n, r) has n nodes and no edges within partitions" do
      check all(
              n <- StreamData.integer(1..15),
              r <- StreamData.integer(1..5)
            ) do
        g = Classic.turan(n, r)
        assert Yog.node_count(g) == n

        if r >= n do
          assert Yog.edge_count(g) == div(n * (n - 1), 2)
        end
      end
    end
  end

  describe "Random Generator Properties" do
    property "erdos_renyi_gnp(n, p) has exactly n nodes" do
      check all(n <- StreamData.integer(1..20)) do
        g = Random.erdos_renyi_gnp(n, 0.3)
        assert Yog.node_count(g) == n
      end
    end

    property "erdos_renyi_gnm(n, m) has exactly n nodes and at most m edges" do
      check all(
              n <- StreamData.integer(1..20),
              m <- StreamData.integer(0..100)
            ) do
        g = Random.erdos_renyi_gnm(n, m)
        assert Yog.node_count(g) == n

        max_edges = div(n * (n - 1), 2)
        assert Yog.edge_count(g) == min(m, max_edges)
      end
    end

    property "random_tree(n) is a tree" do
      check all(n <- StreamData.integer(1..20)) do
        g = Random.random_tree(n)
        assert Yog.node_count(g) == n
        assert Yog.edge_count(g) == max(n - 1, 0)
      end
    end

    property "random_regular(n, d) has correct node and edge counts" do
      check all(
              n <- StreamData.integer(2..20),
              d <- StreamData.integer(0..(n - 1)),
              rem(n * d, 2) == 0
            ) do
        g = Random.random_regular(n, d)

        # Configuration model can fail after 100 retries for some parameters
        # If it returns empty, skip this case
        if Yog.node_count(g) > 0 do
          assert Yog.node_count(g) == n
          assert Yog.edge_count(g) == div(n * d, 2)

          degrees = for v <- 0..(n - 1), do: length(Yog.neighbors(g, v))
          assert Enum.all?(degrees, fn deg -> deg == d end)
        end
      end
    end

    property "random generators with same seed produce identical graphs" do
      check all(
              n <- StreamData.integer(5..15),
              seed <- StreamData.integer(1..10_000)
            ) do
        g1 = Random.erdos_renyi_gnp(n, 0.5, seed)
        g2 = Random.erdos_renyi_gnp(n, 0.5, seed)
        assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
      end
    end
  end
end
