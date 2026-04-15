defmodule Yog.MatchingTest do
  use ExUnit.Case

  doctest Yog.Matching

  alias Yog.Matching

  test "hopcroft_karp_empty_graph_test" do
    graph = Yog.undirected()
    matching = Matching.hopcroft_karp(graph)

    assert matching == %{}
  end

  test "hopcroft_karp_path_graph_test" do
    # 1 -- 2 -- 3 -- 4
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 4, 1}])

    matching = Matching.hopcroft_karp(graph)

    # Maximum matching size is 2 edges = 4 nodes
    assert map_size(matching) == 4
    assert valid_matching?(matching)
  end

  test "hopcroft_karp_star_graph_test" do
    # 1 connected to 2, 3, 4
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {1, 3, 1}, {1, 4, 1}])

    matching = Matching.hopcroft_karp(graph)

    # Only 1 edge possible in a star
    assert map_size(matching) == 2
    assert valid_matching?(matching)
  end

  test "hopcroft_karp_complete_bipartite_test" do
    # K_{3,3}
    graph =
      Yog.from_edges(:undirected, [
        {:a1, :b1, 1},
        {:a1, :b2, 1},
        {:a1, :b3, 1},
        {:a2, :b1, 1},
        {:a2, :b2, 1},
        {:a2, :b3, 1},
        {:a3, :b1, 1},
        {:a3, :b2, 1},
        {:a3, :b3, 1}
      ])

    matching = Matching.hopcroft_karp(graph)

    # All 6 nodes should be matched (3 edges * 2 directions)
    assert map_size(matching) == 6
    assert valid_matching?(matching)
    assert div(map_size(matching), 2) == 3
  end

  test "hopcroft_karp_non_bipartite_raises_test" do
    # Triangle is not bipartite
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])

    assert_raise ArgumentError, fn ->
      Matching.hopcroft_karp(graph)
    end
  end

  test "hopcroft_karp_disjoint_components_test" do
    # Two separate edges: 1-2 and 3-4
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {3, 4, 1}])

    matching = Matching.hopcroft_karp(graph)

    assert map_size(matching) == 4
    assert valid_matching?(matching)
    # Verify 1 and 2 are matched to each other
    assert matching[1] in [2, 3, 4]
    assert matching[matching[1]] == 1
    # Verify all 4 nodes are present
    nodes = Map.keys(matching) |> MapSet.new()
    assert MapSet.equal?(nodes, MapSet.new([1, 2, 3, 4]))
  end

  test "hopcroft_karp_example_from_issue_test" do
    graph =
      Yog.from_edges(:undirected, [
        {:a1, :b1, 1},
        {:a1, :b2, 1},
        {:a2, :b2, 1},
        {:a2, :b3, 1}
      ])

    matching = Matching.hopcroft_karp(graph)

    assert map_size(matching) == 4
    assert valid_matching?(matching)
    assert matching[:a1] in [:b1, :b2]
    assert matching[:a2] in [:b2, :b3]
    assert matching[:a1] != matching[:a2]
  end

  test "hopcroft_karp_large_random_bipartite_test" do
    # Generate a random bipartite graph and verify the matching is valid
    left = Enum.map(1..20, fn i -> {:l, i} end)
    right = Enum.map(1..20, fn i -> {:r, i} end)

    edges =
      for l <- left, r <- right, :rand.uniform() < 0.3 do
        {l, r, 1}
      end

    graph =
      Yog.undirected()
      |> Yog.add_nodes_from(left ++ right)
      |> then(fn g ->
        Enum.reduce(edges, g, fn {u, v, w}, acc ->
          Yog.add_edge_ensure(acc, from: u, to: v, with: w)
        end)
      end)

    matching = Matching.hopcroft_karp(graph)

    assert valid_matching?(matching)

    # Verify it's a maximal matching by checking no augmenting path exists
    assert maximal_matching?(graph, matching)
  end

  test "hopcroft_karp_onesided_star_test" do
    # 1 -- 2
    # 1 -- 3
    # 1 -- 4
    # 5 -- 6
    graph = Yog.from_edges(:undirected, [{1, 2, 1}, {1, 3, 1}, {1, 4, 1}, {5, 6, 1}])

    matching = Matching.hopcroft_karp(graph)

    assert valid_matching?(matching)
    assert map_size(matching) == 4
  end

  test "hopcroft_karp_directed_bipartite_test" do
    # Directed bipartite graph: edges from left to right
    graph =
      Yog.from_edges(:directed, [
        {:a1, :b1, 1},
        {:a1, :b2, 1},
        {:a2, :b2, 1}
      ])

    matching = Matching.hopcroft_karp(graph)

    assert valid_matching?(matching)
    assert map_size(matching) == 4
  end

  # Helper: checks that no vertex appears in more than one edge
  defp valid_matching?(matching) do
    edges = unique_edges(matching)
    used_left = Enum.map(edges, fn {u, _v} -> u end)
    used_right = Enum.map(edges, fn {_u, v} -> v end)

    length(Enum.uniq(used_left)) == length(used_left) and
      length(Enum.uniq(used_right)) == length(used_right)
  end

  defp unique_edges(matching) do
    matching
    |> Enum.map(fn {u, v} -> if u <= v, do: {u, v}, else: {v, u} end)
    |> Enum.uniq()
  end

  # Helper: verifies no augmenting path exists (matching is maximal)
  defp maximal_matching?(graph, matching) do
    # Get unmatched nodes on both sides
    all_nodes = Yog.all_nodes(graph)
    matched_nodes = Map.keys(matching) |> MapSet.new()
    unmatched = MapSet.difference(MapSet.new(all_nodes), matched_nodes)

    # Build adjacency
    adj =
      Enum.reduce(all_nodes, %{}, fn u, acc ->
        Map.put(acc, u, Yog.neighbor_ids(graph, u))
      end)

    # Try to find an augmenting path from any unmatched node
    not Enum.any?(unmatched, fn start ->
      find_augmenting_path(start, adj, matching, MapSet.new([start]))
    end)
  end

  defp find_augmenting_path(current, adj, matching, visited) do
    neighbors = Map.get(adj, current, [])

    Enum.reduce_while(neighbors, false, fn v, _acc ->
      if MapSet.member?(visited, v) do
        {:cont, false}
      else
        new_visited = MapSet.put(visited, v)

        case Map.get(matching, v) do
          nil ->
            # Found a free node on the other side -> augmenting path exists
            {:halt, true}

          u when u != current ->
            # v is matched to u, continue the alternating path
            if find_augmenting_path(u, adj, matching, new_visited) do
              {:halt, true}
            else
              {:cont, false}
            end

          _ ->
            {:cont, false}
        end
      end
    end)
  end
end
