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
  end
end
