defmodule YogEulerianTest do
  use ExUnit.Case

  alias Yog.Eulerian

  # ============= Eulerian Circuit Tests (Undirected) =============

  test "has_eulerian_circuit_triangle_test" do
    # Triangle: all vertices have even degree (degree 2)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 1, weight: 1)

    assert Eulerian.has_eulerian_circuit?(graph) == true
  end

  test "has_eulerian_circuit_square_test" do
    # Square: all vertices have even degree (degree 2)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)
      |> Yog.add_edge(from: 4, to: 1, weight: 1)

    assert Eulerian.has_eulerian_circuit?(graph) == true
  end

  test "has_eulerian_circuit_line_fails_test" do
    # Line: endpoints have odd degree (degree 1)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)

    assert Eulerian.has_eulerian_circuit?(graph) == false
  end

  test "has_eulerian_circuit_star_fails_test" do
    # Star: center has degree 3 (odd), leaves have degree 1 (odd)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 1, to: 4, weight: 1)

    assert Eulerian.has_eulerian_circuit?(graph) == false
  end

  test "has_eulerian_circuit_disconnected_fails_test" do
    # Two triangles, disconnected
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      |> Yog.add_node(6, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 1, weight: 1)
      |> Yog.add_edge(from: 4, to: 5, weight: 1)
      |> Yog.add_edge(from: 5, to: 6, weight: 1)
      |> Yog.add_edge(from: 6, to: 4, weight: 1)

    assert Eulerian.has_eulerian_circuit?(graph) == false
  end

  test "has_eulerian_circuit_empty_graph_test" do
    graph = Yog.undirected()
    assert Eulerian.has_eulerian_circuit?(graph) == false
  end

  # ============= Eulerian Path Tests (Undirected) =============

  test "has_eulerian_path_line_test" do
    # Line: exactly 2 vertices with odd degree (the endpoints)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)

    assert Eulerian.has_eulerian_path?(graph) == true
  end

  test "has_eulerian_path_triangle_test" do
    # Triangle: 0 vertices with odd degree (also has circuit)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 1, weight: 1)

    assert Eulerian.has_eulerian_path?(graph) == true
  end

  test "has_eulerian_path_star_fails_test" do
    # Star: 4 vertices with odd degree (too many)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 1, to: 4, weight: 1)

    assert Eulerian.has_eulerian_path?(graph) == false
  end

  test "has_eulerian_path_house_test" do
    # House shape: square with diagonal
    # Vertices 2,4 have odd degree (3), others even (2)
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)
      |> Yog.add_edge(from: 4, to: 1, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)

    assert Eulerian.has_eulerian_path?(graph) == true
  end

  # ============= Find Eulerian Circuit Tests =============

  test "find_eulerian_circuit_triangle_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 1, weight: 1)

    assert {:ok, path} = Eulerian.find_eulerian_circuit(graph)
    # Path should start and end at same vertex
    assert List.first(path) == List.last(path)
    # Path should have 4 vertices (3 edges + return to start)
    assert length(path) == 4
  end

  test "find_eulerian_circuit_square_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 4, weight: 1)
      |> Yog.add_edge(from: 4, to: 1, weight: 1)

    assert {:ok, path} = Eulerian.find_eulerian_circuit(graph)
    assert List.first(path) == List.last(path)
    assert length(path) == 5
  end

  test "find_eulerian_circuit_line_fails_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)

    assert Eulerian.find_eulerian_circuit(graph) == {:error, :no_eulerian_circuit}
  end

  # ============= Find Eulerian Path Tests =============

  test "find_eulerian_path_line_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)

    assert {:ok, path} = Eulerian.find_eulerian_path(graph)
    # Path should have 3 vertices (2 edges)
    assert length(path) == 3

    # Either starts at 1 and ends at 3, or vice versa
    assert (List.first(path) == 1 and List.last(path) == 3) or
             (List.first(path) == 3 and List.last(path) == 1)
  end

  test "find_eulerian_path_triangle_returns_circuit_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 1, weight: 1)

    assert {:ok, path} = Eulerian.find_eulerian_path(graph)
    assert length(path) == 4
  end

  test "find_eulerian_path_star_fails_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 1, to: 4, weight: 1)

    assert Eulerian.find_eulerian_path(graph) == {:error, :no_eulerian_path}
  end

  # ============= Directed Graph Tests =============

  test "has_eulerian_circuit_directed_cycle_test" do
    # Simple directed cycle: 1 -> 2 -> 3 -> 1
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 1, weight: 1)

    assert Eulerian.has_eulerian_circuit?(graph) == true
  end

  test "has_eulerian_circuit_directed_unbalanced_fails_test" do
    # Directed path: 1 -> 2 -> 3 (no circuit)
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)

    assert Eulerian.has_eulerian_circuit?(graph) == false
  end

  test "has_eulerian_path_directed_line_test" do
    # Directed path: 1 -> 2 -> 3
    # Node 1: out=1, in=0 (start)
    # Node 2: out=1, in=1 (balanced)
    # Node 3: out=0, in=1 (end)
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)

    assert Eulerian.has_eulerian_path?(graph) == true
  end

  test "find_eulerian_circuit_directed_cycle_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 3, to: 1, weight: 1)

    assert {:ok, path} = Eulerian.find_eulerian_circuit(graph)
    assert List.first(path) == List.last(path)
    assert length(path) == 4
  end

  test "find_eulerian_path_directed_line_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)

    assert {:ok, path} = Eulerian.find_eulerian_path(graph)
    assert length(path) == 3
    assert List.first(path) == 1
    assert List.last(path) == 3
  end

  # ============= Complex Graph Tests =============

  test "eulerian_circuit_k4_minus_edge_test" do
    # Complete graph K4 minus one edge (still has Eulerian circuit)
    # All vertices will have even degree
    graph =
      Yog.undirected()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edge(from: 1, to: 2, weight: 1)
      |> Yog.add_edge(from: 1, to: 3, weight: 1)
      |> Yog.add_edge(from: 1, to: 4, weight: 1)
      |> Yog.add_edge(from: 2, to: 3, weight: 1)
      |> Yog.add_edge(from: 2, to: 4, weight: 1)

    # Missing: 3-4

    # Degrees: 1=3(odd), 2=3(odd), 3=2(even), 4=2(even)
    # This should have Eulerian path but not circuit
    assert Eulerian.has_eulerian_circuit?(graph) == false
    assert Eulerian.has_eulerian_path?(graph) == true
  end
end
