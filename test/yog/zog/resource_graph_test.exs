defmodule Yog.Zog.ResourceGraphTest do
  use ExUnit.Case, async: true

  alias Yog.Builder.Zog
  alias Yog.Zog.ResourceGraph

  @moduletag :zigler

  describe "new/1 and destroy/1" do
    test "builds and destroys a resource" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)

      graph = ResourceGraph.new(builder)
      assert is_reference(graph.resource)
      assert graph.builder == builder

      assert ResourceGraph.destroy(graph) == :ok
    end

    test "empty graph" do
      builder = Zog.undirected()
      graph = ResourceGraph.new(builder)
      assert is_reference(graph.resource)
      ResourceGraph.destroy(graph)
    end

    test "single node" do
      builder = Zog.undirected() |> Zog.add_node("A")
      graph = ResourceGraph.new(builder)
      assert is_reference(graph.resource)
      ResourceGraph.destroy(graph)
    end
  end

  describe "betweenness_unweighted/1" do
    test "path graph" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)

      graph = ResourceGraph.new(builder)

      scores = ResourceGraph.betweenness_unweighted(graph)
      assert scores["B"] > scores["A"]
      assert scores["B"] > scores["C"]

      ResourceGraph.destroy(graph)
    end

    test "same results as pure Elixir" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      graph = ResourceGraph.new(builder)
      native = ResourceGraph.betweenness_unweighted(graph)

      # Pure Elixir returns integer-keyed maps; convert to label-keyed
      elixir_raw = Yog.Centrality.betweenness(Zog.to_graph(builder))

      elixir =
        Map.new(Zog.all_labels(builder), fn label ->
          idx = Zog.label_to_id(builder, label)
          {label, elixir_raw[idx]}
        end)

      for {label, _idx} <- Enum.with_index(Zog.all_labels(builder)) do
        assert_in_delta native[label], elixir[label], 0.0001
      end

      ResourceGraph.destroy(graph)
    end
  end

  describe "pagerank/1" do
    test "star graph — center has highest score" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("center", "A", 1.0)
        |> Zog.add_edge("center", "B", 1.0)
        |> Zog.add_edge("center", "C", 1.0)

      graph = ResourceGraph.new(builder)
      scores = ResourceGraph.pagerank(graph)

      assert scores["center"] > scores["A"]
      assert scores["center"] > scores["B"]
      assert scores["center"] > scores["C"]

      ResourceGraph.destroy(graph)
    end

    test "same results as pure Elixir" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      graph = ResourceGraph.new(builder)
      native = ResourceGraph.pagerank(graph)

      elixir_raw = Yog.Centrality.pagerank(Zog.to_graph(builder))

      elixir =
        Map.new(Zog.all_labels(builder), fn label ->
          idx = Zog.label_to_id(builder, label)
          {label, elixir_raw[idx]}
        end)

      for {label, _idx} <- Enum.with_index(Zog.all_labels(builder)) do
        assert_in_delta native[label], elixir[label], 0.0001
      end

      ResourceGraph.destroy(graph)
    end
  end

  describe "closeness_f64/1" do
    test "same results as pure Elixir" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "D", 1.0)

      graph = ResourceGraph.new(builder)
      native = ResourceGraph.closeness_f64(graph)

      elixir_raw = Yog.Centrality.closeness(Zog.to_graph(builder))

      elixir =
        Map.new(Zog.all_labels(builder), fn label ->
          idx = Zog.label_to_id(builder, label)
          {label, elixir_raw[idx]}
        end)

      for {label, _idx} <- Enum.with_index(Zog.all_labels(builder)) do
        assert_in_delta native[label], elixir[label], 0.0001
      end

      ResourceGraph.destroy(graph)
    end
  end

  describe "louvain/1" do
    test "two triangles" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)
        |> Zog.add_edge("D", "E", 1.0)
        |> Zog.add_edge("E", "F", 1.0)
        |> Zog.add_edge("F", "D", 1.0)

      graph = ResourceGraph.new(builder)
      communities = ResourceGraph.louvain(graph)

      # Each triangle should be its own community
      assert Map.get(communities, "A") == Map.get(communities, "B")
      assert Map.get(communities, "A") == Map.get(communities, "C")
      assert Map.get(communities, "D") == Map.get(communities, "E")
      assert Map.get(communities, "D") == Map.get(communities, "F")
      assert Map.get(communities, "A") != Map.get(communities, "D")

      ResourceGraph.destroy(graph)
    end
  end

  describe "metrics" do
    test "density of complete graph" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      graph = ResourceGraph.new(builder)
      # For undirected graphs represented bidirectionally, density is 1.0
      assert ResourceGraph.density(graph) == 1.0
      ResourceGraph.destroy(graph)
    end

    test "triangle_count" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      graph = ResourceGraph.new(builder)
      assert ResourceGraph.triangle_count(graph) == 1
      ResourceGraph.destroy(graph)
    end

    test "average_clustering_coefficient" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      graph = ResourceGraph.new(builder)
      assert ResourceGraph.average_clustering_coefficient(graph) == 1.0
      ResourceGraph.destroy(graph)
    end

    test "local_clustering_coefficient" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      graph = ResourceGraph.new(builder)
      scores = ResourceGraph.local_clustering_coefficient(graph)
      assert scores["A"] == 1.0
      assert scores["B"] == 1.0
      assert scores["C"] == 1.0
      ResourceGraph.destroy(graph)
    end

    test "assortativity" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      graph = ResourceGraph.new(builder)
      r = ResourceGraph.assortativity(graph)
      assert r >= -1.0
      assert r <= 1.0
      ResourceGraph.destroy(graph)
    end
  end

  describe "pathfinding" do
    test "floyd_warshall triangle" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      graph = ResourceGraph.new(builder)
      {:ok, matrix} = ResourceGraph.floyd_warshall(graph)

      assert hd(matrix) == [0.0, 1.0, 2.0]
      assert Enum.at(matrix, 1) == [2.0, 0.0, 1.0]
      assert Enum.at(matrix, 2) == [1.0, 2.0, 0.0]

      ResourceGraph.destroy(graph)
    end

    test "floyd_warshall detects negative cycle" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", -2.0)
        |> Zog.add_edge("C", "A", -1.0)

      graph = ResourceGraph.new(builder)
      assert ResourceGraph.floyd_warshall(graph) == {:error, :negative_cycle}
      ResourceGraph.destroy(graph)
    end

    test "johnsons triangle" do
      builder =
        Zog.directed()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      graph = ResourceGraph.new(builder)
      {:ok, matrix} = ResourceGraph.johnsons(graph)

      assert hd(matrix) == [0.0, 1.0, 2.0]
      assert Enum.at(matrix, 1) == [2.0, 0.0, 1.0]
      assert Enum.at(matrix, 2) == [1.0, 2.0, 0.0]

      ResourceGraph.destroy(graph)
    end
  end

  describe "multiple algorithms on same resource" do
    test "betweenness then pagerank then closeness" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)
        |> Zog.add_edge("B", "D", 1.0)

      graph = ResourceGraph.new(builder)

      b = ResourceGraph.betweenness_unweighted(graph)
      pr = ResourceGraph.pagerank(graph)
      c = ResourceGraph.closeness_f64(graph)

      assert map_size(b) == 4
      assert map_size(pr) == 4
      assert map_size(c) == 4

      ResourceGraph.destroy(graph)
    end
  end

  describe "modularity/2" do
    test "computes modularity for louvain result" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)
        |> Zog.add_edge("D", "E", 1.0)
        |> Zog.add_edge("E", "F", 1.0)
        |> Zog.add_edge("F", "D", 1.0)

      graph = ResourceGraph.new(builder)
      communities = ResourceGraph.louvain(graph)
      q = ResourceGraph.modularity(graph, communities)
      # Two disconnected triangles should have positive modularity
      assert q > 0.0
      ResourceGraph.destroy(graph)
    end
  end
end
