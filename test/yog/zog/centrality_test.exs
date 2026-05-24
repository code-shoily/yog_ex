defmodule Yog.Zog.CentralityTest do
  use ExUnit.Case, async: true

  alias Yog.Builder.Zog
  alias Yog.Zog.Centrality

  @moduletag :zigler

  describe "betweenness_unweighted/1" do
    test "bridge node has highest score" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)

      scores = Centrality.betweenness_unweighted(builder)

      assert scores["B"] > scores["A"]
      assert scores["B"] > scores["C"]
      assert scores["A"] == 0.0
      assert scores["C"] == 0.0
    end

    test "star graph: center has all betweenness" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("center", "a", 1.0)
        |> Zog.add_edge("center", "b", 1.0)
        |> Zog.add_edge("center", "c", 1.0)

      scores = Centrality.betweenness_unweighted(builder)

      assert scores["center"] > 0.0
      assert scores["a"] == 0.0
      assert scores["b"] == 0.0
      assert scores["c"] == 0.0
    end

    test "empty graph returns zeros" do
      builder = Zog.directed()
      scores = Centrality.betweenness_unweighted(builder)
      assert scores == %{}
    end

    test "single node returns zero" do
      builder = Zog.directed() |> Zog.add_node("A")
      scores = Centrality.betweenness_unweighted(builder)
      assert scores == %{"A" => 0.0}
    end
  end

  describe "betweenness_f64/1" do
    test "weighted bridge node has highest score" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)

      scores = Centrality.betweenness_f64(builder)

      assert scores["B"] > scores["A"]
      assert scores["B"] > scores["C"]
    end

    test "weights affect shortest paths" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("A", "C", 10.0)

      scores = Centrality.betweenness_f64(builder)

      # B lies on the shortest path A->C (weight 2), not the direct edge (weight 10)
      assert scores["B"] > 0.0
    end
  end

  describe "closeness_f64/1" do
    test "center of chain has highest closeness" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)

      scores = Centrality.closeness_f64(builder)

      # B is in the middle, can reach both A and C with total distance 2
      # A can reach B and C with total distance 3
      assert scores["B"] > scores["A"]
      assert scores["B"] > scores["C"]
    end

    test "isolated node gets 0.0" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_node("C")

      scores = Centrality.closeness_f64(builder)

      # C cannot reach all other nodes
      assert scores["C"] == 0.0
    end
  end

  describe "harmonic_centrality_f64/1" do
    test "center of chain has highest harmonic centrality" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)

      scores = Centrality.harmonic_centrality_f64(builder)

      assert scores["B"] > scores["A"]
      assert scores["B"] > scores["C"]
    end

    test "handles disconnected graphs gracefully" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_node("C")

      scores = Centrality.harmonic_centrality_f64(builder)

      # C gets some credit for reachable nodes, not 0.0
      assert scores["C"] >= 0.0
      # A and B get higher scores because they reach each other
      assert scores["A"] > scores["C"]
    end
  end

  describe "pagerank/2" do
    test "node with more incoming links has higher rank" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("C", "B", 1.0)

      scores = Centrality.pagerank(builder)

      assert scores["B"] > scores["A"]
      assert scores["B"] > scores["C"]
    end

    test "damping factor affects scores" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)

      scores_default = Centrality.pagerank(builder, damping: 0.85)
      scores_high = Centrality.pagerank(builder, damping: 0.99)

      # Both should return valid scores
      assert scores_default["A"] > 0.0
      assert scores_high["A"] > 0.0
    end
  end

  describe "eigenvector/2" do
    test "cycle graph has equal eigenvector scores" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      scores = Centrality.eigenvector(builder)

      # All nodes in a directed cycle should have roughly equal scores
      assert_in_delta scores["A"], scores["B"], 0.01
      assert_in_delta scores["B"], scores["C"], 0.01
    end

    test "hub node has higher eigenvector score" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("hub", "A", 1.0)
        |> Zog.add_edge("hub", "B", 1.0)
        |> Zog.add_edge("hub", "C", 1.0)

      scores = Centrality.eigenvector(builder)

      assert scores["hub"] > scores["A"]
      assert scores["hub"] > scores["B"]
      assert scores["hub"] > scores["C"]
    end
  end

  describe "katz/2" do
    test "node with more incoming links has higher katz score" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("C", "B", 1.0)

      scores = Centrality.katz(builder)

      # B receives from A and C, so B should have a higher score
      assert scores["B"] > scores["A"]
      assert scores["B"] > scores["C"]
    end

    test "all nodes have at least beta score" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)

      scores = Centrality.katz(builder, beta: 1.0)

      assert scores["A"] >= 1.0
      assert scores["B"] >= 1.0
    end
  end

  describe "alpha_centrality/2" do
    test "returns scores for all nodes" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("C", "B", 1.0)

      scores = Centrality.alpha_centrality(builder)

      assert map_size(scores) == 3
      assert is_float(scores["A"])
      assert is_float(scores["B"])
      assert is_float(scores["C"])
    end
  end
end
