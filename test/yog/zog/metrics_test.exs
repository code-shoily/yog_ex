defmodule Yog.Zog.MetricsTest do
  use ExUnit.Case, async: true

  alias Yog.Builder.Zog
  alias Yog.Zog.Metrics

  @moduletag :zigler

  describe "density/1" do
    test "complete undirected graph has density 1.0" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      assert Metrics.density(builder) == 1.0
    end

    test "empty graph has density 0.0" do
      builder = Zog.undirected()
      assert Metrics.density(builder) == 0.0
    end

    test "single node has density 0.0" do
      builder = Zog.undirected() |> Zog.add_node("A")
      assert Metrics.density(builder) == 0.0
    end

    test "chain graph has density less than 1.0" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)

      # 2 edges out of 3 possible = 0.666...
      assert Metrics.density(builder) < 1.0
      assert Metrics.density(builder) > 0.0
    end
  end

  describe "triangle_count/1" do
    test "triangle has one triangle" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      assert Metrics.triangle_count(builder) == 1
    end

    test "chain has no triangles" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)

      assert Metrics.triangle_count(builder) == 0
    end

    test "two triangles sharing an edge" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)
        |> Zog.add_edge("B", "D", 1.0)
        |> Zog.add_edge("D", "C", 1.0)

      # Triangle ABC and triangle BCD
      assert Metrics.triangle_count(builder) == 2
    end
  end

  describe "average_clustering_coefficient/1" do
    test "complete graph has clustering coefficient 1.0" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      assert Metrics.average_clustering_coefficient(builder) == 1.0
    end

    test "chain has lower clustering than triangle" do
      triangle =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      chain =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)

      assert Metrics.average_clustering_coefficient(chain) <
               Metrics.average_clustering_coefficient(triangle)
    end
  end

  describe "local_clustering_coefficient/1" do
    test "complete graph: all nodes have clustering coefficient 1.0" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      scores = Metrics.local_clustering_coefficient(builder)
      assert map_size(scores) == 3
      assert Enum.all?(scores, fn {_k, v} -> v == 1.0 end)
    end

    test "star graph: center has coefficient 0.0" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("center", "A", 1.0)
        |> Zog.add_edge("center", "B", 1.0)
        |> Zog.add_edge("center", "C", 1.0)

      scores = Metrics.local_clustering_coefficient(builder)
      assert scores["center"] == 0.0
      assert scores["A"] == 0.0
      assert scores["B"] == 0.0
      assert scores["C"] == 0.0
    end

    test "empty graph" do
      builder = Zog.undirected()
      assert Metrics.local_clustering_coefficient(builder) == %{}
    end

    test "single node" do
      builder = Zog.undirected() |> Zog.add_node("A")
      assert Metrics.local_clustering_coefficient(builder) == %{"A" => 0.0}
    end
  end

  describe "assortativity/1" do
    test "returns a value in [-1, 1]" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      r = Metrics.assortativity(builder)
      assert r >= -1.0
      assert r <= 1.0
    end

    test "star graph is disassortative" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("center", "A", 1.0)
        |> Zog.add_edge("center", "B", 1.0)
        |> Zog.add_edge("center", "C", 1.0)

      r = Metrics.assortativity(builder)
      # Star graphs tend to have negative assortativity
      assert r <= 0.0
    end
  end
end
