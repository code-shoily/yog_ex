defmodule Yog.DAGTest do
  @moduledoc """
  Tests for Yog.DAG facade module.

  These tests verify the unified facade properly delegates to:
  - Yog.DAG.Model for construction and modification operations
  - Yog.DAG.Algorithm for algorithmic operations

  Coverage target: 80%+ for facade delegation verification.
  """

  use ExUnit.Case

  doctest Yog.DAG

  alias Yog.DAG
  # =============================================================================
  # Construction Tests - Verify proper graph validation
  # =============================================================================

  describe "construction" do
    test "new/0 creates empty DAG" do
      dag = DAG.new()
      assert %Yog.DAG{} = dag

      graph = DAG.to_graph(dag)
      assert graph.kind == :directed
      assert Yog.Model.node_count(graph) == 0
    end

    test "from_graph/1 creates DAG from acyclic directed graph" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(1, 2, 10)

      assert {:ok, dag} = DAG.from_graph(graph)
      assert %Yog.DAG{} = dag
    end

    test "from_graph/1 rejects undirected graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")

      assert {:error, :cycle_detected} = DAG.from_graph(graph)
    end

    test "from_graph/1 rejects cyclic directed graph" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(1, 2, 10)
        |> Yog.add_edge_ensure(2, 1, 10)

      assert {:error, :cycle_detected} = DAG.from_graph(graph)
    end

    test "to_graph/1 unwraps DAG to regular graph" do
      dag = DAG.new()
      graph = DAG.to_graph(dag)

      assert is_struct(graph, Yog.Graph)
      assert graph.kind == :directed
    end
  end

  # =============================================================================
  # Facade Delegation Tests - Model Operations
  # =============================================================================

  describe "add_node/3 delegation" do
    test "delegates to Model.add_node/3" do
      dag =
        DAG.new()
        |> DAG.add_node(1, "A")
        |> DAG.add_node(2, "B")

      graph = DAG.to_graph(dag)
      nodes = Yog.all_nodes(graph)

      assert length(nodes) == 2
      assert 1 in nodes
      assert 2 in nodes
      assert Yog.node(graph, 1) == "A"
    end

    test "chaining add_node calls" do
      dag =
        DAG.new()
        |> DAG.add_node(:a, %{value: 1})
        |> DAG.add_node(:b, %{value: 2})
        |> DAG.add_node(:c, %{value: 3})

      graph = DAG.to_graph(dag)
      assert Yog.Model.node_count(graph) == 3
    end
  end

  describe "remove_node/2 delegation" do
    test "delegates to Model.remove_node/2" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(1, 2, 10)
        |> DAG.from_graph()

      dag = DAG.remove_node(dag, 2)
      graph = DAG.to_graph(dag)

      assert Yog.Model.node_count(graph) == 1
      assert Yog.all_nodes(graph) == [1]
    end

    test "removing node removes connected edges" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edge_ensure(1, 2, 10)
        |> Yog.add_edge_ensure(2, 3, 20)
        |> DAG.from_graph()

      dag = DAG.remove_node(dag, 2)
      graph = DAG.to_graph(dag)

      assert Yog.successors(graph, 1) == []
      assert Yog.predecessors(graph, 3) == []
    end
  end

  describe "add_edge/4 delegation" do
    test "delegates to Model.add_edge/4" do
      dag =
        DAG.new()
        |> DAG.add_node(1, "A")
        |> DAG.add_node(2, "B")

      assert {:ok, dag2} = DAG.add_edge(dag, 1, 2, 10)
      graph = DAG.to_graph(dag2)

      assert Yog.successors(graph, 1) == [{2, 10}]
    end

    test "detects cycles via Model validation" do
      dag =
        DAG.new()
        |> DAG.add_node(1, "A")
        |> DAG.add_node(2, "B")
        |> DAG.add_node(3, "C")

      {:ok, dag} = DAG.add_edge(dag, 1, 2, 1)
      {:ok, dag} = DAG.add_edge(dag, 2, 3, 2)

      # Adding 3->1 would create a cycle: 1->2->3->1
      assert {:error, :cycle_detected} = DAG.add_edge(dag, 3, 1, 3)
    end

    test "self-loop detection" do
      dag =
        DAG.new()
        |> DAG.add_node(1, "A")

      assert {:error, :cycle_detected} = DAG.add_edge(dag, 1, 1, 10)
    end

    test "complex DAG construction with edge validation" do
      dag =
        DAG.new()
        |> DAG.add_node(:a, "A")
        |> DAG.add_node(:b, "B")
        |> DAG.add_node(:c, "C")
        |> DAG.add_node(:d, "D")

      # Build diamond: a -> b, a -> c, b -> d, c -> d
      {:ok, dag} = DAG.add_edge(dag, :a, :b, 1)
      {:ok, dag} = DAG.add_edge(dag, :a, :c, 2)
      {:ok, dag} = DAG.add_edge(dag, :b, :d, 3)
      {:ok, dag} = DAG.add_edge(dag, :c, :d, 4)

      graph = DAG.to_graph(dag)

      assert length(Yog.successors(graph, :a)) == 2
      assert length(Yog.predecessors(graph, :d)) == 2
    end
  end

  describe "remove_edge/3 delegation" do
    test "delegates to Model.remove_edge/3" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(1, 2, 10)
        |> DAG.from_graph()

      dag = DAG.remove_edge(dag, 1, 2)
      graph = DAG.to_graph(dag)

      assert Yog.successors(graph, 1) == []
    end

    test "removing non-existent edge is safe" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> DAG.from_graph()

      # Should not raise
      dag = DAG.remove_edge(dag, 1, 2)
      graph = DAG.to_graph(dag)

      assert Yog.Model.node_count(graph) == 2
    end
  end

  # =============================================================================
  # Facade Delegation Tests - Algorithm Operations
  # =============================================================================

  describe "topological_sort/1 delegation" do
    test "delegates to Algorithm.topological_sort/1" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)
        |> Yog.add_node(3, nil)
        |> Yog.add_edge_ensure(1, 2, 1)
        |> Yog.add_edge_ensure(2, 3, 1)
        |> DAG.from_graph()

      sorted = DAG.topological_sort(dag)

      assert sorted == [1, 2, 3]
    end

    test "topological sort on complex DAG" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(:a, nil)
        |> Yog.add_node(:b, nil)
        |> Yog.add_node(:c, nil)
        |> Yog.add_node(:d, nil)
        |> Yog.add_edge_ensure(:a, :b, 1)
        |> Yog.add_edge_ensure(:a, :c, 1)
        |> Yog.add_edge_ensure(:b, :d, 1)
        |> Yog.add_edge_ensure(:c, :d, 1)
        |> DAG.from_graph()

      sorted = DAG.topological_sort(dag)

      # :a must be first, :d must be last
      assert hd(sorted) == :a
      assert List.last(sorted) == :d
    end

    test "empty DAG returns empty sort" do
      dag = DAG.new()
      assert DAG.topological_sort(dag) == []
    end

    test "single node DAG returns single element" do
      dag = DAG.new() |> DAG.add_node(:a, nil)
      assert DAG.topological_sort(dag) == [:a]
    end
  end

  describe "longest_path/1 delegation" do
    test "delegates to Algorithm.longest_path/1" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(:a, nil)
        |> Yog.add_node(:b, nil)
        |> Yog.add_node(:c, nil)
        |> Yog.add_edge_ensure(:a, :b, 1)
        |> Yog.add_edge_ensure(:b, :c, 2)
        |> DAG.from_graph()

      path = DAG.longest_path(dag)

      assert path == [:a, :b, :c]
    end

    test "longest path in weighted DAG" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(:a, nil)
        |> Yog.add_node(:b, nil)
        |> Yog.add_node(:c, nil)
        |> Yog.add_node(:d, nil)
        |> Yog.add_edge_ensure(:a, :b, 1)
        |> Yog.add_edge_ensure(:a, :c, 5)
        |> Yog.add_edge_ensure(:b, :d, 1)
        |> Yog.add_edge_ensure(:c, :d, 1)
        |> DAG.from_graph()

      path = DAG.longest_path(dag)

      # a->c->d has weight 6, a->b->d has weight 2
      assert path == [:a, :c, :d]
    end

    test "longest path on empty DAG" do
      dag = DAG.new()
      assert DAG.longest_path(dag) == []
    end
  end

  describe "shortest_path/3 delegation" do
    test "delegates to Algorithm.shortest_path/3" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(:a, nil)
        |> Yog.add_node(:b, nil)
        |> Yog.add_node(:c, nil)
        |> Yog.add_edge_ensure(:a, :b, 3)
        |> Yog.add_edge_ensure(:b, :c, 2)
        |> DAG.from_graph()

      {:ok, path} = DAG.shortest_path(dag, :a, :c)

      assert path.nodes == [:a, :b, :c]
      assert path.weight == 5
    end

    test "shortest path error on unreachable node" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(:a, nil)
        |> Yog.add_node(:b, nil)
        |> Yog.add_node(:c, nil)
        |> Yog.add_edge_ensure(:a, :b, 1)
        |> DAG.from_graph()

      # c is unreachable from a
      assert :error = DAG.shortest_path(dag, :a, :c)
    end

    test "shortest path to self returns zero weight" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(:a, nil)
        |> Yog.add_node(:b, nil)
        |> Yog.add_edge_ensure(:a, :b, 5)
        |> DAG.from_graph()

      {:ok, path} = DAG.shortest_path(dag, :a, :a)

      assert path.nodes == [:a]
      assert path.weight == 0
    end
  end

  describe "topological_generations/1 delegation" do
    test "delegates to Algorithm.topological_generations/1" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(:a, nil)
        |> Yog.add_node(:b, nil)
        |> Yog.add_node(:c, nil)
        |> Yog.add_node(:d, nil)
        |> Yog.add_edge_ensure(:a, :b, 1)
        |> Yog.add_edge_ensure(:a, :c, 1)
        |> Yog.add_edge_ensure(:b, :d, 1)
        |> Yog.add_edge_ensure(:c, :d, 1)
        |> DAG.from_graph()

      assert DAG.topological_generations(dag) == [[:a], [:b, :c], [:d]]
    end
  end

  describe "lowest_common_ancestors/3 delegation" do
    test "delegates to Algorithm.lowest_common_ancestors/3" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(:a, nil)
        |> Yog.add_node(:b, nil)
        |> Yog.add_node(:c, nil)
        |> Yog.add_node(:d, nil)
        |> Yog.add_edge_ensure(:a, :b, 1)
        |> Yog.add_edge_ensure(:a, :c, 1)
        |> Yog.add_edge_ensure(:b, :d, 1)
        |> Yog.add_edge_ensure(:c, :d, 1)
        |> DAG.from_graph()

      lcas = DAG.lowest_common_ancestors(dag, :b, :c)

      assert :a in lcas
    end

    test "LCA in complex DAG" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(:x, nil)
        |> Yog.add_node(:y, nil)
        |> Yog.add_node(:z, nil)
        |> Yog.add_node(:a, nil)
        |> Yog.add_node(:b, nil)
        |> Yog.add_edge_ensure(:x, :y, 1)
        |> Yog.add_edge_ensure(:x, :z, 1)
        |> Yog.add_edge_ensure(:y, :a, 1)
        |> Yog.add_edge_ensure(:z, :b, 1)
        |> DAG.from_graph()

      lcas = DAG.lowest_common_ancestors(dag, :a, :b)

      assert :x in lcas
    end

    test "LCA returns empty for disconnected nodes" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(:a, nil)
        |> Yog.add_node(:b, nil)
        |> Yog.add_node(:c, nil)
        |> Yog.add_node(:d, nil)
        |> Yog.add_edge_ensure(:a, :b, 1)
        |> Yog.add_edge_ensure(:c, :d, 1)
        |> DAG.from_graph()

      lcas = DAG.lowest_common_ancestors(dag, :b, :d)

      # No common ancestors
      assert lcas == []
    end
  end

  # =============================================================================
  # Protocol Implementation Tests
  # =============================================================================

  describe "Enumerable protocol" do
    test "enumerates over nodes as {id, data} tuples" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> DAG.from_graph()

      nodes = Enum.to_list(dag)

      assert {1, "A"} in nodes
      assert {2, "B"} in nodes
      assert length(nodes) == 2
    end

    test "Enum.count/1 returns node count" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> DAG.from_graph()

      assert Enum.count(dag) == 3
    end

    test "Enum.member?/2 checks node existence" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> DAG.from_graph()

      assert Enum.member?(dag, {1, "A"})
      assert Enum.member?(dag, {2, "B"})
      refute Enum.member?(dag, {3, "C"})
    end
  end

  describe "Inspect protocol" do
    test "provides compact representation" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge_ensure(1, 2, 10)
        |> DAG.from_graph()

      inspected = inspect(dag)

      assert inspected =~ "#Yog.DAG<"
      assert inspected =~ "2 nodes"
      assert inspected =~ "1 edge"
    end

    test "singular form for single node" do
      dag = DAG.new() |> DAG.add_node(1, "A")

      inspected = inspect(dag)

      assert inspected =~ "1 node"
      assert inspected =~ "0 edges"
    end

    test "singular form for single edge" do
      {:ok, dag} =
        DAG.new()
        |> DAG.add_node(1, "A")
        |> DAG.add_node(2, "B")
        |> DAG.add_edge(1, 2, 10)

      inspected = inspect(dag)

      assert inspected =~ "2 nodes"
      assert inspected =~ "1 edge"
    end
  end

  # =============================================================================
  # Query Tests
  # =============================================================================

  describe "query functions" do
    test "has_node?/2" do
      dag = DAG.new() |> DAG.add_node(:a, "A")
      assert DAG.has_node?(dag, :a)
      refute DAG.has_node?(dag, :b)
    end

    test "has_edge?/3" do
      {:ok, dag} =
        DAG.new()
        |> DAG.add_node(:a, nil)
        |> DAG.add_node(:b, nil)
        |> DAG.add_edge(:a, :b, 1)

      assert DAG.has_edge?(dag, :a, :b)
      refute DAG.has_edge?(dag, :b, :a)
    end

    test "node_count/1 and edge_count/1" do
      {:ok, dag} =
        DAG.new()
        |> DAG.add_node(:a, nil)
        |> DAG.add_node(:b, nil)
        |> DAG.add_node(:c, nil)
        |> DAG.add_edge(:a, :b, 1)

      assert DAG.node_count(dag) == 3
      assert DAG.edge_count(dag) == 1
    end

    test "nodes/1" do
      dag = DAG.new() |> DAG.add_node(:a, nil) |> DAG.add_node(:b, nil)
      assert Enum.sort(DAG.nodes(dag)) == [:a, :b]
    end

    test "successors/2 and predecessors/2" do
      dag =
        DAG.new()
        |> DAG.add_node(:a, nil)
        |> DAG.add_node(:b, nil)
        |> DAG.add_node(:c, nil)

      {:ok, dag} = DAG.add_edge(dag, :a, :b, 10)
      {:ok, dag} = DAG.add_edge(dag, :a, :c, 20)

      succs = DAG.successors(dag, :a)
      assert length(succs) == 2
      assert {:b, 10} in succs
      assert {:c, 20} in succs

      preds = DAG.predecessors(dag, :b)
      assert preds == [{:a, 10}]
    end

    test "in_degree/2 and out_degree/2" do
      dag =
        DAG.new()
        |> DAG.add_node(:a, nil)
        |> DAG.add_node(:b, nil)
        |> DAG.add_node(:c, nil)

      {:ok, dag} = DAG.add_edge(dag, :a, :b, 1)
      {:ok, dag} = DAG.add_edge(dag, :a, :c, 1)

      assert DAG.in_degree(dag, :a) == 0
      assert DAG.out_degree(dag, :a) == 2
      assert DAG.in_degree(dag, :b) == 1
      assert DAG.out_degree(dag, :b) == 0
    end

    test "reachable?/3" do
      dag =
        DAG.new()
        |> DAG.add_node(:a, nil)
        |> DAG.add_node(:b, nil)
        |> DAG.add_node(:c, nil)

      {:ok, dag} = DAG.add_edge(dag, :a, :b, 1)
      {:ok, dag} = DAG.add_edge(dag, :b, :c, 1)

      assert DAG.reachable?(dag, :a, :c)
      refute DAG.reachable?(dag, :c, :a)
      assert DAG.reachable?(dag, :a, :a)
    end
  end

  # =============================================================================
  # Convenience Constructor Tests
  # =============================================================================

  describe "from_edges/1 and from_edges/2" do
    test "from_edges/1 creates DAG from unweighted edges" do
      assert {:ok, dag} = DAG.from_edges([{:a, :b}, {:b, :c}])
      assert DAG.topological_sort(dag) == [:a, :b, :c]
      assert DAG.edge_count(dag) == 2
    end

    test "from_edges/1 with weights" do
      assert {:ok, dag} = DAG.from_edges([{:a, :b, 5}, {:b, :c, 10}])
      assert DAG.topological_sort(dag) == [:a, :b, :c]
      assert DAG.edge_count(dag) == 2
    end

    test "from_edges/1 rejects cycles" do
      assert {:error, :cycle_detected} = DAG.from_edges([{:a, :b}, {:b, :a}])
    end

    test "from_edges/2 with default weight" do
      assert {:ok, dag} = DAG.from_edges([{:a, :b}, {:b, :c}], 42)
      graph = DAG.to_graph(dag)
      assert Yog.Model.edge_data(graph, :a, :b) == 42
      assert Yog.Model.edge_data(graph, :b, :c) == 42
    end
  end

  # =============================================================================
  # Sources and Sinks Tests
  # =============================================================================

  describe "sources/1 and sinks/1" do
    test "sources returns nodes with in-degree 0" do
      {:ok, dag} = DAG.from_edges([{:a, :b}, {:a, :c}, {:b, :d}, {:c, :d}])
      assert DAG.sources(dag) == [:a]
    end

    test "sinks returns nodes with out-degree 0" do
      {:ok, dag} = DAG.from_edges([{:a, :b}, {:a, :c}, {:b, :d}, {:c, :d}])
      assert DAG.sinks(dag) == [:d]
    end

    test "sources and sinks on disconnected DAG" do
      {:ok, dag} = DAG.from_edges([{:a, :b}, {:c, :d}])
      assert Enum.sort(DAG.sources(dag)) == [:a, :c]
      assert Enum.sort(DAG.sinks(dag)) == [:b, :d]
    end

    test "sources and sinks on empty DAG" do
      assert DAG.sources(DAG.new()) == []
      assert DAG.sinks(DAG.new()) == []
    end
  end

  # =============================================================================
  # Ancestors and Descendants Tests
  # =============================================================================

  describe "ancestors/2 and descendants/2" do
    test "ancestors includes the node itself" do
      {:ok, dag} = DAG.from_edges([{:a, :b}, {:b, :c}])
      assert Enum.sort(DAG.ancestors(dag, :c)) == [:a, :b, :c]
    end

    test "ancestors for source node" do
      {:ok, dag} = DAG.from_edges([{:a, :b}, {:b, :c}])
      assert DAG.ancestors(dag, :a) == [:a]
    end

    test "descendants includes the node itself" do
      {:ok, dag} = DAG.from_edges([{:a, :b}, {:b, :c}])
      assert Enum.sort(DAG.descendants(dag, :a)) == [:a, :b, :c]
    end

    test "descendants for sink node" do
      {:ok, dag} = DAG.from_edges([{:a, :b}, {:b, :c}])
      assert DAG.descendants(dag, :c) == [:c]
    end
  end

  # =============================================================================
  # Single Source Distances Tests
  # =============================================================================

  describe "single_source_distances/2" do
    test "computes all shortest distances from source" do
      {:ok, dag} = DAG.from_edges([{:a, :b, 3}, {:b, :c, 2}, {:a, :c, 10}])
      distances = DAG.single_source_distances(dag, :a)

      assert distances[:a] == 0
      assert distances[:b] == 3
      assert distances[:c] == 5
    end

    test "returns empty map for unknown source" do
      {:ok, dag} = DAG.from_edges([{:a, :b, 1}])
      assert DAG.single_source_distances(dag, :z) == %{}
    end

    test "skips unreachable nodes" do
      {:ok, dag} = DAG.from_edges([{:a, :b, 1}, {:c, :d, 1}])
      distances = DAG.single_source_distances(dag, :a)

      assert distances[:a] == 0
      assert distances[:b] == 1
      refute Map.has_key?(distances, :c)
      refute Map.has_key?(distances, :d)
    end
  end

  # =============================================================================
  # Longest Path (between two nodes) Tests
  # =============================================================================

  describe "longest_path/3" do
    test "finds longest path between two nodes" do
      {:ok, dag} = DAG.from_edges([{:a, :b, 1}, {:a, :c, 5}, {:b, :d, 1}, {:c, :d, 1}])
      {:ok, path} = DAG.longest_path(dag, :a, :d)

      assert path.nodes == [:a, :c, :d]
      assert path.weight == 6
    end

    test "returns error for unreachable target" do
      {:ok, dag} = DAG.from_edges([{:a, :b, 1}, {:c, :d, 1}])
      assert :error = DAG.longest_path(dag, :a, :d)
    end

    test "returns error for unknown source" do
      {:ok, dag} = DAG.from_edges([{:a, :b, 1}])
      assert :error = DAG.longest_path(dag, :z, :b)
    end

    test "path to self has zero weight" do
      {:ok, dag} = DAG.from_edges([{:a, :b, 5}])
      {:ok, path} = DAG.longest_path(dag, :a, :a)

      assert path.nodes == [:a]
      assert path.weight == 0
    end
  end

  # =============================================================================
  # Path Count Tests
  # =============================================================================

  describe "path_count/3" do
    test "counts single path" do
      {:ok, dag} = DAG.from_edges([{:a, :b}, {:b, :c}])
      assert DAG.path_count(dag, :a, :c) == 1
    end

    test "counts multiple paths in diamond" do
      {:ok, dag} = DAG.from_edges([{:a, :b}, {:a, :c}, {:b, :d}, {:c, :d}])
      assert DAG.path_count(dag, :a, :d) == 2
    end

    test "counts converging paths" do
      {:ok, dag} = DAG.from_edges([{:a, :c}, {:b, :c}, {:c, :d}])
      assert DAG.path_count(dag, :a, :d) == 1
    end

    test "zero paths for unreachable target" do
      {:ok, dag} = DAG.from_edges([{:a, :b}, {:c, :d}])
      assert DAG.path_count(dag, :a, :d) == 0
    end

    test "zero paths for unknown source" do
      {:ok, dag} = DAG.from_edges([{:a, :b}])
      assert DAG.path_count(dag, :z, :b) == 0
    end
  end

  # =============================================================================
  # Integration Tests
  # =============================================================================

  describe "integration tests" do
    test "full DAG lifecycle: create, modify, query" do
      # Create empty DAG
      dag = DAG.new()
      assert inspect(dag) =~ "0 nodes"

      # Add nodes
      dag =
        dag
        |> DAG.add_node(:task1, %{name: "Compile", duration: 5})
        |> DAG.add_node(:task2, %{name: "Test", duration: 10})
        |> DAG.add_node(:task3, %{name: "Deploy", duration: 3})

      assert Enum.count(dag) == 3

      # Add edges (dependencies)
      {:ok, dag} = DAG.add_edge(dag, :task1, :task2, 0)
      {:ok, dag} = DAG.add_edge(dag, :task2, :task3, 0)

      # Verify structure via topological sort
      sorted = DAG.topological_sort(dag)
      assert sorted == [:task1, :task2, :task3]

      # Query paths
      {:ok, path} = DAG.shortest_path(dag, :task1, :task3)
      assert path.nodes == [:task1, :task2, :task3]

      # Convert back to graph
      graph = DAG.to_graph(dag)
      assert is_struct(graph, Yog.Graph)
    end

    test "complex build dependency DAG" do
      # Simulate a build system with dependencies
      # lib -> compile_lib -> link
      # app -> compile_app -> link
      # link -> package

      dag =
        DAG.new()
        |> DAG.add_node(:lib_src, nil)
        |> DAG.add_node(:app_src, nil)
        |> DAG.add_node(:compile_lib, nil)
        |> DAG.add_node(:compile_app, nil)
        |> DAG.add_node(:link, nil)
        |> DAG.add_node(:package, nil)

      {:ok, dag} = DAG.add_edge(dag, :lib_src, :compile_lib, 1)
      {:ok, dag} = DAG.add_edge(dag, :app_src, :compile_app, 2)
      {:ok, dag} = DAG.add_edge(dag, :compile_lib, :link, 3)
      {:ok, dag} = DAG.add_edge(dag, :compile_app, :link, 4)
      {:ok, dag} = DAG.add_edge(dag, :link, :package, 5)

      # Verify critical path
      critical_path = DAG.longest_path(dag)

      # app_src -> compile_app -> link -> package should be critical (2+4+5=11)
      # vs lib_src -> compile_lib -> link -> package (1+3+5=9)
      assert :app_src in critical_path
      assert :package in critical_path

      # LCA of compile_lib and compile_app should be nil (no shared ancestors)
      lcas = DAG.lowest_common_ancestors(dag, :compile_lib, :compile_app)
      assert lcas == []

      # LCA of link and package - both have link as ancestor
      lcas = DAG.lowest_common_ancestors(dag, :link, :package)
      assert :link in lcas
    end

    test "query-heavy workflow using from_edges" do
      {:ok, dag} =
        DAG.from_edges([
          {:deps, :compile},
          {:compile, :test},
          {:compile, :lint},
          {:test, :package},
          {:lint, :package}
        ])

      # Structural queries
      assert DAG.sources(dag) == [:deps]
      assert DAG.sinks(dag) == [:package]
      assert DAG.node_count(dag) == 5
      assert DAG.edge_count(dag) == 5

      # Reachability
      assert DAG.reachable?(dag, :deps, :package)
      refute DAG.reachable?(dag, :package, :deps)

      # Ancestors/descendants
      assert :deps in DAG.ancestors(dag, :package)
      assert :package in DAG.descendants(dag, :deps)

      # Path counting (2 paths from compile to package)
      assert DAG.path_count(dag, :compile, :package) == 2
      assert DAG.path_count(dag, :deps, :package) == 2

      # Distances (all unweighted, so shortest = fewest edges)
      distances = DAG.single_source_distances(dag, :deps)
      assert distances[:deps] == 0
      assert distances[:compile] == 1
      assert distances[:package] == 3
    end
  end
end
