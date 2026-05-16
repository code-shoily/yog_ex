defmodule Yog.Connectivity.ReachabilityTest do
  use ExUnit.Case, async: true
  doctest Yog.Connectivity.Reachability

  alias Yog.Connectivity.Reachability

  describe "counts/2" do
    test "handles acyclic graphs (descendants)" do
      graph = Yog.from_edges(:directed, [{1, 2, 1}, {2, 3, 1}, {1, 4, 1}])
      counts = Reachability.counts(graph, :descendants)
      # Reachable: 2, 3, 4
      assert counts[1] == 3
      # Reachable: 3
      assert counts[2] == 1
      assert counts[3] == 0
      assert counts[4] == 0
    end

    test "handles acyclic graphs (ancestors)" do
      graph = Yog.from_edges(:directed, [{1, 2, 1}, {2, 3, 1}, {1, 4, 1}])
      counts = Reachability.counts(graph, :ancestors)
      assert counts[1] == 0
      # Can reach 2: 1
      assert counts[2] == 1
      # Can reach 3: 1, 2
      assert counts[3] == 2
      # Can reach 4: 1
      assert counts[4] == 1
    end

    test "handles cyclic graphs via condensation" do
      # Cycle: 1 <-> 2, and 2 -> 3
      graph =
        Yog.directed()
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 1, with: 1)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: 1)

      counts = Reachability.counts(graph, :descendants)
      # From 1: can reach 2, 3. Also 1 is in same SCC as 2, so 2 descendants.
      # Wait, from 1, descendants are {2, 3}. 2 is in same SCC.
      # My implementation: node_count + (my_scc_size - 1)
      # SCC {1, 2} has size 2. SCC {3} has size 1.
      # Condensation: {1,2} -> {3}
      # From {1,2}, reachable SCCs is [{3}]. size=1.
      # Node 1 count: 1 + (2-1) = 2. Correct.
      assert counts[1] == 2
      assert counts[2] == 2
      assert counts[3] == 0
    end

    test "handles disconnected components" do
      graph =
        Yog.directed()
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 1)
        # Isolated
        |> Yog.add_node(3, nil)

      counts = Reachability.counts(graph, :descendants)
      assert counts[1] == 1
      assert counts[2] == 0
      assert counts[3] == 0
    end
  end

  describe "counts_estimate/2" do
    test "estimates descendants for acyclic graph" do
      graph = Yog.from_edges(:directed, [{1, 2, 1}, {2, 3, 1}])
      counts = Reachability.counts_estimate(graph, :descendants)
      # Estimation on tiny graphs should be exactly correct or very close
      assert counts[1] >= 1
      assert counts[3] == 0
    end

    test "estimates for cyclic graphs" do
      graph = Yog.from_edges(:directed, [{1, 2, 1}, {2, 1, 1}, {2, 3, 1}])
      counts = Reachability.counts_estimate(graph, :descendants)
      assert counts[1] >= 1
      assert counts[3] == 0
    end

    test "handles large-ish graph estimation" do
      # Linear graph 1 -> 2 -> ... -> 50
      nodes = Enum.to_list(1..50)
      edges = Enum.chunk_every(nodes, 2, 1, :discard) |> Enum.map(fn [a, b] -> {a, b, 1} end)
      graph = Yog.from_edges(:directed, edges)

      counts = Reachability.counts_estimate(graph, :descendants)
      # Node 1 should reach 49 others. Standard error ~3.25%.
      # 49 * 0.0325 ≈ 1.6. So should be close to 49.
      assert_in_delta counts[1], 49, 10
    end
  end
end
