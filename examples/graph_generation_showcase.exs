defmodule GraphGenerationShowcase do
  @moduledoc """
  Graph Generation Showcase Example

  Demonstrates all 9 classic graph patterns with statistics
  """

  require Yog

  def run do
    IO.puts("=== Graph Generation Showcase ===\n")

    # Complete graphs
    IO.puts("1. Complete Graph K_5")
    k5 = Yog.Generators.complete(5)
    print_graph_stats("K_5", k5)
    IO.puts("  Every node connected to every other node")
    IO.puts("  Perfect for studying maximum connectivity\n")

    # Cycle graphs
    IO.puts("2. Cycle Graph C_6")
    c6 = Yog.Generators.cycle(6)
    print_graph_stats("C_6", c6)
    IO.puts("  Nodes form a ring: 0-1-2-3-4-5-0")
    IO.puts("  Perfect for studying circular structures\n")

    # Path graphs
    IO.puts("3. Path Graph P_5")
    p5 = Yog.Generators.path(5)
    print_graph_stats("P_5", p5)
    IO.puts("  Linear chain: 0-1-2-3-4")
    IO.puts("  Perfect for studying sequential processes\n")

    # Star graphs
    IO.puts("4. Star Graph S_6")
    s6 = Yog.Generators.star(6)
    print_graph_stats("S_6", s6)
    IO.puts("  Central node (0) connected to all others")
    IO.puts("  Perfect for studying hub-and-spoke networks\n")

    # Wheel graphs
    IO.puts("5. Wheel Graph W_6")
    w6 = Yog.Generators.wheel(6)
    print_graph_stats("W_6", w6)
    IO.puts("  Cycle with central hub")
    IO.puts("  Perfect for studying hybrid topologies\n")

    # Complete bipartite
    IO.puts("6. Complete Bipartite K_{3,3}")
    k33 = Yog.Generators.complete_bipartite(3, 3)
    print_graph_stats("K_3,3", k33)
    IO.puts("  Two groups: nodes 0-2 and 3-5")
    IO.puts("  Every node in one group connected to all in other")
    IO.puts("  Perfect for studying matching problems\n")

    # Binary tree
    IO.puts("7. Binary Tree (depth 3)")
    tree = Yog.Generators.binary_tree(3)
    print_graph_stats("Binary Tree", tree)
    IO.puts("  Complete binary tree with 15 nodes")
    IO.puts("  Root at 0, children at 2i+1 and 2i+2")
    IO.puts("  Perfect for studying hierarchical structures\n")

    # Grid 2D
    IO.puts("8. 2D Grid (3x4)")
    grid = Yog.Generators.grid_2d(3, 4)
    print_graph_stats("3x4 Grid", grid)
    IO.puts("  Rectangular lattice with 12 nodes")
    IO.puts("  Perfect for studying spatial problems\n")

    # Petersen graph
    IO.puts("9. Petersen Graph")
    petersen = Yog.Generators.petersen()
    print_graph_stats("Petersen", petersen)
    IO.puts("  Famous 3-regular graph with 10 nodes")
    IO.puts("  Perfect for counterexamples in graph theory\n")

    IO.puts("=== Use Cases ===")
    IO.puts("• Testing: Graphs with known properties")
    IO.puts("• Benchmarking: Graphs of various sizes")
    IO.puts("• Education: Classic structures for learning")
    IO.puts("• Prototyping: Quick graph creation\n")

    IO.puts("=== Directed vs Undirected ===")
    directed_k4 = Yog.Generators.complete_with_type(4, :directed)
    undirected_k4 = Yog.Generators.complete_with_type(4, :undirected)

    IO.puts("Directed K_4 edges: #{count_edges(directed_k4)}")
    IO.puts("Undirected K_4 edges: #{div(count_edges(undirected_k4), 2)}")
    IO.puts("(Directed has edges in both directions)")
  end

  defp print_graph_stats(_name, graph) do
    node_count = Yog.all_nodes(graph) |> length()
    edge_count = count_edges(graph)

    # Get graph type from the graph structure
    graph_type = elem(graph, 1)
    display_edges = case graph_type do
      :undirected -> div(edge_count, 2)
      :directed -> edge_count
    end

    IO.puts("  Nodes: #{node_count}")
    IO.puts("  Edges: #{display_edges}")
  end

  defp count_edges(graph) do
    Yog.all_nodes(graph)
    |> Enum.reduce(0, fn node, count ->
      successors = Yog.successors(graph, node)
      count + length(successors)
    end)
  end
end

GraphGenerationShowcase.run()
