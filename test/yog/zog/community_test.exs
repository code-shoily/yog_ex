defmodule Yog.Zog.CommunityTest do
  use ExUnit.Case, async: true

  alias Yog.Builder.Zog
  alias Yog.Zog.Community

  @moduletag :zigler

  describe "louvain/2" do
    test "triangle forms a single community" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      assignments = Community.louvain(builder)

      assert map_size(assignments) == 3
      # All nodes in a triangle should end up in the same community
      assert assignments["A"] == assignments["B"]
      assert assignments["B"] == assignments["C"]
    end

    test "two disconnected triangles form two communities" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)
        |> Zog.add_edge("D", "E", 1.0)
        |> Zog.add_edge("E", "F", 1.0)
        |> Zog.add_edge("F", "D", 1.0)

      assignments = Community.louvain(builder)

      # Nodes in the first triangle share a community
      assert assignments["A"] == assignments["B"]
      assert assignments["B"] == assignments["C"]

      # Nodes in the second triangle share a community
      assert assignments["D"] == assignments["E"]
      assert assignments["E"] == assignments["F"]

      # The two communities are different
      refute assignments["A"] == assignments["D"]
    end

    test "empty graph returns empty map" do
      builder = Zog.undirected()
      assignments = Community.louvain(builder)
      assert assignments == %{}
    end

    test "single node returns single community" do
      builder = Zog.undirected() |> Zog.add_node("A")
      assignments = Community.louvain(builder)
      assert assignments == %{"A" => 0}
    end
  end

  describe "leiden/2" do
    test "triangle forms a single community" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      assignments = Community.leiden(builder)

      assert map_size(assignments) == 3
      assert assignments["A"] == assignments["B"]
      assert assignments["B"] == assignments["C"]
    end

    test "two disconnected triangles form two communities" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)
        |> Zog.add_edge("D", "E", 1.0)
        |> Zog.add_edge("E", "F", 1.0)
        |> Zog.add_edge("F", "D", 1.0)

      assignments = Community.leiden(builder)

      # Nodes in the first triangle share a community
      assert assignments["A"] == assignments["B"]
      assert assignments["B"] == assignments["C"]

      # Nodes in the second triangle share a community
      assert assignments["D"] == assignments["E"]
      assert assignments["E"] == assignments["F"]

      # The two communities are different
      refute assignments["A"] == assignments["D"]
    end

    test "empty graph returns empty map" do
      builder = Zog.undirected()
      assignments = Community.leiden(builder)
      assert assignments == %{}
    end

    test "single node returns single community" do
      builder = Zog.undirected() |> Zog.add_node("A")
      assignments = Community.leiden(builder)
      assert assignments == %{"A" => 0}
    end
  end

  describe "leiden_hierarchical/2" do
    test "returns a valid Dendrogram for simple triangles" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)
        |> Zog.add_edge("D", "E", 1.0)
        |> Zog.add_edge("E", "F", 1.0)
        |> Zog.add_edge("F", "D", 1.0)
        |> Zog.add_edge("C", "D", 1.0)

      dend = Community.leiden_hierarchical(builder)

      assert %Yog.Community.Dendrogram{} = dend
      assert length(dend.levels) > 0

      # Each level should be a Result
      for level <- dend.levels do
        assert %Yog.Community.Result{} = level
        assert map_size(level.assignments) == 6
      end
    end
  end

  describe "modularity/2" do
    test "perfect partition has positive modularity" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)
        |> Zog.add_edge("D", "E", 1.0)
        |> Zog.add_edge("E", "F", 1.0)
        |> Zog.add_edge("F", "D", 1.0)

      # Two perfect communities
      assignments = %{
        "A" => 0,
        "B" => 0,
        "C" => 0,
        "D" => 1,
        "E" => 1,
        "F" => 1
      }

      q = Community.modularity(builder, assignments)
      assert q > 0.0
    end

    test "random partition has lower modularity than good partition" do
      builder =
        Zog.undirected()
        |> Zog.add_edge("A", "B", 1.0)
        |> Zog.add_edge("B", "C", 1.0)
        |> Zog.add_edge("C", "A", 1.0)

      good = %{"A" => 0, "B" => 0, "C" => 0}
      bad = %{"A" => 0, "B" => 1, "C" => 2}

      q_good = Community.modularity(builder, good)
      q_bad = Community.modularity(builder, bad)

      assert q_good > q_bad
    end
  end
end
