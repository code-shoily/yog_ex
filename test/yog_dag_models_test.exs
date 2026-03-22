defmodule YogDAGModelsTest do
  @moduledoc """
  Tests for Yog.DAG.Models module.

  The DAG (Directed Acyclic Graph) type guarantees acyclicity at the type level,
  enabling total functions for operations like topological sorting.
  """

  use ExUnit.Case

  doctest Yog.DAG.Models

  alias Yog.DAG.Models

  # ============================================================
  # Construction Tests
  # ============================================================

  describe "construction" do
    test "new/1 creates empty DAG" do
      dag = Models.new(:directed)
      assert {:dag, _} = dag
    end

    test "from_graph/1 creates DAG from acyclic graph" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge!(1, 2, 10)

      assert {:ok, {:dag, _}} = Models.from_graph(graph)
    end

    test "from_graph/1 returns error for cyclic graph" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge!(1, 2, 10)
        |> Yog.add_edge!(2, 1, 10)

      assert {:error, :cycle_detected} = Models.from_graph(graph)
    end

    test "to_graph/1 unwraps DAG to graph" do
      dag = Models.new(:directed)
      graph = Models.to_graph(dag)
      assert is_tuple(graph)
    end
  end

  # ============================================================
  # Node Operations Tests
  # ============================================================

  describe "node operations" do
    test "add_node/3 adds node to DAG" do
      dag =
        Models.new(:directed)
        |> Models.add_node(1, "A")
        |> Models.add_node(2, "B")

      graph = Models.to_graph(dag)
      nodes = Yog.all_nodes(graph)
      assert length(nodes) == 2
      assert 1 in nodes
      assert 2 in nodes
    end

    test "remove_node/2 removes node and edges" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge!(1, 2, 10)
        |> Models.from_graph()

      dag = Models.remove_node(dag, 2)
      graph = Models.to_graph(dag)
      nodes = Yog.all_nodes(graph)
      assert nodes == [1]
    end
  end

  # ============================================================
  # Edge Operations Tests
  # ============================================================

  describe "edge operations" do
    test "add_edge/4 adds valid edge" do
      dag =
        Models.new(:directed)
        |> Models.add_node(1, "A")
        |> Models.add_node(2, "B")

      assert {:ok, dag2} = Models.add_edge(dag, 1, 2, 10)
      graph = Models.to_graph(dag2)
      assert Yog.successors(graph, 1) == [{2, 10}]
    end

    test "add_edge/4 detects cycle" do
      dag =
        Models.new(:directed)
        |> Models.add_node(1, "A")
        |> Models.add_node(2, "B")
        |> Models.add_node(3, "C")

      {:ok, dag} = Models.add_edge(dag, 1, 2, 10)
      {:ok, dag} = Models.add_edge(dag, 2, 3, 20)

      # Adding 3->1 would create a cycle
      assert {:error, :cycle_detected} = Models.add_edge(dag, 3, 1, 30)
    end

    test "add_edge/4 allows self-loop detection" do
      dag =
        Models.new(:directed)
        |> Models.add_node(1, "A")

      # Self-loop is a cycle
      assert {:error, :cycle_detected} = Models.add_edge(dag, 1, 1, 10)
    end

    test "remove_edge/3 removes edge" do
      {:ok, dag} =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge!(1, 2, 10)
        |> Models.from_graph()

      dag = Models.remove_edge(dag, 1, 2)
      graph = Models.to_graph(dag)
      assert Yog.successors(graph, 1) == []
    end
  end

  # ============================================================
  # DAG Preservation Tests
  # ============================================================

  describe "DAG preservation" do
    test "multiple edges preserving acyclicity" do
      dag =
        Models.new(:directed)
        |> Models.add_node(1, "A")
        |> Models.add_node(2, "B")
        |> Models.add_node(3, "C")
        |> Models.add_node(4, "D")

      # Build a diamond DAG: 1 -> 2, 1 -> 3, 2 -> 4, 3 -> 4
      {:ok, dag} = Models.add_edge(dag, 1, 2, 1)
      {:ok, dag} = Models.add_edge(dag, 1, 3, 2)
      {:ok, dag} = Models.add_edge(dag, 2, 4, 3)
      {:ok, dag} = Models.add_edge(dag, 3, 4, 4)

      graph = Models.to_graph(dag)
      assert length(Yog.successors(graph, 1)) == 2
      assert length(Yog.predecessors(graph, 4)) == 2
    end

    test "complex DAG construction" do
      # Create a more complex DAG
      dag =
        Models.new(:directed)
        |> Models.add_node(:a, "A")
        |> Models.add_node(:b, "B")
        |> Models.add_node(:c, "C")
        |> Models.add_node(:d, "D")
        |> Models.add_node(:e, "E")

      {:ok, dag} = Models.add_edge(dag, :a, :b, 1)
      {:ok, dag} = Models.add_edge(dag, :a, :c, 2)
      {:ok, dag} = Models.add_edge(dag, :b, :d, 3)
      {:ok, dag} = Models.add_edge(dag, :c, :d, 4)
      {:ok, dag} = Models.add_edge(dag, :d, :e, 5)

      # Verify structure
      graph = Models.to_graph(dag)
      assert Yog.successors(graph, :a) |> Enum.map(&elem(&1, 0)) |> Enum.sort() == [:b, :c]
      assert Yog.predecessors(graph, :d) |> Enum.map(&elem(&1, 0)) |> Enum.sort() == [:b, :c]
      assert Yog.successors(graph, :d) == [{:e, 5}]
    end
  end

  # ============================================================
  # Error Handling Tests
  # ============================================================

  describe "error handling" do
    test "cycle detection in complex graph" do
      # Create a graph that's almost a cycle
      dag =
        Models.new(:directed)
        |> Models.add_node(1, "A")
        |> Models.add_node(2, "B")
        |> Models.add_node(3, "C")
        |> Models.add_node(4, "D")

      {:ok, dag} = Models.add_edge(dag, 1, 2, 1)
      {:ok, dag} = Models.add_edge(dag, 2, 3, 2)
      {:ok, dag} = Models.add_edge(dag, 3, 4, 3)

      # Adding 4->2 creates a cycle: 2->3->4->2
      assert {:error, :cycle_detected} = Models.add_edge(dag, 4, 2, 4)

      # But adding 4->1 is fine (creates 1->2->3->4->1 which is a cycle - wait, that IS a cycle)
      # Actually 4->1 creates 1->2->3->4->1 which IS a cycle
      assert {:error, :cycle_detected} = Models.add_edge(dag, 4, 1, 5)
    end

    test "from_graph preserves error for cyclic graph" do
      # Create a cyclic graph
      graph =
        Yog.directed()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_node(3, "C")
        |> Yog.add_edge!(1, 2, 1)
        |> Yog.add_edge!(2, 3, 2)
        |> Yog.add_edge!(3, 1, 3)

      assert {:error, :cycle_detected} = Models.from_graph(graph)
    end
  end
end
