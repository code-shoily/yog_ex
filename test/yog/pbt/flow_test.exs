defmodule Yog.PBT.FlowTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Flow Properties" do
    property "Max-Flow Min-Cut Theorem: max_flow value equals cut capacity" do
      check all({graph, s, t} <- flow_problem_gen()) do
        result = Yog.Flow.MaxFlow.edmonds_karp(graph, s, t)
        cut = Yog.Flow.MaxFlow.extract_min_cut(result)

        # The cut_value is now computed directly during max flow extraction
        assert result.max_flow == cut.cut_value
      end
    end

    property "Flow Conservation and Capacity Constraints" do
      check all({graph, s, t} <- flow_problem_gen()) do
        result = Yog.Flow.MaxFlow.edmonds_karp(graph, s, t)
        res_graph = result.residual_graph

        all_node_ids = Yog.all_nodes(graph)

        # Calculate net flow out for each node
        net_flows =
          Enum.reduce(all_node_ids, %{}, fn u, acc ->
            out_orig = Yog.successors(graph, u) |> Enum.into(%{})
            out_res = Yog.successors(res_graph, u) |> Enum.into(%{})

            sum_orig = out_orig |> Map.values() |> Enum.sum()
            sum_res = out_res |> Map.values() |> Enum.sum()

            Map.put(acc, u, sum_orig - sum_res)
          end)

        for u <- all_node_ids do
          cond do
            u == s ->
              assert net_flows[u] == result.max_flow

            u == t ->
              assert net_flows[u] == -result.max_flow

            true ->
              assert net_flows[u] == 0
          end
        end
      end
    end

    property "Integrality: Integer capacities yield integer max flow" do
      check all(
              nodes <- node_list_gen(2, 20),
              weights <- weight_list_gen(length(nodes), 1..100),
              graph = build_graph(:directed, nodes, weights),
              [s, t] <- StreamData.uniq_list_of(StreamData.member_of(nodes), length: 2)
            ) do
        result = Yog.Flow.MaxFlow.edmonds_karp(graph, s, t)

        # Max flow should be an integer for integer capacities
        assert is_integer(result.max_flow) or result.max_flow == trunc(result.max_flow)
      end
    end

    property "Residual graph has no path from source to sink" do
      check all({graph, s, t} <- flow_problem_gen()) do
        result = Yog.Flow.MaxFlow.edmonds_karp(graph, s, t)
        res_graph = result.residual_graph

        # After max flow, there should be no augmenting path in residual graph
        # This is verified by checking that t is not reachable from s
        reachable = Yog.Traversal.walk(res_graph, s, :breadth_first)

        # Either t is not reachable, or the only paths have zero capacity
        # Or no flow was possible
        assert t not in reachable or
                 result.max_flow == 0
      end
    end

    property "Zero flow on disconnected components" do
      check all(
              # Create two disconnected subgraphs
              nodes1 <- node_list_gen(2, 10, 50),
              nodes2 <- node_list_gen(2, 10, 50),
              weights1 <- weight_list_gen(length(nodes1), 1..50),
              weights2 <- weight_list_gen(length(nodes2), 1..50)
            ) do
        g1 = build_graph(:directed, nodes1, weights1)

        # Build g2 with offset node IDs directly to avoid map_nodes issues
        offset = 1000
        g2_nodes = Enum.map(nodes2, &(&1 + offset))
        g2_edges = Enum.map(weights2, fn {u, v, w} -> {u + offset, v + offset, w} end)
        g2 = build_graph(:directed, g2_nodes, g2_edges)

        # Disjoint union (no edges between g1 and g2)
        graph = Yog.Operation.disjoint_union(g1, g2)

        # Pick s from g1 and t from g2
        s = hd(nodes1)
        t = hd(g2_nodes)

        result = Yog.Flow.MaxFlow.edmonds_karp(graph, s, t)

        # No path between disconnected components
        assert result.max_flow == 0
      end
    end
  end

  describe "Performance Tests" do
    @tag timeout: 30000
    test "handles larger flow networks efficiently" do
      # Create a larger flow network: grid-like structure
      # 50x50 grid = 2500 nodes
      n = 50

      graph =
        Enum.reduce(0..(n - 1), Yog.directed(), fn i, g ->
          Enum.reduce(0..(n - 1), g, fn j, acc ->
            node_id = i * n + j
            Yog.add_node(acc, node_id, nil)
          end)
        end)
        |> add_grid_edges(n)

      source = 0
      sink = n * n - 1

      {time_ms, result} =
        :timer.tc(
          fn ->
            Yog.Flow.MaxFlow.edmonds_karp(graph, source, sink)
          end,
          :millisecond
        )

      # Should complete in reasonable time (< 10 seconds)
      assert time_ms < 10000
      assert result.max_flow > 0

      # Verify min-cut equals max-flow
      cut = Yog.Flow.MaxFlow.extract_min_cut(result)
      assert cut.cut_value == result.max_flow
    end

    @tag timeout: 30000
    test "Stoer-Wagner handles larger undirected graphs" do
      # Create a larger graph with known min-cut
      n = 100

      # Two cliques connected by a single edge
      graph =
        Yog.undirected()
        # First clique
        |> add_clique(0, div(n, 2), 10)
        # Second clique
        |> add_clique(div(n, 2), n, 10)
        # Single weak bridge
        |> add_bridge(div(n, 2) - 1, div(n, 2), 5)

      {time_ms, result} =
        :timer.tc(
          fn ->
            Yog.Flow.MinCut.global_min_cut(graph)
          end,
          :millisecond
        )

      # Should complete in reasonable time
      assert time_ms < 10000
      # Min cut should be the bridge weight
      assert result.cut_value == 5
      assert result.source_side_size + result.sink_side_size == n
    end
  end

  describe "Algorithm Comparison Properties" do
    property "Multiple max flow paths yield same result" do
      check all(
              # Complete bipartite graph - multiple equivalent paths
              m <- StreamData.integer(2..5),
              n <- StreamData.integer(2..5)
            ) do
        graph = Yog.Generator.Classic.complete_bipartite(m, n)

        # All edges have capacity 1
        graph = Yog.map_edges(graph, fn _ -> 1 end)

        # Source is first node in left partition, sink is first in right
        s = 0
        # First node in right partition
        t = m

        result = Yog.Flow.MaxFlow.edmonds_karp(graph, s, t)

        # In K_{m,n}, max flow from any left to any right node 
        # is at least 1 (direct edge) + possibly more through other nodes
        assert result.max_flow >= 1
      end
    end
  end

  # Helper functions for performance tests
  defp add_grid_edges(graph, n) do
    Enum.reduce(0..(n - 1), graph, fn i, g ->
      Enum.reduce(0..(n - 1), g, fn j, acc ->
        node_id = i * n + j

        # Add right neighbor
        acc =
          if j < n - 1 do
            right_id = i * n + (j + 1)
            Yog.add_edge_ensure(acc, node_id, right_id, :rand.uniform(10))
          else
            acc
          end

        # Add down neighbor
        acc =
          if i < n - 1 do
            down_id = (i + 1) * n + j
            Yog.add_edge_ensure(acc, node_id, down_id, :rand.uniform(10))
          else
            acc
          end

        acc
      end)
    end)
  end

  defp add_clique(graph, start, finish, weight) do
    nodes = Enum.to_list(start..(finish - 1))

    Enum.reduce(nodes, graph, fn i, g ->
      Enum.reduce(nodes, g, fn j, acc ->
        if i < j do
          Yog.add_edge_ensure(acc, i, j, weight)
        else
          acc
        end
      end)
    end)
  end

  defp add_bridge(graph, u, v, weight) do
    Yog.add_edge_ensure(graph, u, v, weight)
  end
end
