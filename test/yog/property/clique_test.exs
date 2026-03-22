defmodule Yog.Property.CliqueTest do
  use ExUnit.Case

  alias Yog.Property.Clique

  doctest Yog.Property.Clique

  # ============= Max Clique Tests =============

  test "max_clique finds complete subgraph in triangle" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)

    clique = Clique.max_clique(graph)
    assert MapSet.size(clique) == 3
    assert MapSet.equal?(clique, MapSet.new([1, 2, 3]))
  end

  test "max_clique in graph with larger clique" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_node(5, "E")
      # Complete subgraph on {1, 2, 3}
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      # 4 only connects to 1 and 2 (not a clique of 4)
      |> Yog.add_edge!(from: 4, to: 1, with: 1)
      |> Yog.add_edge!(from: 4, to: 2, with: 1)
      # 5 is isolated
      |> Yog.add_edge!(from: 5, to: 1, with: 1)

    clique = Clique.max_clique(graph)
    assert MapSet.size(clique) == 3
  end

  test "max_clique in graph with no edges" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    clique = Clique.max_clique(graph)
    # Single node is the max clique
    assert MapSet.size(clique) == 1
  end

  # ============= All Maximal Cliques Tests =============

  test "all_maximal_cliques finds all cliques" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      # Triangle {1, 2, 3}
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)
      # Edge {3, 4}
      |> Yog.add_edge!(from: 3, to: 4, with: 1)

    cliques = Clique.all_maximal_cliques(graph)
    assert length(cliques) >= 2
  end

  # ============= K-Cliques Tests =============

  test "k_cliques finds triangles" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      # Triangle {1, 2, 3}
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      |> Yog.add_edge!(from: 1, to: 3, with: 1)
      # 4 connects to 2 and 3 (forms second triangle)
      |> Yog.add_edge!(from: 4, to: 2, with: 1)
      |> Yog.add_edge!(from: 4, to: 3, with: 1)

    triangles = Clique.k_cliques(graph, 3)
    assert length(triangles) == 2

    triangle_sets = Enum.map(triangles, &MapSet.new/1)
    assert MapSet.new([1, 2, 3]) in triangle_sets
    assert MapSet.new([2, 3, 4]) in triangle_sets
  end

  test "k_cliques with k=2 finds edges" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)

    pairs = Clique.k_cliques(graph, 2)
    assert length(pairs) == 2
  end
end
