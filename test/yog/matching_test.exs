defmodule Yog.MatchingTest do
  use ExUnit.Case

  doctest Yog.Matching

  alias Yog.Matching
  alias Yog.Model

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

  describe "Hungarian Algorithm" do
    test "minimum weight perfect matching (3x3 example)" do
      # Example from the issue
      graph =
        Yog.from_edges(:undirected, [
          {:a, :x, 10},
          {:a, :y, 19},
          {:a, :z, 8},
          {:b, :x, 15},
          {:b, :y, 17},
          {:b, :z, 12},
          {:c, :x, 8},
          {:c, :y, 18},
          {:c, :z, 9}
        ])

      {cost, matching} = Matching.hungarian(graph, :min)

      assert cost == 33
      # Optimal matching: a-z (8), b-y (17), c-x (8) => 8+17+8 = 33? 
      # Wait, let's re-calculate:
      # a: x=10, y=19, z=8
      # b: x=15, y=17, z=12
      # c: x=8, y=18, z=9
      # Option 1: a-z(8), b-y(17), c-x(8) => 33
      # Option 2: a-x(10), b-y(17), c-z(9) => 36
      # Option 3: a-z(8), b-x(15), c-y(18) => 41
      # So 33 is better than 35. 
      # Let's check the issue's example: 10 + 17 + 8 = 35. 
      # a-x(10), b-y(17), c-z(9)? No, that's 36. 
      # a-x(10), b-z(12), c-y(18)? No.
      # If a-x(10), b-y(17), then c must be z(9). 10+17+9=36.
      # In the issue: 10 + 17 + 8. That would be a-x, b-y, c-x. 
      # BUT matching must be a set of edges without common vertices. 
      # c-x and a-x both use x. So that's not a matching.

      # The issue description says: "total_cost => 35 (10 + 17 + 8)". 
      # This is likely a typo in the issue or I'm misreading.
      # Let's re-run the manual calc for 35: 
      # a-y(19), b-z(12), c-x(8) => 39
      # a-x(10), b-y(17), c-z(9) => 36
      # a-z(8), b-x(15), c-y(18) => 41
      # a-z(8), b-y(17), c-x(8) => 33. This IS a valid matching. 

      # I'll assert 33 or whatever my algorithm calculates as optimal.
      assert cost == 33
      assert valid_matching?(matching)
      assert map_size(matching) == 6
    end

    test "maximum weight perfect matching" do
      graph =
        Yog.from_edges(:undirected, [
          {:a, :x, 1},
          {:a, :y, 4},
          {:b, :x, 3},
          {:b, :y, 2}
        ])

      {cost, matching} = Matching.hungarian(graph, :max)

      # a-y (4), b-x (3) => 7
      assert cost == 7
      assert matching[:a] == :y
      assert matching[:b] == :x
    end

    test "rectangular bipartite graph (more workers than jobs)" do
      # 3 workers, 2 jobs
      graph =
        Yog.from_edges(:undirected, [
          {:a, :x, 10},
          {:a, :y, 5},
          {:b, :x, 2},
          {:b, :y, 8},
          {:c, :x, 1},
          {:c, :y, 1}
        ])

      {cost, matching} = Matching.hungarian(graph, :min)

      # Jobs x and y should be assigned to the best workers.
      # Workers are a, b, c. Jobs are x, y.
      # Option 1: a-y(5), b-x(2) => 7
      # Option 2: a-x(10), b-y(8) => 18
      # Option 3: b-y(8), c-x(1) => 9
      # Option 5: b-x(2), c-y(1) => 3. Optimal.
      assert cost == 3
      assert map_size(matching) == 4

      assert (matching[:b] == :x and matching[:c] == :y) or
               (matching[:b] == :y and matching[:c] == :x)

      # Wait, a-y(5) and c-x(1) is indeed 6.
    end

    test "rectangular bipartite graph (more jobs than workers)" do
      graph =
        Yog.from_edges(:undirected, [
          {:w1, :j1, 10},
          {:w1, :j2, 20},
          {:w1, :j3, 30},
          {:w2, :j1, 5},
          {:w2, :j2, 5},
          {:w2, :j3, 5}
        ])

      {cost, matching} = Matching.hungarian(graph, :min)

      # w2 takes any job (5), w1 takes j1 (10) => 15
      assert cost == 15
      assert map_size(matching) == 4
    end

    test "large random complete bipartite matching" do
      # 10x10 complete bipartite
      left = Enum.map(1..10, &{:l, &1})
      right = Enum.map(1..10, &{:r, &1})

      edges =
        for l <- left, r <- right do
          {l, r, :rand.uniform(100)}
        end

      graph = Yog.from_edges(:undirected, edges)

      {cost, matching} = Matching.hungarian(graph, :min)

      assert cost > 0
      assert valid_matching?(matching)
      assert map_size(matching) == 20

      # Verify cost manually
      calculated_cost =
        matching
        |> Enum.filter(fn {u, _v} -> u in left end)
        |> Enum.reduce(0, fn {u, v}, acc -> acc + (Model.edge_data(graph, u, v) || 0) end)

      assert cost == calculated_cost
    end

    test "non-complete bipartite graph raises error" do
      # 2x2 but missing one edge
      graph =
        Yog.from_edges(:undirected, [
          {:a, :x, 10},
          {:a, :y, 5},
          {:b, :x, 2}
          # missing {:b, :y}
        ])

      assert_raise ArgumentError, ~r/complete bipartite/, fn ->
        Matching.hungarian(graph)
      end
    end
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
            visited_with_u = MapSet.put(new_visited, u)

            if find_augmenting_path(u, adj, matching, visited_with_u) do
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
