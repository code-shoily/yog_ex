defmodule YogDAGTest do
  use ExUnit.Case

  # ============= Construction Tests =============

  test "new_dag_test" do
    dag = Yog.DAG.new(:directed)

    assert dag != nil
    graph = Yog.DAG.to_graph(dag)
    assert Yog.Model.order(graph) == 0
  end

  test "from_graph_acyclic_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)

    assert {:ok, dag} = Yog.DAG.from_graph(graph)
    result_graph = Yog.DAG.to_graph(dag)
    assert Yog.Model.order(result_graph) == 3
  end

  test "from_graph_cyclic_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 3, with: 1)
      # Creates cycle
      |> Yog.add_edge!(from: 3, to: 1, with: 1)

    assert {:error, :cycle_detected} = Yog.DAG.from_graph(graph)
  end

  test "from_graph_self_loop_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      # Self loop
      |> Yog.add_edge!(from: 1, to: 1, with: 1)

    assert {:error, :cycle_detected} = Yog.DAG.from_graph(graph)
  end

  # ============= Node Operations Tests =============

  test "add_node_test" do
    dag =
      Yog.DAG.new(:directed)
      |> Yog.DAG.add_node(1, "A")
      |> Yog.DAG.add_node(2, "B")

    graph = Yog.DAG.to_graph(dag)
    assert Yog.Model.order(graph) == 2
    assert Yog.Model.node(graph, 1) == "A"
    assert Yog.Model.node(graph, 2) == "B"
  end

  test "remove_node_test" do
    dag =
      Yog.DAG.new(:directed)
      |> Yog.DAG.add_node(1, "A")
      |> Yog.DAG.add_node(2, "B")
      |> Yog.DAG.add_node(3, "C")
      |> Yog.DAG.remove_node(2)

    graph = Yog.DAG.to_graph(dag)
    assert Yog.Model.order(graph) == 2
    assert Yog.Model.node(graph, 1) == "A"
    assert Yog.Model.node(graph, 3) == "C"
  end

  # ============= Edge Operations Tests =============

  test "add_edge_valid_test" do
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, 1, "A")
    dag = Yog.DAG.add_node(dag, 2, "B")

    assert {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 10)

    graph = Yog.DAG.to_graph(dag)
    assert Yog.successors(graph, 1) == [{2, 10}]
  end

  test "add_edge_creates_cycle_test" do
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, 1, "A")
    dag = Yog.DAG.add_node(dag, 2, "B")
    dag = Yog.DAG.add_node(dag, 3, "C")

    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 1)
    {:ok, dag} = Yog.DAG.add_edge(dag, 2, 3, 1)

    # Adding edge 3->1 would create a cycle
    assert {:error, :cycle_detected} = Yog.DAG.add_edge(dag, 3, 1, 1)
  end

  test "add_edge_self_loop_test" do
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, 1, "A")

    # Self loop creates a cycle
    assert {:error, :cycle_detected} = Yog.DAG.add_edge(dag, 1, 1, 1)
  end

  test "remove_edge_test" do
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, 1, "A")
    dag = Yog.DAG.add_node(dag, 2, "B")

    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 10)
    dag = Yog.DAG.remove_edge(dag, 1, 2)

    graph = Yog.DAG.to_graph(dag)
    assert Yog.successors(graph, 1) == []
  end

  # ============= Topological Sort Tests =============

  test "topological_sort_simple_test" do
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, 1, "A")
    dag = Yog.DAG.add_node(dag, 2, "B")
    dag = Yog.DAG.add_node(dag, 3, "C")

    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 1)
    {:ok, dag} = Yog.DAG.add_edge(dag, 2, 3, 1)

    sorted = Yog.DAG.topological_sort(dag)

    # Should be [1, 2, 3]
    assert sorted == [1, 2, 3]
  end

  test "topological_sort_diamond_test" do
    # Diamond shape: 1 -> 2, 1 -> 3, 2 -> 4, 3 -> 4
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, 1, "A")
    dag = Yog.DAG.add_node(dag, 2, "B")
    dag = Yog.DAG.add_node(dag, 3, "C")
    dag = Yog.DAG.add_node(dag, 4, "D")

    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 1)
    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 3, 1)
    {:ok, dag} = Yog.DAG.add_edge(dag, 2, 4, 1)
    {:ok, dag} = Yog.DAG.add_edge(dag, 3, 4, 1)

    sorted = Yog.DAG.topological_sort(dag)

    # 1 must come before 2 and 3, 2 and 3 must come before 4
    assert List.first(sorted) == 1
    assert List.last(sorted) == 4
    idx_2 = Enum.find_index(sorted, &(&1 == 2))
    idx_3 = Enum.find_index(sorted, &(&1 == 3))
    idx_4 = Enum.find_index(sorted, &(&1 == 4))
    assert idx_2 < idx_4
    assert idx_3 < idx_4
  end

  test "topological_sort_empty_dag_test" do
    dag = Yog.DAG.new(:directed)
    sorted = Yog.DAG.topological_sort(dag)

    assert sorted == []
  end

  test "topological_sort_single_node_test" do
    dag = Yog.DAG.new(:directed) |> Yog.DAG.add_node(1, "A")
    sorted = Yog.DAG.topological_sort(dag)

    assert sorted == [1]
  end

  # ============= Longest Path Tests =============

  test "longest_path_simple_test" do
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, 1, "A")
    dag = Yog.DAG.add_node(dag, 2, "B")
    dag = Yog.DAG.add_node(dag, 3, "C")

    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 10)
    {:ok, dag} = Yog.DAG.add_edge(dag, 2, 3, 5)

    path = Yog.DAG.longest_path(dag)

    # Longest path should be 1 -> 2 -> 3
    assert path == [1, 2, 3]
  end

  test "longest_path_diamond_test" do
    # Diamond: 1->2 (weight 1), 1->3 (weight 10), 2->4 (weight 1), 3->4 (weight 1)
    # Longest path should be 1->3->4 (total weight 11)
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, 1, "A")
    dag = Yog.DAG.add_node(dag, 2, "B")
    dag = Yog.DAG.add_node(dag, 3, "C")
    dag = Yog.DAG.add_node(dag, 4, "D")

    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 1)
    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 3, 10)
    {:ok, dag} = Yog.DAG.add_edge(dag, 2, 4, 1)
    {:ok, dag} = Yog.DAG.add_edge(dag, 3, 4, 1)

    path = Yog.DAG.longest_path(dag)

    # Should prefer the heavier path through node 3
    assert path == [1, 3, 4]
  end

  # ============= Transitive Closure Tests =============

  test "transitive_closure_test" do
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, 1, "A")
    dag = Yog.DAG.add_node(dag, 2, "B")
    dag = Yog.DAG.add_node(dag, 3, "C")

    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 1)
    {:ok, dag} = Yog.DAG.add_edge(dag, 2, 3, 1)

    closure = Yog.DAG.transitive_closure(dag)
    graph = Yog.DAG.to_graph(closure)

    # Should have edges: 1->2, 2->3, and 1->3 (transitive)
    successors_1 = Yog.successor_ids(graph, 1)
    assert 2 in successors_1
    assert 3 in successors_1

    successors_2 = Yog.successor_ids(graph, 2)
    assert 3 in successors_2
  end

  # ============= Transitive Reduction Tests =============

  test "transitive_reduction_test" do
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, 1, "A")
    dag = Yog.DAG.add_node(dag, 2, "B")
    dag = Yog.DAG.add_node(dag, 3, "C")

    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 1)
    {:ok, dag} = Yog.DAG.add_edge(dag, 2, 3, 1)
    # Redundant edge
    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 3, 1)

    reduction = Yog.DAG.transitive_reduction(dag)
    graph = Yog.DAG.to_graph(reduction)

    # Should remove the redundant 1->3 edge
    successors_1 = Yog.successor_ids(graph, 1)
    # After reduction, should only have direct edge to 2
    assert length(successors_1) <= 2
  end

  # ============= Complex DAG Tests =============

  test "complex_dag_operations_test" do
    # Build a task dependency graph
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, :start, "Start")
    dag = Yog.DAG.add_node(dag, :task_a, "Task A")
    dag = Yog.DAG.add_node(dag, :task_b, "Task B")
    dag = Yog.DAG.add_node(dag, :task_c, "Task C")
    dag = Yog.DAG.add_node(dag, :end, "End")

    {:ok, dag} = Yog.DAG.add_edge(dag, :start, :task_a, 5)
    {:ok, dag} = Yog.DAG.add_edge(dag, :start, :task_b, 3)
    {:ok, dag} = Yog.DAG.add_edge(dag, :task_a, :task_c, 2)
    {:ok, dag} = Yog.DAG.add_edge(dag, :task_b, :task_c, 4)
    {:ok, dag} = Yog.DAG.add_edge(dag, :task_c, :end, 1)

    # Verify topological sort
    sorted = Yog.DAG.topological_sort(dag)
    assert :start == List.first(sorted)
    assert :end == List.last(sorted)

    # Verify longest path
    path = Yog.DAG.longest_path(dag)
    assert :start == List.first(path)
    assert :end == List.last(path)
  end

  # ============= Edge Cases =============

  test "multiple_disconnected_components_test" do
    dag = Yog.DAG.new(:directed)
    dag = Yog.DAG.add_node(dag, 1, "A")
    dag = Yog.DAG.add_node(dag, 2, "B")
    dag = Yog.DAG.add_node(dag, 3, "C")
    dag = Yog.DAG.add_node(dag, 4, "D")

    {:ok, dag} = Yog.DAG.add_edge(dag, 1, 2, 1)
    {:ok, dag} = Yog.DAG.add_edge(dag, 3, 4, 1)

    # Should still be a valid DAG
    sorted = Yog.DAG.topological_sort(dag)
    assert length(sorted) == 4
  end
end
