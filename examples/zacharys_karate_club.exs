defmodule ZacharysKarateClub do
  @moduledoc """
  Zachary's Karate Club Example

  A classic social network dataset showing the split of a karate club
  into two factions after a dispute.
  """
  def run do
    # Create an undirected graph
    graph = Yog.undirected()

    # Define the 34 nodes and their factions (Ground Truth)
    # Faction 1: Mr. Hi, Faction 2: Officer
    nodes = [
      {1, "Mr. Hi"}, {2, "Mr. Hi"}, {3, "Mr. Hi"}, {4, "Mr. Hi"}, {5, "Mr. Hi"},
      {6, "Mr. Hi"}, {7, "Mr. Hi"}, {8, "Mr. Hi"}, {9, "Mr. Hi"}, {10, "Officer"},
      {11, "Mr. Hi"}, {12, "Mr. Hi"}, {13, "Mr. Hi"}, {14, "Mr. Hi"}, {15, "Officer"},
      {16, "Officer"}, {17, "Mr. Hi"}, {18, "Mr. Hi"}, {19, "Officer"}, {20, "Mr. Hi"},
      {21, "Officer"}, {22, "Mr. Hi"}, {23, "Officer"}, {24, "Officer"}, {25, "Officer"},
      {26, "Officer"}, {27, "Officer"}, {28, "Officer"}, {29, "Officer"}, {30, "Officer"},
      {31, "Officer"}, {32, "Officer"}, {33, "Officer"}, {34, "Officer"}
    ]

    # Add nodes with their faction as the label
    graph = Enum.reduce(nodes, graph, fn {id, faction}, g ->
      Yog.add_node(g, id, faction)
    end)

    # Standard 78 edges for Zachary's Karate Club
    edges = [
      {1, 2}, {1, 3}, {1, 4}, {1, 5}, {1, 6}, {1, 7}, {1, 8}, {1, 9}, {1, 11}, {1, 12}, {1, 13}, {1, 14}, {1, 18}, {1, 20}, {1, 22}, {1, 32},
      {2, 3}, {2, 4}, {2, 8}, {2, 14}, {2, 18}, {2, 20}, {2, 22}, {2, 31},
      {3, 4}, {3, 8}, {3, 9}, {3, 10}, {3, 14}, {3, 28}, {3, 29}, {3, 33},
      {4, 8}, {4, 13}, {4, 14},
      {5, 7}, {5, 11},
      {6, 7}, {6, 11}, {6, 17},
      {7, 17},
      {9, 31}, {9, 33}, {9, 34},
      {10, 34},
      {14, 34},
      {15, 33}, {15, 34},
      {16, 33}, {16, 34},
      {19, 33}, {19, 34},
      {20, 34},
      {21, 33}, {21, 34},
      {23, 33}, {23, 34},
      {24, 26}, {24, 28}, {24, 30}, {24, 33}, {24, 34},
      {25, 26}, {25, 28}, {25, 32},
      {26, 32},
      {27, 30}, {27, 34},
      {28, 34},
      {29, 32}, {29, 34},
      {30, 33}, {30, 34},
      {31, 33}, {31, 34},
      {32, 33}, {32, 34},
      {33, 34}
    ]

    # Add edges to the graph
    graph = Enum.reduce(edges, graph, fn {u, v}, g ->
      Yog.add_edge!(g, u, v, 1)
    end)

    IO.puts("Zachary's Karate Club Summary:")
    IO.puts("- Nodes: #{Yog.Model.order(graph)}")
    IO.puts("- Edges: #{Yog.Model.edge_count(graph)}")
    IO.puts("- Density: #{Float.round(Yog.Community.density(graph), 4)}")
    IO.puts("- Avg Clustering: #{Float.round(Yog.Community.average_clustering_coefficient(graph), 4)}")
    IO.puts("")

    # Identify influential members using Degree Centrality
    IO.puts("Top 5 Incremental Influencers (Degree Centrality):")
    Yog.Centrality.degree(graph)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
    |> Enum.take(5)
    |> Enum.each(fn {node, score} ->
      IO.puts("  Node #{node} (#{Yog.Model.node(graph, node)}): #{score}")
    end)
    IO.puts("")

    # Detect communities using Leiden algorithm with custom resolution
    # Lower resolution encourages larger communities
    IO.puts("Detecting Communities (Louvain Algorithm, resolution: 0.3):")
    communities = Yog.Community.Louvain.detect_with_options(graph, resolution: 0.3)
    IO.puts("- Communities found: #{communities.num_communities}")

    # Calculate modularity using the same resolution
    modularity = Yog.Community.modularity(graph, communities, resolution: 0.3)
    IO.puts("- Modularity score: #{Float.round(modularity, 4)}")
    IO.puts("")

    # Compare detected communities with ground truth factions
    # (Mapping community IDs to faction counts)
    community_to_factions =
      Enum.reduce(communities.assignments, %{}, fn {node, comm_id}, acc ->
        faction = Yog.Model.node(graph, node)
        current_counts = Map.get(acc, comm_id, %{})
        new_counts = Map.update(current_counts, faction, 1, &(&1 + 1))
        Map.put(acc, comm_id, new_counts)
      end)

    IO.puts("Detected Communities vs Ground Truth Factions:")
    Enum.each(community_to_factions, fn {comm_id, factions} ->
      faction_str = factions
                    |> Enum.map(fn {f, c} -> "#{f}: #{c}" end)
                    |> Enum.join(", ")
      IO.puts("  Community #{comm_id}: [#{faction_str}]")
    end)
  end
end

ZacharysKarateClub.run()
