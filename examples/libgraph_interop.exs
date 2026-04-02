#!/usr/bin/env elixir
# Libgraph Interoperability Example
#
# This example demonstrates using YogEx's centrality algorithms on a 
# libgraph Graph through the Queryable protocol.
#
# ## Running this example
#
# Create a temporary Mix project and run the example:
#
#     mkdir /tmp/libgraph_demo && cd /tmp/libgraph_demo
#     cat > mix.exs << 'EOF'
#     defmodule Demo.MixProject do
#       use Mix.Project
#       def project do
#         [
#           app: :demo,
#           version: "0.1.0",
#           elixir: "~> 1.15",
#           consolidate_protocols: false,
#           deps: [
#             {:libgraph, "~> 0.16"},
#             {:yog_ex, path: "/path/to/yog_ex"}
#           ]
#         ]
#       end
#     end
#     EOF
#     mix deps.get
#     mix run /path/to/yog_ex/examples/libgraph_interop.exs

# Only use Mix.install when NOT in a Mix project
if !Code.ensure_loaded?(Mix.Project) || is_nil(Mix.Project.get()) do
  Mix.install([
    {:libgraph, "~> 0.16"},
    {:yog_ex, path: Path.expand("..", __DIR__)}
  ])
end

# Check if protocols are consolidated - if so, give instructions
if Protocol.consolidated?(Yog.Queryable) do
  IO.puts("""
  ⚠️  Protocols are already consolidated.

  Please create a temporary Mix project to run this example:

      mkdir /tmp/libgraph_demo && cd /tmp/libgraph_demo
      cat > mix.exs << 'EOF'
      defmodule Demo.MixProject do
        use Mix.Project
        def project do
          [
            app: :demo,
            version: "0.1.0",
            elixir: "~> 1.15",
            consolidate_protocols: false,
            deps: [
              {:libgraph, "~> 0.16"},
              {:yog_ex, path: "#{Path.expand("..", __DIR__)}"}
            ]
          ]
        end
      end
      EOF
      mix deps.get
      mix run #{__ENV__.file}
  """)

  System.halt(1)
end

# Define the protocol implementation for libgraph's Graph struct
defimpl Yog.Queryable, for: Graph do
  def successors(graph, id) do
    graph
    |> Graph.out_neighbors(id)
    |> Enum.map(fn neighbor ->
      %Graph.Edge{weight: weight} = Graph.edge(graph, id, neighbor)
      {neighbor, weight}
    end)
  end

  def predecessors(graph, id) do
    graph
    |> Graph.in_neighbors(id)
    |> Enum.map(fn neighbor ->
      %Graph.Edge{weight: weight} = Graph.edge(graph, neighbor, id)
      {neighbor, weight}
    end)
  end

  def neighbors(graph, id) do
    # Combine successors and predecessors without duplicates
    succs = successors(graph, id) |> Map.new()
    preds = predecessors(graph, id) |> Map.new()

    Map.merge(preds, succs)
    |> Map.to_list()
  end

  def successor_ids(graph, id) do
    Graph.out_neighbors(graph, id)
  end

  def predecessor_ids(graph, id) do
    Graph.in_neighbors(graph, id)
  end

  def neighbor_ids(graph, id) do
    succs = successor_ids(graph, id) |> MapSet.new()
    preds = predecessor_ids(graph, id) |> MapSet.new()

    MapSet.union(succs, preds)
    |> MapSet.to_list()
  end

  def all_nodes(graph) do
    Graph.vertices(graph)
  end

  def order(graph) do
    Graph.num_vertices(graph)
  end

  def node_count(graph), do: order(graph)

  def edge_count(graph) do
    Graph.num_edges(graph)
  end

  def out_degree(graph, id) do
    Graph.out_degree(graph, id)
  end

  def in_degree(graph, id) do
    Graph.in_degree(graph, id)
  end

  def degree(graph, id) do
    out_degree(graph, id) + in_degree(graph, id)
  end

  def has_node?(graph, id) do
    Graph.has_vertex?(graph, id)
  end

  def has_edge?(graph, src, dst) do
    Graph.edge(graph, src, dst) != nil
  end

  def node(graph, id) do
    # libgraph doesn't store node data separately, return the ID itself
    if has_node?(graph, id), do: id, else: nil
  end

  def nodes(graph) do
    all_nodes(graph)
    |> Map.new(fn id -> {id, id} end)
  end

  def edge_data(graph, src, dst) do
    case Graph.edge(graph, src, dst) do
      %Graph.Edge{v1: ^src, v2: ^dst, weight: weight} -> weight
      _ -> nil
    end
  end

  def all_edges(graph) do
    graph
    |> Graph.edges()
    |> Enum.map(fn {src, dst, weight} -> {src, dst, weight} end)
  end

  def type(%Graph{type: type}), do: type
end

# Main example code
alias Yog.Centrality

IO.puts("=" |> String.duplicate(60))
IO.puts("Libgraph + YogEx Protocol Interoperability Demo")
IO.puts("=" |> String.duplicate(60))
IO.puts("")

# Create a libgraph graph (Zachary's Karate Club - a classic network)
IO.puts("Creating a libgraph Graph (Zachary's Karate Club network)...")

karate_club =
  Graph.new(type: :undirected)
  |> Graph.add_vertices(Enum.to_list(1..34))
  # Club members and their connections
  |> Graph.add_edge(1, 2, weight: 1)
  |> Graph.add_edge(1, 3, weight: 1)
  |> Graph.add_edge(2, 3, weight: 1)
  |> Graph.add_edge(1, 4, weight: 1)
  |> Graph.add_edge(2, 4, weight: 1)
  |> Graph.add_edge(3, 4, weight: 1)
  |> Graph.add_edge(1, 5, weight: 1)
  |> Graph.add_edge(1, 6, weight: 1)
  |> Graph.add_edge(1, 7, weight: 1)
  |> Graph.add_edge(5, 7, weight: 1)
  |> Graph.add_edge(6, 7, weight: 1)
  |> Graph.add_edge(1, 8, weight: 1)
  |> Graph.add_edge(2, 8, weight: 1)
  |> Graph.add_edge(3, 8, weight: 1)
  |> Graph.add_edge(4, 8, weight: 1)
  |> Graph.add_edge(1, 9, weight: 1)
  |> Graph.add_edge(3, 9, weight: 1)
  |> Graph.add_edge(3, 10, weight: 1)
  |> Graph.add_edge(1, 11, weight: 1)
  |> Graph.add_edge(5, 11, weight: 1)
  |> Graph.add_edge(6, 11, weight: 1)
  |> Graph.add_edge(1, 12, weight: 1)
  |> Graph.add_edge(1, 13, weight: 1)
  |> Graph.add_edge(4, 13, weight: 1)
  |> Graph.add_edge(1, 14, weight: 1)
  |> Graph.add_edge(2, 14, weight: 1)
  |> Graph.add_edge(3, 14, weight: 1)
  |> Graph.add_edge(4, 14, weight: 1)
  |> Graph.add_edge(6, 17, weight: 1)
  |> Graph.add_edge(7, 17, weight: 1)
  |> Graph.add_edge(1, 18, weight: 1)
  |> Graph.add_edge(2, 18, weight: 1)
  |> Graph.add_edge(1, 20, weight: 1)
  |> Graph.add_edge(2, 20, weight: 1)
  |> Graph.add_edge(1, 22, weight: 1)
  |> Graph.add_edge(2, 22, weight: 1)
  |> Graph.add_edge(24, 26, weight: 1)
  |> Graph.add_edge(25, 26, weight: 1)
  |> Graph.add_edge(3, 28, weight: 1)
  |> Graph.add_edge(24, 28, weight: 1)
  |> Graph.add_edge(25, 28, weight: 1)
  |> Graph.add_edge(3, 29, weight: 1)
  |> Graph.add_edge(24, 30, weight: 1)
  |> Graph.add_edge(27, 30, weight: 1)
  |> Graph.add_edge(2, 31, weight: 1)
  |> Graph.add_edge(9, 31, weight: 1)
  |> Graph.add_edge(1, 32, weight: 1)
  |> Graph.add_edge(25, 32, weight: 1)
  |> Graph.add_edge(26, 32, weight: 1)
  |> Graph.add_edge(28, 32, weight: 1)
  |> Graph.add_edge(1, 33, weight: 1)
  |> Graph.add_edge(2, 33, weight: 1)
  |> Graph.add_edge(9, 33, weight: 1)
  |> Graph.add_edge(19, 33, weight: 1)
  |> Graph.add_edge(1, 34, weight: 1)
  |> Graph.add_edge(2, 34, weight: 1)
  |> Graph.add_edge(3, 34, weight: 1)

IO.puts(
  "✓ Created libgraph with #{Graph.num_vertices(karate_club)} nodes and #{Graph.num_edges(karate_club)} edges"
)

IO.puts("")

# Use YogEx's centrality algorithms on the libgraph graph!
IO.puts("Running YogEx Centrality.degree/1 on libgraph Graph...")
degree_scores = Centrality.degree(karate_club)

IO.puts("\nTop 5 most connected members (degree centrality):")

degree_scores
|> Enum.sort_by(fn {_, score} -> score end, :desc)
|> Enum.take(5)
|> Enum.with_index(1)
|> Enum.each(fn {{node, score}, rank} ->
  IO.puts("  #{rank}. Member #{node}: #{score} connections")
end)

IO.puts("")
IO.puts("Running YogEx Centrality.pagerank/2 on libgraph Graph...")
pagerank_scores = Centrality.pagerank(karate_club, damping_factor: 0.85, iterations: 100)

IO.puts("\nTop 5 most influential members (PageRank):")

pagerank_scores
|> Enum.sort_by(fn {_, score} -> score end, :desc)
|> Enum.take(5)
|> Enum.with_index(1)
|> Enum.each(fn {{node, score}, rank} ->
  IO.puts("  #{rank}. Member #{node}: #{Float.round(score, 4)}")
end)

IO.puts("")
IO.puts("Running YogEx Centrality.betweenness/1 on libgraph Graph...")
betweenness_scores = Centrality.betweenness(karate_club)

IO.puts("\nTop 5 bridge members (betweenness centrality):")

betweenness_scores
|> Enum.sort_by(fn {_, score} -> score end, :desc)
|> Enum.take(5)
|> Enum.with_index(1)
|> Enum.each(fn {{node, score}, rank} ->
  IO.puts("  #{rank}. Member #{node}: #{Float.round(score, 4)}")
end)

IO.puts("")
IO.puts("=" |> String.duplicate(60))
IO.puts("Demo complete! 🎉")
IO.puts("")
IO.puts("Key takeaway: YogEx algorithms work on ANY graph type")
IO.puts("that implements the Yog.Queryable protocol.")
IO.puts("")
IO.puts("The protocol implementation above enables:")
IO.puts("  • libgraph Graph → YogEx Centrality ✓")
IO.puts("  • libgraph Graph → YogEx Pathfinding ✓")
IO.puts("  • libgraph Graph → YogEx Community Detection ✓")
IO.puts("  • And all other YogEx analysis modules ✓")
IO.puts("=" |> String.duplicate(60))
