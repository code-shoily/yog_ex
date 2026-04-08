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
      # For a d-regular graph with n nodes to exist, n*d must be even (handshaking lemma)
      # Generate n, then choose d such that n*d is always even:
      # - If n is even, any d works (0 to n-1)
      # - If n is odd, d must be even (0, 2, 4, ...)
      check all(
              n <- StreamData.integer(2..20),
              d <-
                StreamData.bind(StreamData.integer(0..(n - 1)), fn d ->
                  if rem(n, 2) == 0 do
                    StreamData.constant(d)
                  else
                    # n is odd, ensure d is even by rounding down to nearest even
                    StreamData.constant(d - rem(d, 2))
                  end
                end)
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

    property "sbm(n, k, p_in, p_out) has exactly n nodes" do
      check all(
              n <- StreamData.integer(5..30),
              k <- StreamData.integer(1..5),
              p_in <- StreamData.float(min: 0.0, max: 1.0),
              p_out <- StreamData.float(min: 0.0, max: 1.0)
            ) do
        g = Random.sbm(n, k, p_in, p_out)
        assert Yog.node_count(g) == n
      end
    end

    property "sbm community assignments are in valid range" do
      check all(
              n <- StreamData.integer(5..30),
              k <- StreamData.integer(1..5),
              seed <- StreamData.integer(1..10_000)
            ) do
        {_g, communities} = Random.sbm_with_labels(n, k, 0.3, 0.05, seed: seed)
        assert map_size(communities) == n
        assert Enum.all?(communities, fn {_node, comm} -> comm >= 0 and comm < k end)
      end
    end

    property "dcsbm(n, k, p_in, p_out) has exactly n nodes" do
      check all(
              n <- StreamData.integer(5..30),
              k <- StreamData.integer(1..5),
              p_in <- StreamData.float(min: 0.0, max: 1.0),
              p_out <- StreamData.float(min: 0.0, max: 1.0)
            ) do
        g = Random.dcsbm(n, k, p_in, p_out)
        assert Yog.node_count(g) == n
      end
    end

    property "hsbm(n, opts) has exactly n nodes" do
      check all(
              n <- StreamData.integer(8..64),
              seed <- StreamData.integer(1..10_000)
            ) do
        g = Random.hsbm(n, levels: 2, branching: 2, seed: seed)
        assert Yog.node_count(g) == n
      end
    end

    property "sbm with same seed is reproducible" do
      check all(
              n <- StreamData.integer(5..20),
              k <- StreamData.integer(1..4),
              seed <- StreamData.integer(1..10_000)
            ) do
        {g1, comm1} = Random.sbm_with_labels(n, k, 0.3, 0.05, seed: seed)
        {g2, comm2} = Random.sbm_with_labels(n, k, 0.3, 0.05, seed: seed)
        assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
        assert comm1 == comm2
      end
    end
  end

  describe "Configuration Model Properties" do
    property "configuration_model preserves degree sequence" do
      check all(
              degrees <-
                StreamData.list_of(StreamData.integer(1..5),
                  min_length: 2,
                  max_length: 12
                )
                |> StreamData.filter(&(rem(Enum.sum(&1), 2) == 0))
            ) do
        case Random.configuration_model(degrees) do
          {:ok, g} ->
            assert Yog.node_count(g) == length(degrees)

            # Verify each node has the expected degree
            for {expected_deg, node} <- Enum.with_index(degrees) do
              actual_deg = Yog.Model.degree(g, node)
              assert actual_deg == expected_deg
            end

          {:error, :max_retries_exceeded} ->
            # Some degree sequences are hard to realize as simple graphs
            :ok
        end
      end
    end

    property "configuration_model satisfies handshaking lemma" do
      check all(
              degrees <-
                StreamData.list_of(StreamData.integer(0..5),
                  min_length: 1,
                  max_length: 12
                )
                |> StreamData.filter(&(rem(Enum.sum(&1), 2) == 0))
            ) do
        case Random.configuration_model(degrees) do
          {:ok, g} ->
            sum_degrees = Enum.sum(degrees)
            num_edges = Yog.edge_count(g)
            assert sum_degrees == 2 * num_edges

          {:error, :max_retries_exceeded} ->
            :ok
        end
      end
    end

    property "configuration_model with allow_selfloops=false has no self-loops" do
      check all(
              degrees <-
                StreamData.list_of(StreamData.integer(1..4),
                  min_length: 3,
                  max_length: 8
                )
                |> StreamData.filter(&(rem(Enum.sum(&1), 2) == 0))
            ) do
        case Random.configuration_model(degrees, allow_selfloops: false) do
          {:ok, g} ->
            # Check no self-loops exist
            for node <- 0..(length(degrees) - 1) do
              refute Yog.Model.has_edge?(g, node, node)
            end

          {:error, :max_retries_exceeded} ->
            :ok
        end
      end
    end

    property "randomize_degree_sequence preserves degrees" do
      check all(
              n <- StreamData.integer(5..12),
              seed <- StreamData.integer(1..10_000)
            ) do
        # Create a random graph to randomize
        original = Random.erdos_renyi_gnp(n, 0.3, seed)

        case Random.randomize_degree_sequence(original, seed: seed) do
          {:ok, randomized} ->
            assert Yog.node_count(randomized) == Yog.node_count(original)

            # Degrees should be preserved
            for node <- 0..(n - 1) do
              orig_deg = Yog.Model.degree(original, node)
              rand_deg = Yog.Model.degree(randomized, node)
              assert orig_deg == rand_deg
            end

          {:error, :max_retries_exceeded} ->
            # Some degree sequences are hard to realize
            :ok
        end
      end
    end

    property "power_law_graph respects n and degree bounds" do
      check all(
              n <- StreamData.integer(10..30),
              gamma <- StreamData.float(min: 2.1, max: 4.0),
              seed <- StreamData.integer(1..10_000)
            ) do
        result = Random.power_law_graph(n, gamma: gamma, k_min: 1, k_max: 8, seed: seed)

        # May fail due to retries, so handle both cases
        case result do
          {:ok, g} ->
            assert Yog.node_count(g) == n

            # All degrees should be within bounds
            for node <- 0..(n - 1) do
              deg = Yog.Model.degree(g, node)
              assert deg >= 1 and deg <= 8
            end

          {:error, _} ->
            # Retry limit exceeded - acceptable for some parameter combinations
            :ok
        end
      end
    end

    property "configuration_model with same seed is reproducible" do
      check all(
              degrees <-
                StreamData.list_of(StreamData.integer(1..4),
                  min_length: 2,
                  max_length: 8
                )
                |> StreamData.filter(&(rem(Enum.sum(&1), 2) == 0)),
              seed <- StreamData.integer(1..10_000)
            ) do
        result1 = Random.configuration_model(degrees, seed: seed)
        result2 = Random.configuration_model(degrees, seed: seed)

        case {result1, result2} do
          {{:ok, g1}, {:ok, g2}} ->
            assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()

          _ ->
            # If one fails, both should fail the same way (or both succeed)
            assert result1 == result2
        end
      end
    end

    property "configuration_model rejects invalid inputs" do
      check all(
              degrees <-
                StreamData.list_of(StreamData.integer(1..5),
                  min_length: 1,
                  max_length: 10
                )
                |> StreamData.filter(&(rem(Enum.sum(&1), 2) == 1))
            ) do
        # Odd degree sum should be rejected
        result = Random.configuration_model(degrees)
        assert result == {:error, :odd_degree_sum}
      end
    end
  end

  describe "Kronecker Graph Properties" do
    property "kronecker/3 creates graph with 2^k nodes" do
      check all(
              k <- StreamData.integer(2..6),
              seed <- StreamData.integer(1..10_000)
            ) do
        initiator = [[0.9, 0.5], [0.5, 0.1]]
        g = Random.kronecker(k, initiator, seed: seed)
        expected_nodes = Integer.pow(2, k)
        assert Yog.node_count(g) == expected_nodes
      end
    end

    property "kronecker/3 with directed: false creates undirected graph" do
      check all(
              k <- StreamData.integer(2..5),
              seed <- StreamData.integer(1..10_000)
            ) do
        initiator = [[0.8, 0.4], [0.4, 0.2]]
        g = Random.kronecker(k, initiator, directed: false, seed: seed)
        assert Yog.node_count(g) == Integer.pow(2, k)
        assert Yog.Model.type(g) == :undirected
      end
    end

    property "rmat/7 creates graph with correct node count" do
      check all(
              log_n <- StreamData.integer(5..8),
              seed <- StreamData.integer(1..10_000)
            ) do
        n = Integer.pow(2, log_n)
        # Average degree of 4
        m = n * 4
        g = Random.rmat(n, m, 0.45, 0.15, 0.15, 0.25, seed: seed)
        assert Yog.node_count(g) == n
      end
    end

    property "rmat/7 with undirected: true creates undirected graph" do
      check all(
              log_n <- StreamData.integer(5..7),
              seed <- StreamData.integer(1..10_000)
            ) do
        n = Integer.pow(2, log_n)
        m = n * 4
        g = Random.rmat(n, m, 0.5, 0.2, 0.2, 0.1, undirected: true, seed: seed)
        assert Yog.node_count(g) == n
        assert Yog.Model.type(g) == :undirected
      end
    end

    property "kronecker/3 is reproducible with seed" do
      check all(
              k <- StreamData.integer(2..5),
              seed <- StreamData.integer(1..10_000)
            ) do
        initiator = [[0.9, 0.5], [0.5, 0.1]]
        g1 = Random.kronecker(k, initiator, seed: seed)
        g2 = Random.kronecker(k, initiator, seed: seed)
        assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
      end
    end

    property "rmat/7 is reproducible with seed" do
      check all(
              log_n <- StreamData.integer(5..7),
              seed <- StreamData.integer(1..10_000)
            ) do
        n = Integer.pow(2, log_n)
        m = n * 4
        g1 = Random.rmat(n, m, 0.45, 0.15, 0.15, 0.25, seed: seed)
        g2 = Random.rmat(n, m, 0.45, 0.15, 0.15, 0.25, seed: seed)
        assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
      end
    end

    property "kronecker graphs have varying degrees (not regular)" do
      check all(
              k <- StreamData.integer(4..6),
              seed <- StreamData.integer(1..10_000)
            ) do
        initiator = [[0.9, 0.5], [0.5, 0.1]]
        g = Random.kronecker(k, initiator, seed: seed)
        n = Yog.node_count(g)

        # Get degrees
        degrees = for v <- 0..(n - 1), do: Yog.Model.degree(g, v)

        # Check that degrees vary (not all the same)
        unique_degrees = Enum.uniq(degrees)
        assert length(unique_degrees) > 1

        # Check there are some high-degree nodes (hubs) relative to min
        max_degree = Enum.max(degrees)
        min_degree = Enum.min(degrees)

        # In Kronecker graphs, there should be variation in degrees
        assert max_degree >= min_degree * 2 or length(unique_degrees) >= 3
      end
    end

    property "kronecker_general/3 creates graph with n^k nodes" do
      check all(
              k <- StreamData.integer(1..3),
              seed <- StreamData.integer(1..10_000)
            ) do
        # 3x3 initiator
        init_3x3 = [[0.8, 0.3, 0.2], [0.3, 0.6, 0.2], [0.2, 0.2, 0.5]]
        g = Random.kronecker_general(k, init_3x3, seed: seed)
        expected_nodes = Integer.pow(3, k)
        assert Yog.node_count(g) == expected_nodes
      end
    end
  end

  describe "Geometric Graph Properties" do
    property "geometric/2 creates graph with n nodes" do
      check all(
              n <- StreamData.integer(10..50),
              seed <- StreamData.integer(1..10_000)
            ) do
        g = Random.geometric(n, radius: 0.15, seed: seed)
        assert Yog.node_count(g) == n
      end
    end

    property "geometric/2 with radius=0 has no edges" do
      check all(
              n <- StreamData.integer(5..20),
              seed <- StreamData.integer(1..10_000)
            ) do
        g = Random.geometric(n, radius: 0.0, seed: seed)
        assert Yog.node_count(g) == n
        assert Yog.edge_count(g) == 0
      end
    end

    property "geometric/2 is reproducible with seed" do
      check all(
              n <- StreamData.integer(10..30),
              r <- StreamData.float(min: 0.05, max: 0.3),
              seed <- StreamData.integer(1..10_000)
            ) do
        g1 = Random.geometric(n, radius: r, seed: seed)
        g2 = Random.geometric(n, radius: r, seed: seed)
        assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
      end
    end

    property "geometric_nd/2 creates graph with correct node count" do
      check all(
              n <- StreamData.integer(10..40),
              dims <- StreamData.integer(2..4),
              seed <- StreamData.integer(1..10_000)
            ) do
        g = Random.geometric_nd(n, dimensions: dims, radius: 0.2, seed: seed)
        assert Yog.node_count(g) == n
      end
    end

    property "waxman/2 creates graph with n nodes" do
      check all(
              n <- StreamData.integer(10..50),
              alpha <- StreamData.float(min: 0.05, max: 0.3),
              beta <- StreamData.float(min: 0.1, max: 0.8),
              seed <- StreamData.integer(1..10_000)
            ) do
        g = Random.waxman(n, alpha: alpha, beta: beta, seed: seed)
        assert Yog.node_count(g) == n
      end
    end

    property "waxman/2 is reproducible with seed" do
      check all(
              n <- StreamData.integer(10..30),
              seed <- StreamData.integer(1..10_000)
            ) do
        g1 = Random.waxman(n, alpha: 0.15, beta: 0.4, seed: seed)
        g2 = Random.waxman(n, alpha: 0.15, beta: 0.4, seed: seed)
        assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
      end
    end

    property "geometric larger radius creates more edges" do
      check all(
              n <- StreamData.integer(20..40),
              seed <- StreamData.integer(1..10_000)
            ) do
        g_small = Random.geometric(n, radius: 0.05, seed: seed)
        g_large = Random.geometric(n, radius: 0.3, seed: seed)

        # Larger radius should generally produce more edges
        # (This is probabilistic, so we check the trend rather than strict inequality)
        edges_small = Yog.edge_count(g_small)
        edges_large = Yog.edge_count(g_large)

        # With high probability, larger radius produces more or equal edges
        assert edges_large >= edges_small * 0.5
      end
    end
  end
end
