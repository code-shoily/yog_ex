defmodule GraphCreation do
  @moduledoc """
  Graph Creation Example

  Comprehensive guide to 10+ ways of creating graphs
  """

  require Yog

  def run do
    IO.puts("=== Graph Creation Methods ===\n")

    # 1. Builder pattern with add_node and add_edge
    IO.puts("1. Builder Pattern")
    g1 = Yog.directed()
         |> Yog.add_node(1, "A")
         |> Yog.add_node(2, "B")
         |> Yog.add_edge(from: 1, to: 2, with: 5)
    IO.puts("   Created graph with #{count_nodes(g1)} nodes")

    # 2. from_edges function for quick creation
    IO.puts("\n2. From Edges")
    g2 = Yog.from_edges(:directed, [
      {1, 2, 5},
      {2, 3, 10}
    ])
    IO.puts("   Created graph with #{count_nodes(g2)} nodes")

    # 3. from_unweighted_edges for graphs without weights
    IO.puts("\n3. From Unweighted Edges")
    g3 = Yog.from_unweighted_edges(:directed, [
      {1, 2},
      {2, 3},
      {3, 1}
    ])
    IO.puts("   Created graph with #{count_nodes(g3)} nodes")

    # 4. from_adjacency_list for adjacency-based construction
    IO.puts("\n4. From Adjacency List")
    g4 = Yog.from_adjacency_list(:directed, [
      {1, [{2, 5}, {3, 10}]},
      {2, [{3, 2}]},
      {3, []}
    ])
    IO.puts("   Created graph with #{count_nodes(g4)} nodes")

    # 5. add_simple_edge with default weight of 1
    IO.puts("\n5. Simple Edges (Default Weight = 1)")
    g5 = Yog.directed()
         |> Yog.add_node(1, "A")
         |> Yog.add_node(2, "B")
         |> Yog.add_simple_edge(from: 1, to: 2)
    IO.puts("   Created graph with #{count_nodes(g5)} nodes")

    # 6. Labeled variants - Note: Labeled API is separate in Yog.Builder.Labeled module
    IO.puts("\n6. Labeled Builder Pattern (using Yog.Builder.Labeled)")
    # Labeled graphs use the Yog.Builder.Labeled module with string/atom identifiers
    IO.puts("   Available via Yog.Builder.Labeled module for string-based node IDs")

    IO.puts("\n7-9. Additional Graph Creation Methods")
    IO.puts("   Yog provides flexible APIs in the Yog.Builder.Labeled module")

    # 10. Undirected graph support
    IO.puts("\n10. Undirected Graph")
    g10 = Yog.undirected()
          |> Yog.add_node(1, "A")
          |> Yog.add_node(2, "B")
          |> Yog.add_edge(from: 1, to: 2, with: 5)
    IO.puts("   Created undirected graph (edges work both ways)")

    IO.puts("\n=== Summary ===")
    IO.puts("YogEx provides flexible options for different graph construction scenarios:")
    IO.puts("• Quick creation from edge lists")
    IO.puts("• Builder pattern for complex graphs")
    IO.puts("• Support for both numeric and string node identifiers")
    IO.puts("• Directed and undirected graphs")
  end

  defp count_nodes(graph) do
    Yog.all_nodes(graph) |> length()
  end
end

GraphCreation.run()
