defmodule Yog.Generator.RandomTest do
  use ExUnit.Case

  alias Yog.Generator.Random

  doctest Yog.Generator.Random

  # ============= Erdős-Rényi G(n, p) Tests =============

  test "erdos_renyi_gnp/2 creates graph with n nodes" do
    g = Random.erdos_renyi_gnp(10, 0.3)
    assert Yog.Model.order(g) == 10
  end

  test "erdos_renyi_gnp/2 with p=0 has no edges" do
    g = Random.erdos_renyi_gnp(10, 0.0)
    assert Yog.Model.edge_count(g) == 0
  end

  test "erdos_renyi_gnp/2 with p=1 is complete graph" do
    g = Random.erdos_renyi_gnp(5, 1.0)
    assert Yog.Model.edge_count(g) == 10
  end

  test "erdos_renyi_gnp/2 directed variant" do
    g = Random.erdos_renyi_gnp_with_type(5, 0.5, :directed)
    assert Yog.Model.type(g) == :directed
    assert Yog.Model.order(g) == 5
  end

  # ============= Erdős-Rényi G(n, m) Tests =============

  test "erdos_renyi_gnm/2 creates graph with exactly m edges" do
    g = Random.erdos_renyi_gnm(10, 15)
    assert Yog.Model.order(g) == 10
    assert Yog.Model.edge_count(g) == 15
  end

  test "erdos_renyi_gnm/2 clamps m to max possible" do
    g = Random.erdos_renyi_gnm(5, 100)
    # Max edges in K5 = 10
    assert Yog.Model.edge_count(g) == 10
  end

  test "erdos_renyi_gnm/2 with m=0 has no edges" do
    g = Random.erdos_renyi_gnm(10, 0)
    assert Yog.Model.edge_count(g) == 0
  end

  # ============= Barabási-Albert Tests =============

  test "barabasi_albert/2 creates graph with n nodes" do
    g = Random.barabasi_albert(20, 2)
    assert Yog.Model.order(g) == 20
  end

  test "barabasi_albert/2 m >= n returns isolated nodes" do
    g = Random.barabasi_albert(5, 10)
    assert Yog.Model.order(g) == 5
    assert Yog.Model.edge_count(g) == 0
  end

  test "barabasi_albert/2 directed variant" do
    g = Random.barabasi_albert_with_type(10, 2, :directed)
    assert Yog.Model.type(g) == :directed
    assert Yog.Model.order(g) == 10
  end

  # ============= Watts-Strogatz Tests =============

  test "watts_strogatz/3 creates graph with n nodes" do
    g = Random.watts_strogatz(20, 4, 0.1)
    assert Yog.Model.order(g) == 20
  end

  test "watts_strogatz/3 p=0 is regular lattice" do
    g = Random.watts_strogatz(10, 4, 0.0)
    assert Yog.Model.order(g) == 10
    # Each node should have degree 4
    degrees = for v <- 0..9, do: length(Yog.neighbors(g, v))
    assert Enum.all?(degrees, fn d -> d == 4 end)
  end

  test "watts_strogatz/3 directed variant" do
    g = Random.watts_strogatz_with_type(10, 4, 0.1, :directed)
    assert Yog.Model.type(g) == :directed
    assert Yog.Model.order(g) == 10
  end

  # ============= Random Tree Tests =============

  test "random_tree/1 creates tree with n-1 edges" do
    g = Random.random_tree(10)
    assert Yog.Model.order(g) == 10
    assert Yog.Model.edge_count(g) == 9
  end

  test "random_tree/1 single node" do
    g = Random.random_tree(1)
    assert Yog.Model.order(g) == 1
    assert Yog.Model.edge_count(g) == 0
  end

  test "random_tree/1 directed variant" do
    g = Random.random_tree_with_type(10, :directed)
    assert Yog.Model.type(g) == :directed
    assert Yog.Model.order(g) == 10
  end

  # ============= Random Regular Graph Tests =============

  test "random_regular/2 generates d-regular graph" do
    reg = Random.random_regular(10, 3)
    assert Yog.Model.order(reg) == 10
    # n*d/2 = 10*3/2
    assert Yog.Model.edge_count(reg) == 15

    # All nodes have degree exactly d
    degrees = for v <- 0..9, do: length(Yog.neighbors(reg, v))
    assert Enum.all?(degrees, fn d -> d == 3 end)
  end

  test "random_regular/2 generates 0-regular graph (isolated nodes)" do
    reg = Random.random_regular(5, 0)
    assert Yog.Model.order(reg) == 5
    assert Yog.Model.edge_count(reg) == 0

    degrees = for v <- 0..4, do: length(Yog.neighbors(reg, v))
    assert Enum.all?(degrees, fn d -> d == 0 end)
  end

  test "random_regular/2 generates 1-regular graph (matching)" do
    reg = Random.random_regular(10, 1)
    assert Yog.Model.order(reg) == 10
    # n*d/2 = 10*1/2
    assert Yog.Model.edge_count(reg) == 5

    degrees = for v <- 0..9, do: length(Yog.neighbors(reg, v))
    assert Enum.all?(degrees, fn d -> d == 1 end)
  end

  test "random_regular/2 generates 2-regular graph (disjoint cycles)" do
    reg = Random.random_regular(10, 2)
    assert Yog.Model.order(reg) == 10
    # n*d/2 = 10*2/2
    assert Yog.Model.edge_count(reg) == 10

    degrees = for v <- 0..9, do: length(Yog.neighbors(reg, v))
    assert Enum.all?(degrees, fn d -> d == 2 end)
  end

  test "random_regular/2 invalid n*d odd returns empty" do
    # n*d must be even for any d-regular graph to exist
    reg = Random.random_regular(5, 3)
    # 5*3 = 15 is odd, so should return empty graph
    assert Yog.Model.order(reg) == 0
  end

  test "random_regular/2 d >= n returns empty" do
    reg = Random.random_regular(5, 5)
    assert Yog.Model.order(reg) == 0
  end

  test "random_regular/2 negative n returns empty" do
    reg = Random.random_regular(-1, 2)
    assert Yog.Model.order(reg) == 0
  end

  test "random_regular/2 negative d returns empty" do
    reg = Random.random_regular(10, -1)
    assert Yog.Model.order(reg) == 0
  end

  test "random_regular_with_type/3 directed regular graph" do
    reg = Random.random_regular_with_type(10, 3, :directed)
    assert Yog.Model.type(reg) == :directed
    assert Yog.Model.order(reg) == 10
  end

  test "random_regular/2 single node" do
    reg = Random.random_regular(1, 0)
    assert Yog.Model.order(reg) == 1
    assert Yog.Model.edge_count(reg) == 0
  end

  test "random_regular/2 no self-loops" do
    reg = Random.random_regular(10, 3)

    for v <- 0..9 do
      refute v in Yog.neighbors(reg, v)
    end
  end

  test "random_regular/2 no parallel edges" do
    reg = Random.random_regular(10, 3)

    for v <- 0..9 do
      neigh = Yog.neighbors(reg, v)
      # Check no duplicates
      assert length(neigh) == length(Enum.uniq(neigh))
    end
  end

  # ============= Reproducibility (Seed) Tests =============

  test "erdos_renyi_gnp/3 with same seed is reproducible" do
    g1 = Random.erdos_renyi_gnp(20, 0.3, 42)
    g2 = Random.erdos_renyi_gnp(20, 0.3, 42)
    assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
  end

  test "erdos_renyi_gnm/3 with same seed is reproducible" do
    g1 = Random.erdos_renyi_gnm(20, 50, 42)
    g2 = Random.erdos_renyi_gnm(20, 50, 42)
    assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
  end

  test "barabasi_albert/3 with same seed is reproducible" do
    g1 = Random.barabasi_albert(20, 2, 42)
    g2 = Random.barabasi_albert(20, 2, 42)
    assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
  end

  test "watts_strogatz/4 with same seed is reproducible" do
    g1 = Random.watts_strogatz(20, 4, 0.1, 42)
    g2 = Random.watts_strogatz(20, 4, 0.1, 42)
    assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
  end

  test "random_tree/2 with same seed is reproducible" do
    g1 = Random.random_tree(20, 42)
    g2 = Random.random_tree(20, 42)
    assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
  end

  test "random_regular/3 with same seed is reproducible" do
    g1 = Random.random_regular(10, 3, 42)
    g2 = Random.random_regular(10, 3, 42)
    assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
  end

  test "seed does not pollute global RNG state" do
    # Fix the global RNG to a known seed
    :rand.seed(:exsss, 12345)

    # Generate a sequence without any seeded generator interruption
    seq_without = [:rand.uniform(), :rand.uniform(), :rand.uniform()]

    # Reset to the same seed and generate the same sequence,
    # but insert a seeded generator call in the middle
    :rand.seed(:exsss, 12345)

    seq_with = [
      :rand.uniform(),
      # This should temporarily use seed 99999, then restore global state
      (fn ->
         _ = Random.erdos_renyi_gnp(10, 0.5, 99999)
         :rand.uniform()
       end).(),
      :rand.uniform()
    ]

    # The sequences should be identical - proving the global RNG state
    # was properly saved and restored around the seeded generator
    assert seq_without == seq_with
  end

  # ============= SBM Tests =============

  test "sbm/5 creates graph with n nodes" do
    g = Random.sbm(50, 4, 0.3, 0.05)
    assert Yog.Model.order(g) == 50
  end

  test "sbm/5 with p_in=1.0, p_out=0.0 creates disconnected cliques" do
    g = Random.sbm(12, 3, 1.0, 0.0)
    assert Yog.Model.order(g) == 12
    # 3 communities of 4 nodes each -> 3 * 6 = 18 edges
    assert Yog.Model.edge_count(g) == 18
  end

  test "sbm/5 with custom community sizes" do
    g = Random.sbm(10, 2, 1.0, 0.0, community_sizes: [3, 7])
    assert Yog.Model.order(g) == 10
    # Community 0: 3 nodes -> 3 edges, Community 1: 7 nodes -> 21 edges
    assert Yog.Model.edge_count(g) == 24
  end

  test "sbm_with_labels/5 returns correct community assignments" do
    {g, communities} = Random.sbm_with_labels(10, 2, 0.5, 0.1)
    assert Yog.Model.order(g) == 10
    assert map_size(communities) == 10
    assert communities[0] == 0
    assert communities[9] == 1
  end

  test "sbm_with_type/6 directed variant" do
    g = Random.sbm_with_type(10, 2, 0.5, 0.1, :directed)
    assert Yog.Model.type(g) == :directed
    assert Yog.Model.order(g) == 10
  end

  test "sbm/5 with same seed is reproducible" do
    {g1, comm1} = Random.sbm_with_labels(20, 2, 0.4, 0.05, seed: 42)
    {g2, comm2} = Random.sbm_with_labels(20, 2, 0.4, 0.05, seed: 42)
    assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
    assert comm1 == comm2
  end

  test "sbm/5 invalid args returns empty graph" do
    g = Random.sbm(0, 2, 0.3, 0.05)
    assert Yog.Model.order(g) == 0

    g = Random.sbm(10, 0, 0.3, 0.05)
    assert Yog.Model.order(g) == 0
  end

  # ============= DCSBM Tests =============

  test "dcsbm/5 creates graph with n nodes" do
    g = Random.dcsbm(50, 4, 0.3, 0.05)
    assert Yog.Model.order(g) == 50
  end

  test "dcsbm/5 with power_law degree distribution" do
    g = Random.dcsbm(30, 3, 0.5, 0.05, degree_dist: :power_law, gamma: 2.5)
    assert Yog.Model.order(g) == 30
  end

  test "dcsbm/5 with custom degree list" do
    g = Random.dcsbm(20, 2, 0.5, 0.05, degree_dist: List.duplicate(1.0, 20))
    assert Yog.Model.order(g) == 20
  end

  test "dcsbm/5 invalid args returns empty graph" do
    g = Random.dcsbm(-1, 2, 0.3, 0.05)
    assert Yog.Model.order(g) == 0
  end

  # ============= HSBM Tests =============

  test "hsbm/2 creates graph with n nodes" do
    g = Random.hsbm(80, levels: 2, branching: 2, p_in: 0.4, p_mid: 0.1, p_out: 0.01)
    assert Yog.Model.order(g) == 80
  end

  test "hsbm/2 with custom probs" do
    g = Random.hsbm(16, levels: 2, branching: 2, probs: [1.0, 0.0, 0.0])
    assert Yog.Model.order(g) == 16
    # Only edges within leaf blocks of size 4 -> 4 blocks * 6 edges = 24
    assert Yog.Model.edge_count(g) == 24
  end

  test "hsbm/2 with p_in=1.0 and p_out=0.0 creates cliques at leaf level" do
    g = Random.hsbm(8, levels: 1, branching: 2, p_in: 1.0, p_out: 0.0)
    assert Yog.Model.order(g) == 8
    # 2 leaf blocks of 4 -> 2 * 6 = 12 edges
    assert Yog.Model.edge_count(g) == 12
  end

  test "hsbm/2 invalid args returns empty graph" do
    g = Random.hsbm(0, levels: 2, branching: 2)
    assert Yog.Model.order(g) == 0

    g = Random.hsbm(8, levels: 2, branching: 5)
    # 5^2 = 25 leaf blocks, but only 8 nodes -> base_leaf_size = 0
    assert Yog.Model.order(g) == 0
  end

  # ============= Configuration Model Tests =============

  test "configuration_model/2 creates graph with correct degree sequence" do
    degrees = [3, 3, 2, 2, 2]
    {:ok, g} = Random.configuration_model(degrees)
    assert Yog.Model.order(g) == 5

    # Check each node has the expected degree
    for {expected_deg, node} <- Enum.with_index(degrees) do
      actual_deg = Yog.Model.degree(g, node)

      assert actual_deg == expected_deg,
             "Node #{node} should have degree #{expected_deg}, got #{actual_deg}"
    end
  end

  test "configuration_model/2 returns error for odd degree sum" do
    # Use a sequence with odd sum: 3+2+2 = 7
    result = Random.configuration_model([3, 2, 2])
    assert result == {:error, :odd_degree_sum}
  end

  test "configuration_model/2 returns error for negative degrees" do
    result = Random.configuration_model([3, -1, 2])
    assert result == {:error, :negative_degrees}
  end

  test "configuration_model/2 returns error for empty sequence" do
    result = Random.configuration_model([])
    assert result == {:error, :empty_degree_sequence}
  end

  test "configuration_model/2 allows self-loops when configured" do
    # Star graph: one center with degree 4, 4 leaves with degree 1
    # Without allowing self-loops, this is easy
    degrees = [4, 1, 1, 1, 1]
    {:ok, g} = Random.configuration_model(degrees, allow_selfloops: true)
    assert Yog.Model.order(g) == 5
  end

  test "configuration_model/2 is reproducible with seed" do
    degrees = [3, 3, 2, 2, 2]
    {:ok, g1} = Random.configuration_model(degrees, seed: 42)
    {:ok, g2} = Random.configuration_model(degrees, seed: 42)
    assert Yog.all_edges(g1) |> MapSet.new() == Yog.all_edges(g2) |> MapSet.new()
  end

  test "randomize_degree_sequence/2 preserves degrees" do
    original = Yog.Generator.Classic.star(5)
    {:ok, randomized} = Random.randomize_degree_sequence(original, seed: 42)

    assert Yog.Model.order(randomized) == 5

    # Check degrees are preserved
    for node <- 0..4 do
      orig_deg = Yog.Model.degree(original, node)
      rand_deg = Yog.Model.degree(randomized, node)
      assert orig_deg == rand_deg
    end
  end

  test "randomize_degree_sequence/2 works with non-integer node IDs" do
    # Create a graph with atom node IDs
    original =
      Yog.undirected()
      |> Yog.add_node(:a, nil)
      |> Yog.add_node(:b, nil)
      |> Yog.add_node(:c, nil)
      |> Yog.add_node(:d, nil)
      |> Yog.add_edge!(:a, :b, 1)
      |> Yog.add_edge!(:b, :c, 1)
      |> Yog.add_edge!(:c, :d, 1)

    {:ok, randomized} = Random.randomize_degree_sequence(original, seed: 42)

    assert Yog.Model.order(randomized) == 4

    # Check that node IDs are preserved
    assert Yog.Model.has_node?(randomized, :a)
    assert Yog.Model.has_node?(randomized, :b)
    assert Yog.Model.has_node?(randomized, :c)
    assert Yog.Model.has_node?(randomized, :d)

    # Check degrees are preserved
    assert Yog.Model.degree(randomized, :a) == Yog.Model.degree(original, :a)
    assert Yog.Model.degree(randomized, :b) == Yog.Model.degree(original, :b)
    assert Yog.Model.degree(randomized, :c) == Yog.Model.degree(original, :c)
    assert Yog.Model.degree(randomized, :d) == Yog.Model.degree(original, :d)
  end

  test "power_law_graph/2 creates graph with n nodes" do
    result = Random.power_law_graph(50, gamma: 2.5, seed: 42)
    assert {:ok, g} = result
    assert Yog.Model.order(g) == 50
  end

  test "power_law_graph/2 returns error for invalid gamma" do
    result = Random.power_law_graph(50, gamma: 2.0)
    assert result == {:error, :gamma_must_be_greater_than_2}

    result = Random.power_law_graph(50, gamma: 1.5)
    assert result == {:error, :gamma_must_be_greater_than_2}
  end

  test "power_law_graph/2 respects degree bounds" do
    {:ok, g} = Random.power_law_graph(30, gamma: 2.5, k_min: 2, k_max: 5, seed: 42)

    for node <- 0..29 do
      deg = Yog.Model.degree(g, node)
      assert deg >= 2 and deg <= 5
    end
  end
end
