#!/usr/bin/env elixir
# Libgraph Interoperability Example
#
# This example demonstrates using YogEx's centrality algorithms on a 
# libgraph Graph through the Queryable protocol.
#
# ## Key Point
#
# Only 7 functions are REQUIRED for full YogEx compatibility!
# All other functions use defaults from Yog.Queryable.Defaults.
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

# =============================================================================
# MINIMAL PROTOCOL IMPLEMENTATION
# =============================================================================
#
# Only 7 functions are REQUIRED for full YogEx algorithm compatibility!
# All other functions automatically use efficient defaults from 
# Yog.Queryable.Defaults.
#
# Required (7):
#   successors/2, predecessors/2, type/1, node/2, all_nodes/1, order/1, edge_count/1
#
# Optional overrides (for O(1) efficiency):
#   out_degree/2, in_degree/2, degree/2
#
# Defaults available (see Yog.Queryable.Defaults):
#   has_node?/2, has_edge?/3, edge_data/3, nodes/1, all_edges/1,
#   successor_ids/2, predecessor_ids/2, neighbors/2, neighbor_ids/2, node_count/1
# =============================================================================

defimpl Yog.Queryable, for: Graph do
  alias Yog.Queryable.Defaults

  # === REQUIRED: 7 Core Functions ===
  # These are the ONLY functions you must implement!

  @doc "Get successors as [{id, weight}] - REQUIRED"
  def successors(graph, id) do
    graph
    |> Graph.out_neighbors(id)
    |> Enum.map(fn neighbor ->
      %Graph.Edge{weight: weight} = Graph.edge(graph, id, neighbor)
      {neighbor, weight}
    end)
  end

  @doc "Get predecessors as [{id, weight}] - REQUIRED"
  def predecessors(graph, id) do
    graph
    |> Graph.in_neighbors(id)
    |> Enum.map(fn neighbor ->
      %Graph.Edge{weight: weight} = Graph.edge(graph, neighbor, id)
      {neighbor, weight}
    end)
  end

  @doc "Graph type - REQUIRED"
  def type(%Graph{type: type}), do: type

  @doc "Number of nodes - REQUIRED"
  def order(graph), do: Graph.num_vertices(graph)

  @doc "Number of edges - REQUIRED"
  def edge_count(graph), do: Graph.num_edges(graph)

  @doc "All node IDs - REQUIRED"
  def all_nodes(graph), do: Graph.vertices(graph)

  @doc "Node data (nil if not found) - REQUIRED"
  def node(graph, id) do
    # libgraph doesn't store separate node data, return ID itself if exists
    if Graph.has_vertex?(graph, id), do: id, else: nil
  end

  # === OVERRIDES: For O(1) Efficiency ===
  # These override the O(degree) defaults with libgraph's O(1) lookups

  @doc "Out-degree (O(1) via libgraph)"
  def out_degree(graph, id), do: Graph.out_degree(graph, id)

  @doc "In-degree (O(1) via libgraph)"
  def in_degree(graph, id), do: Graph.in_degree(graph, id)

  @doc "Total degree (O(1) via libgraph, handles undirected correctly)"
  def degree(graph, id), do: Graph.degree(graph, id)

  # === DEFAULTS: Use Yog.Queryable.Defaults ===
  # These 11 functions work automatically via defaults!
  # Uncomment any to override with optimized implementations.

  defdelegate has_node?(graph, id), to: Defaults
  defdelegate has_edge?(graph, src, dst), to: Defaults
  defdelegate edge_data(graph, src, dst), to: Defaults
  defdelegate nodes(graph), to: Defaults
  defdelegate all_edges(graph), to: Defaults
  defdelegate successor_ids(graph, id), to: Defaults
  defdelegate predecessor_ids(graph, id), to: Defaults
  defdelegate neighbors(graph, id), to: Defaults
  defdelegate neighbor_ids(graph, id), to: Defaults
  defdelegate node_count(graph), to: Defaults
end

# =============================================================================
# DEMO CODE
# =============================================================================

alias Yog.Centrality

IO.puts("=" |> String.duplicate(60))
IO.puts("Libgraph + YogEx Protocol Interoperability Demo")
IO.puts("=" |> String.duplicate(60))
IO.puts("")
IO.puts("Protocol implementation: 7 required + 3 efficiency overrides")
IO.puts("The other 11 functions use defaults from Yog.Queryable.Defaults")
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
IO.puts("Implementation summary:")
IO.puts("  • 7 required functions implemented")
IO.puts("  • 3 efficiency overrides (out_degree, in_degree, degree)")
IO.puts("  • 11 functions delegated to Yog.Queryable.Defaults")
IO.puts("")
IO.puts("Key takeaway: YogEx algorithms work on ANY graph type")
IO.puts("that implements just 7 core functions of Yog.Queryable!")
IO.puts("")
IO.puts("This enables:")
IO.puts("  • libgraph Graph → YogEx Centrality ✓")
IO.puts("  • libgraph Graph → YogEx Pathfinding ✓")
IO.puts("  • libgraph Graph → YogEx Community Detection ✓")
IO.puts("  • And all other YogEx analysis modules ✓")
IO.puts("=" |> String.duplicate(60))
