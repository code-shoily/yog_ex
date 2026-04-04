defmodule Yog.MultiTest do
  @moduledoc """
  Tests for Yog.Multi facade module.

  These tests verify the unified facade properly delegates to internal modules:
  - Yog.Multi.Model for construction, modification, and query operations
  - Yog.Multi.Traversal for BFS, DFS, and fold_walk operations
  - Yog.Multi.Eulerian for Eulerian path/circuit detection and finding

  Coverage target: 80%+ for facade delegation verification.
  """

  use ExUnit.Case

  doctest Yog.Multi

  alias Yog.Multi

  # =============================================================================
  # Construction - Facade Delegation to Model
  # =============================================================================

  describe "new/1 delegation" do
    test "delegates to Model.new/1 for directed" do
      graph = Multi.new(:directed)

      assert graph.kind == :directed
      assert Multi.order(graph) == 0
      assert Multi.size(graph) == 0
    end

    test "delegates to Model.new/1 for undirected" do
      graph = Multi.new(:undirected)

      assert graph.kind == :undirected
      assert Multi.order(graph) == 0
    end
  end

  describe "directed/0 and undirected/0 convenience constructors" do
    test "directed/0 creates directed multigraph" do
      graph = Multi.directed()
      assert graph.kind == :directed
    end

    test "undirected/0 creates undirected multigraph" do
      graph = Multi.undirected()
      assert graph.kind == :undirected
    end
  end

  # =============================================================================
  # Node Operations - Facade Delegation to Model
  # =============================================================================

  describe "add_node/3 delegation" do
    test "delegates to Model.add_node/3" do
      graph =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")

      assert Multi.order(graph) == 2
      assert 1 in Multi.all_nodes(graph)
      assert 2 in Multi.all_nodes(graph)
    end

    test "node data is stored correctly via facade" do
      graph =
        Multi.directed()
        |> Multi.add_node(:user1, %{name: "Alice", age: 30})
        |> Multi.add_node(:user2, %{name: "Bob", age: 25})

      # Verify through to_simple_graph conversion
      simple = Multi.to_simple_graph(graph, fn a, _b -> a end)
      assert Yog.node(simple, :user1) == %{name: "Alice", age: 30}
    end
  end

  describe "remove_node/2 delegation" do
    test "delegates to Model.remove_node/2" do
      graph =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")

      graph = Multi.remove_node(graph, 1)

      assert Multi.order(graph) == 1
      assert 1 not in Multi.all_nodes(graph)
      assert 2 in Multi.all_nodes(graph)
    end

    test "removing node removes connected edges" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_edge(1, 2, 10)

      graph = Multi.remove_node(graph, 1)

      assert Multi.size(graph) == 0
    end
  end

  describe "all_nodes/1 and order/1 delegation" do
    test "all_nodes/1 delegates to Model.all_nodes/1" do
      graph =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_node(3, "C")

      nodes = Multi.all_nodes(graph)

      assert is_list(nodes)
      assert length(nodes) == 3
      assert Enum.sort(nodes) == [1, 2, 3]
    end

    test "order/1 delegates to Model.order/1" do
      graph = Multi.directed()
      assert Multi.order(graph) == 0

      graph = Multi.add_node(graph, 1, "A")
      assert Multi.order(graph) == 1

      graph = Multi.add_node(graph, 2, "B")
      assert Multi.order(graph) == 2
    end
  end

  # =============================================================================
  # Edge Operations - Facade Delegation to Model
  # =============================================================================

  describe "add_edge/4 delegation" do
    test "delegates to Model.add_edge/4" do
      {graph, edge_id} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_edge(1, 2, 10)

      assert is_integer(edge_id)
      assert Multi.size(graph) == 1
    end

    test "parallel edges supported via facade" do
      {graph, eid1} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_edge(1, 2, 10)

      {graph, eid2} = Multi.add_edge(graph, 1, 2, 20)
      {graph, eid3} = Multi.add_edge(graph, 1, 2, 30)

      assert Multi.size(graph) == 3
      assert eid1 != eid2
      assert eid2 != eid3

      edges = Multi.edges_between(graph, 1, 2)
      assert length(edges) == 3
    end

    test "undirected edges via facade" do
      {graph, eid} =
        Multi.undirected()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_edge(1, 2, 10)

      # In undirected, edge appears in both directions
      assert Multi.size(graph) == 1

      successors = Multi.successors(graph, 1)
      assert Enum.any?(successors, fn {n, id, _} -> n == 2 and id == eid end)

      predecessors = Multi.predecessors(graph, 2)
      assert Enum.any?(predecessors, fn {n, id, _} -> n == 1 and id == eid end)
    end
  end

  describe "remove_edge/2 delegation" do
    test "delegates to Model.remove_edge/2" do
      {graph, edge_id} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_edge(1, 2, 10)

      graph = Multi.remove_edge(graph, edge_id)

      assert Multi.size(graph) == 0
      assert Multi.edges_between(graph, 1, 2) == []
    end

    test "removing specific edge among parallels" do
      {graph, eid1} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_edge(1, 2, 10)

      {graph, eid2} = Multi.add_edge(graph, 1, 2, 20)

      graph = Multi.remove_edge(graph, eid1)

      # Second edge should remain
      assert Multi.size(graph) == 1
      edges = Multi.edges_between(graph, 1, 2)
      assert [{^eid2, 20}] = edges
    end
  end

  describe "all_edge_ids/1 and size/1 delegation" do
    test "all_edge_ids/1 delegates to Model.all_edge_ids/1" do
      {graph, eid1} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_edge(1, 2, 10)

      {graph, eid2} = Multi.add_edge(graph, 2, 1, 20)

      edge_ids = Multi.all_edge_ids(graph)

      assert is_list(edge_ids)
      assert length(edge_ids) == 2
      assert eid1 in edge_ids
      assert eid2 in edge_ids
    end

    test "size/1 delegates to Model.size/1" do
      graph = Multi.directed() |> Multi.add_node(1, "A") |> Multi.add_node(2, "B")
      assert Multi.size(graph) == 0

      {graph, _} = Multi.add_edge(graph, 1, 2, 10)
      assert Multi.size(graph) == 1

      {graph, _} = Multi.add_edge(graph, 1, 2, 20)
      assert Multi.size(graph) == 2
    end
  end

  describe "edges_between/3 delegation" do
    test "delegates to Model.edges_between/3" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_edge(1, 2, 10)

      {graph, _} = Multi.add_edge(graph, 1, 2, 20)
      {graph, _} = Multi.add_edge(graph, 2, 1, 30)

      edges_1_2 = Multi.edges_between(graph, 1, 2)
      assert length(edges_1_2) == 2

      edges_2_1 = Multi.edges_between(graph, 2, 1)
      assert length(edges_2_1) == 1
    end
  end

  describe "successors/2 and predecessors/2 delegation" do
    test "successors/2 delegates to Model.successors/2" do
      {graph, eid} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_node(3, "C")
        |> Multi.add_edge(1, 2, 10)

      {graph, _} = Multi.add_edge(graph, 1, 3, 20)

      successors = Multi.successors(graph, 1)

      assert length(successors) == 2
      assert {2, ^eid, 10} = Enum.find(successors, fn {n, _, _} -> n == 2 end)
    end

    test "predecessors/2 delegates to Model.predecessors/2" do
      {graph, eid} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_node(3, "C")
        |> Multi.add_edge(1, 2, 10)

      {graph, _} = Multi.add_edge(graph, 3, 2, 20)

      predecessors = Multi.predecessors(graph, 2)

      assert length(predecessors) == 2
      assert {1, ^eid, 10} = Enum.find(predecessors, fn {n, _, _} -> n == 1 end)
    end
  end

  describe "out_degree/2 and in_degree/2 delegation" do
    test "out_degree/2 delegates to Model.out_degree/2" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_node(3, "C")
        |> Multi.add_edge(1, 2, 10)

      {graph, _} = Multi.add_edge(graph, 1, 3, 20)
      # Parallel edge
      {graph, _} = Multi.add_edge(graph, 1, 2, 30)

      assert Multi.out_degree(graph, 1) == 3
      assert Multi.out_degree(graph, 2) == 0
    end

    test "in_degree/2 delegates to Model.in_degree/2" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_node(3, "C")
        |> Multi.add_edge(1, 2, 10)

      {graph, _} = Multi.add_edge(graph, 3, 2, 20)
      # Parallel edge
      {graph, _} = Multi.add_edge(graph, 1, 2, 30)

      assert Multi.in_degree(graph, 2) == 3
      assert Multi.in_degree(graph, 1) == 0
    end
  end

  # =============================================================================
  # Traversal - Facade Delegation to Traversal
  # =============================================================================

  describe "bfs/2 delegation" do
    test "delegates to Traversal.bfs/2" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_node(:c, nil)
        |> Multi.add_node(:d, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, _} = Multi.add_edge(graph, :a, :c, 2)
      {graph, _} = Multi.add_edge(graph, :b, :d, 3)

      result = Multi.bfs(graph, :a)

      assert is_list(result)
      assert hd(result) == :a
      assert :b in result
      assert :c in result
      assert :d in result
    end

    test "BFS handles parallel edges correctly" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_edge(:a, :b, 1)

      # Parallel
      {graph, _} = Multi.add_edge(graph, :a, :b, 2)

      result = Multi.bfs(graph, :a)

      assert result == [:a, :b]
    end
  end

  describe "dfs/2 delegation" do
    test "delegates to Traversal.dfs/2" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_node(:c, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, _} = Multi.add_edge(graph, :b, :c, 2)

      result = Multi.dfs(graph, :a)

      assert is_list(result)
      assert hd(result) == :a
      assert :b in result
      assert :c in result
    end
  end

  describe "fold_walk/4 delegation" do
    test "delegates to Traversal.fold_walk/4" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_node(:c, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, _} = Multi.add_edge(graph, :b, :c, 2)

      result =
        Multi.fold_walk(graph, :a, [], fn acc, node, meta ->
          {:continue, [{node, meta.depth} | acc]}
        end)

      assert is_list(result)
      assert {:a, 0} in result
      assert {:b, 1} in result
      assert {:c, 2} in result
    end

    test "fold_walk respects :halt control" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_node(:c, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, _} = Multi.add_edge(graph, :b, :c, 2)

      result =
        Multi.fold_walk(graph, :a, [], fn acc, node, _meta ->
          if node == :b do
            {:halt, acc}
          else
            {:continue, [node | acc]}
          end
        end)

      # Should halt before reaching c
      assert :a in result
      refute :c in result
    end

    test "fold_walk provides edge metadata" do
      {graph, eid} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_edge(:a, :b, 10)

      result =
        Multi.fold_walk(graph, :a, %{}, fn acc, node, meta ->
          new_acc =
            case meta.parent do
              {parent, edge_id} -> Map.put(acc, node, {parent, edge_id})
              nil -> Map.put(acc, node, :root)
            end

          {:continue, new_acc}
        end)

      assert result[:a] == :root
      assert result[:b] == {:a, eid}
    end
  end

  # =============================================================================
  # Eulerian - Facade Delegation to Eulerian
  # =============================================================================

  describe "has_eulerian_circuit?/1 delegation" do
    test "delegates to Eulerian.has_eulerian_circuit?/1 - cycle" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_node(:c, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, _} = Multi.add_edge(graph, :b, :c, 2)
      {graph, _} = Multi.add_edge(graph, :c, :a, 3)

      assert Multi.has_eulerian_circuit?(graph)
    end

    test "delegates to Eulerian - no circuit for path" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_edge(:a, :b, 1)

      refute Multi.has_eulerian_circuit?(graph)
    end

    test "delegates to Eulerian - empty graph" do
      graph = Multi.directed()
      refute Multi.has_eulerian_circuit?(graph)
    end

    test "undirected Eulerian circuit detection" do
      # Square with diagonal (all even degrees)
      {graph, _} =
        Multi.undirected()
        |> Multi.add_node(1, nil)
        |> Multi.add_node(2, nil)
        |> Multi.add_node(3, nil)
        |> Multi.add_node(4, nil)
        |> Multi.add_edge(1, 2, 1)

      {graph, _} = Multi.add_edge(graph, 2, 3, 1)
      {graph, _} = Multi.add_edge(graph, 3, 4, 1)
      {graph, _} = Multi.add_edge(graph, 4, 1, 1)

      assert Multi.has_eulerian_circuit?(graph)
    end
  end

  describe "has_eulerian_path?/1 delegation" do
    test "delegates to Eulerian.has_eulerian_path?/1 - path" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_node(:c, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, _} = Multi.add_edge(graph, :b, :c, 2)

      assert Multi.has_eulerian_path?(graph)
    end

    test "circuit is also a valid path" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_node(:c, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, _} = Multi.add_edge(graph, :b, :c, 2)
      {graph, _} = Multi.add_edge(graph, :c, :a, 3)

      assert Multi.has_eulerian_path?(graph)
    end

    test "no path for disconnected components" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_node(:c, nil)
        |> Multi.add_node(:d, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, _} = Multi.add_edge(graph, :c, :d, 2)

      refute Multi.has_eulerian_path?(graph)
    end
  end

  describe "find_eulerian_circuit/1 delegation" do
    test "delegates to Eulerian.find_eulerian_circuit/1" do
      {graph, eid1} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_node(:c, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, eid2} = Multi.add_edge(graph, :b, :c, 2)
      {graph, eid3} = Multi.add_edge(graph, :c, :a, 3)

      {:ok, circuit} = Multi.find_eulerian_circuit(graph)

      assert is_list(circuit)
      assert length(circuit) == 3
      assert eid1 in circuit
      assert eid2 in circuit
      assert eid3 in circuit
    end

    test "returns :error when no circuit exists" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_edge(:a, :b, 1)

      assert :error = Multi.find_eulerian_circuit(graph)
    end

    test "handles parallel edges in circuit" do
      {graph, eid1} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, eid2} = Multi.add_edge(graph, :b, :a, 2)

      {:ok, circuit} = Multi.find_eulerian_circuit(graph)

      assert length(circuit) == 2
      assert eid1 in circuit
      assert eid2 in circuit
    end
  end

  describe "find_eulerian_path/1 delegation" do
    test "delegates to Eulerian.find_eulerian_path/1" do
      {graph, eid1} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_node(:c, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, eid2} = Multi.add_edge(graph, :b, :c, 2)

      {:ok, path} = Multi.find_eulerian_path(graph)

      assert is_list(path)
      assert length(path) == 2
      assert eid1 in path
      assert eid2 in path
    end

    test "returns :error when no path exists" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(:a, nil)
        |> Multi.add_node(:b, nil)
        |> Multi.add_node(:c, nil)
        |> Multi.add_node(:d, nil)
        |> Multi.add_edge(:a, :b, 1)

      {graph, _} = Multi.add_edge(graph, :c, :d, 2)

      assert :error = Multi.find_eulerian_path(graph)
    end
  end

  # =============================================================================
  # Conversion - Facade Delegation to Model
  # =============================================================================

  describe "to_simple_graph/2 delegation" do
    test "delegates to Model.to_simple_graph/2" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_edge(1, 2, 10)

      # Parallel
      {graph, _} = Multi.add_edge(graph, 1, 2, 20)

      simple = Multi.to_simple_graph(graph, fn a, b -> min(a, b) end)

      assert is_struct(simple, Yog.Graph)
      assert simple.kind == :directed
      assert Yog.Model.has_edge?(simple, 1, 2)
      # min(10, 20) = 10
      assert Yog.Model.edge_data(simple, 1, 2) == 10
    end

    test "combines parallel edges with sum" do
      {graph, _} =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_edge(1, 2, 10)

      {graph, _} = Multi.add_edge(graph, 1, 2, 20)
      {graph, _} = Multi.add_edge(graph, 1, 2, 30)

      simple = Multi.to_simple_graph(graph, fn a, b -> a + b end)

      # 10 + 20 + 30 = 60
      assert Yog.Model.edge_data(simple, 1, 2) == 60
    end

    test "preserves nodes in conversion" do
      graph =
        Multi.directed()
        |> Multi.add_node(1, "A")
        |> Multi.add_node(2, "B")
        |> Multi.add_node(3, "C")

      simple = Multi.to_simple_graph(graph, fn a, _ -> a end)

      assert Yog.Model.node_count(simple) == 3
      assert Yog.node(simple, 1) == "A"
      assert Yog.node(simple, 2) == "B"
    end
  end

  # =============================================================================
  # Integration Tests
  # =============================================================================

  describe "integration tests" do
    test "full multigraph lifecycle via facade" do
      # Create multigraph
      graph = Multi.undirected()

      # Add nodes
      graph =
        graph
        |> Multi.add_node(:station_a, %{name: "Central"})
        |> Multi.add_node(:station_b, %{name: "North"})
        |> Multi.add_node(:station_c, %{name: "South"})

      assert Multi.order(graph) == 3

      # Add parallel edges (multiple routes)
      {graph, route1} = Multi.add_edge(graph, :station_a, :station_b, %{distance: 10, time: 20})
      {graph, _route2} = Multi.add_edge(graph, :station_a, :station_b, %{distance: 15, time: 15})
      {graph, _route3} = Multi.add_edge(graph, :station_b, :station_c, %{distance: 8, time: 12})

      assert Multi.size(graph) == 3

      # Query parallel edges
      routes = Multi.edges_between(graph, :station_a, :station_b)
      assert length(routes) == 2

      # Traverse
      visited = Multi.bfs(graph, :station_a)
      assert :station_a in visited
      assert :station_b in visited
      assert :station_c in visited

      # Remove specific route
      graph = Multi.remove_edge(graph, route1)
      assert Multi.size(graph) == 2

      # Convert to simple graph (keep fastest route)
      simple =
        Multi.to_simple_graph(graph, fn a, b ->
          if a.time <= b.time, do: a, else: b
        end)

      assert Yog.Model.has_edge?(simple, :station_a, :station_b)
    end

    test "Eulerian circuit in multigraph via facade" do
      # Create a multigraph with Eulerian circuit
      {graph, _} =
        Multi.undirected()
        |> Multi.add_node(1, nil)
        |> Multi.add_node(2, nil)
        |> Multi.add_node(3, nil)
        |> Multi.add_node(4, nil)
        |> Multi.add_edge(1, 2, 1)

      {graph, _} = Multi.add_edge(graph, 2, 3, 1)
      {graph, _} = Multi.add_edge(graph, 3, 4, 1)
      {graph, _} = Multi.add_edge(graph, 4, 1, 1)

      assert Multi.has_eulerian_circuit?(graph)

      {:ok, circuit} = Multi.find_eulerian_circuit(graph)
      assert length(circuit) == 4
    end
  end
end
