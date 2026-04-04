defmodule Yog.PBT.TraversalTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Traversal Properties" do
    property "BFS visits each reachable node exactly once" do
      check all(
              graph <- graph_gen(),
              nodes = Yog.all_nodes(graph),
              nodes != [],
              start_node <- StreamData.member_of(nodes)
            ) do
        visited =
          Yog.Traversal.fold_walk(
            over: graph,
            from: start_node,
            using: :breadth_first,
            initial: [],
            with: fn acc, node, _metadata ->
              {:continue, [node | acc]}
            end
          )

        assert length(visited) == length(Enum.uniq(visited))
      end
    end

    property "DFS visits same reachable nodes as BFS" do
      check all(
              graph <- graph_gen(),
              nodes = Yog.all_nodes(graph),
              nodes != [],
              start_node <- StreamData.member_of(nodes)
            ) do
        bfs_visited = Yog.Traversal.walk(graph, start_node, :breadth_first) |> Enum.sort()
        dfs_visited = Yog.Traversal.walk(graph, start_node, :depth_first) |> Enum.sort()

        assert bfs_visited == dfs_visited
      end
    end

    property "find_path retrieves a historically accurate path segment" do
      check all(
              graph <- graph_gen(),
              nodes = Yog.all_nodes(graph),
              nodes != [],
              start_node <- StreamData.member_of(nodes),
              target_node <- StreamData.member_of(nodes)
            ) do
        path = Yog.Traversal.find_path(graph, start_node, target_node)

        reachable_nodes = Yog.Traversal.walk(graph, start_node, :breadth_first) |> MapSet.new()
        is_reachable = MapSet.member?(reachable_nodes, target_node)

        if is_reachable do
          assert path != nil
          assert hd(path) == start_node
          assert List.last(path) == target_node

          # Check connectivity explicitly
          path
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.each(fn [u, v] ->
            assert Yog.Model.has_edge?(graph, u, v)
          end)
        else
          assert path == nil
        end
      end
    end

    property "Implicit DFS visits correlate strictly with Explicit Graph structure" do
      check all(
              graph <- graph_gen(),
              nodes = Yog.all_nodes(graph),
              nodes != [],
              start_node <- StreamData.member_of(nodes)
            ) do
        dfs_visited = Yog.Traversal.walk(graph, start_node, :depth_first) |> Enum.sort()

        implicit_dfs_visited =
          Yog.Traversal.implicit_fold(
            from: start_node,
            using: :depth_first,
            initial: [],
            successors_of: fn id -> Yog.Model.successor_ids(graph, id) end,
            with: fn acc, node, _ -> {:continue, [node | acc]} end
          )
          |> Enum.sort()

        assert dfs_visited == implicit_dfs_visited
      end
    end

    property "Topological operations invariant holds for directed graphs" do
      check all(graph <- graph_gen()) do
        is_cyclic = Yog.Property.Cyclicity.cyclic?(graph)
        is_acyclic = Yog.Property.Cyclicity.acyclic?(graph)

        assert is_cyclic == not is_acyclic

        if Yog.Model.type(graph) == :directed do
          sort_res = Yog.Traversal.topological_sort(graph)

          if is_cyclic do
            assert sort_res == {:error, :contains_cycle}
          else
            assert {:ok, sorted_nodes} = sort_res
            assert Enum.sort(sorted_nodes) == Enum.sort(Yog.all_nodes(graph))

            # The strictly guaranteed invariant constraint
            sorted_idx = sorted_nodes |> Enum.with_index() |> Map.new()

            for {u, v, _w} <- Yog.Model.all_edges(graph) do
              assert Map.fetch!(sorted_idx, u) < Map.fetch!(sorted_idx, v)
            end
          end
        end
      end
    end

    property "Topological Sort: Order preserves dependencies in a DAG" do
      check all(graph <- directed_graph_gen()) do
        case Yog.Traversal.topological_sort(graph) do
          {:ok, sorted_nodes} ->
            pos_map = Enum.with_index(sorted_nodes) |> Enum.into(%{})

            edges = Yog.all_edges(graph)

            for {u, v, _} <- edges do
              if u != v do
                assert pos_map[u] < pos_map[v]
              end
            end

          {:error, _} ->
            assert Yog.cyclic?(graph)
        end
      end
    end
  end
end
