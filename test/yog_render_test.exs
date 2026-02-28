defmodule YogRenderTest do
  use ExUnit.Case

  alias Yog.Render

  # ============= Basic Mermaid Generation Tests =============

  test "empty_directed_graph_test" do
    graph = Yog.directed()
    output = Render.to_mermaid(graph)

    assert String.starts_with?(output, "graph TD\n")
  end

  test "empty_undirected_graph_test" do
    graph = Yog.undirected()
    output = Render.to_mermaid(graph)

    assert String.starts_with?(output, "graph LR\n")
  end

  test "single_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")

    output = Render.to_mermaid(graph)

    assert String.contains?(output, "1[\"1\"]")
  end

  test "multiple_nodes_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_node(3, "Node C")

    output = Render.to_mermaid(graph)

    assert String.contains?(output, "1[\"1\"]")
    assert String.contains?(output, "2[\"2\"]")
    assert String.contains?(output, "3[\"3\"]")
  end

  test "single_directed_edge_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_edge(from: 1, to: 2, with: "10")

    output = Render.to_mermaid(graph)

    # Should use --> for directed edge
    assert String.contains?(output, "1 -->|10| 2")
  end

  test "single_undirected_edge_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_edge(from: 1, to: 2, with: "10")

    output = Render.to_mermaid(graph)

    # Should use --- for undirected edge
    assert String.contains?(output, "1 ---|10| 2")

    # Should NOT show the reverse edge (2 ---|10| 1)
    refute String.contains?(output, "2 ---|10| 1")
  end

  test "undirected_no_duplicate_edges_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: "5")
      |> Yog.add_edge(from: 2, to: 3, with: "3")
      |> Yog.add_edge(from: 1, to: 3, with: "1")

    output = Render.to_mermaid(graph)

    # Should have exactly 3 edges (not 6)
    # Count occurrences of "---" (edge marker)
    edge_count =
      output
      |> String.split("---")
      |> length()
      |> Kernel.-(1)

    assert edge_count == 3

    # Verify each edge appears once
    assert String.contains?(output, "1 ---|5| 2")
    assert String.contains?(output, "2 ---|3| 3")
    assert String.contains?(output, "1 ---|1| 3")

    # Verify reverse edges DON'T appear
    refute String.contains?(output, "2 ---|5| 1")
    refute String.contains?(output, "3 ---|3| 2")
    refute String.contains?(output, "3 ---|1| 1")
  end

  test "multiple_edges_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: "5")
      |> Yog.add_edge(from: 2, to: 3, with: "10")
      |> Yog.add_edge(from: 1, to: 3, with: "15")

    output = Render.to_mermaid(graph)

    assert String.contains?(output, "1 -->|5| 2")
    assert String.contains?(output, "2 -->|10| 3")
    assert String.contains?(output, "1 -->|15| 3")
  end

  # ============= Custom Label Tests =============

  test "custom_node_label_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Start")
      |> Yog.add_node(2, "End")

    output =
      Render.to_mermaid(graph,
        node_label: fn id, data -> "#{data} (ID:#{id})" end
      )

    assert String.contains?(output, "1[\"Start (ID:1)\"]")
    assert String.contains?(output, "2[\"End (ID:2)\"]")
  end

  test "custom_edge_label_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: "100")

    output =
      Render.to_mermaid(graph,
        edge_label: fn weight -> "#{weight} km" end
      )

    assert String.contains?(output, "1 -->|100 km| 2")
  end

  # ============= Highlighting Tests =============

  test "highlight_single_node_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")

    output =
      Render.to_mermaid(graph,
        options: %{highlighted_nodes: [2]}
      )

    # Should have style definitions
    assert String.contains?(output, "classDef highlight")

    # Node 2 should be highlighted
    assert String.contains?(output, "2[\"2\"]:::highlight")

    # Node 1 should not be highlighted
    refute String.contains?(output, "1[\"1\"]:::highlight")
  end

  test "highlight_multiple_nodes_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")

    output =
      Render.to_mermaid(graph,
        options: %{highlighted_nodes: [1, 3]}
      )

    assert String.contains?(output, "1[\"1\"]:::highlight")
    assert String.contains?(output, "3[\"3\"]:::highlight")
    refute String.contains?(output, "2[\"2\"]:::highlight")
  end

  test "highlight_edges_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: "5")
      |> Yog.add_edge(from: 2, to: 3, with: "10")

    output =
      Render.to_mermaid(graph,
        options: %{highlighted_edges: [{1, 2}]}
      )

    assert String.contains?(output, "classDef highlightEdge")
    assert String.contains?(output, "1 -->|5| 2:::highlightEdge")
    refute String.contains?(output, "2 -->|10| 3:::highlightEdge")
  end

  test "highlight_path_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: "5")
      |> Yog.add_edge(from: 2, to: 3, with: "10")

    output =
      Render.to_mermaid(graph,
        options: %{
          highlighted_nodes: [1, 2, 3],
          highlighted_edges: [{1, 2}, {2, 3}]
        }
      )

    # All nodes should be highlighted
    assert String.contains?(output, "1[\"1\"]:::highlight")
    assert String.contains?(output, "2[\"2\"]:::highlight")
    assert String.contains?(output, "3[\"3\"]:::highlight")

    # Both edges should be highlighted
    assert String.contains?(output, "1 -->|5| 2:::highlightEdge")
    assert String.contains?(output, "2 -->|10| 3:::highlightEdge")
  end

  # ============= DOT (Graphviz) Rendering Tests =============

  test "empty_directed_dot_test" do
    graph = Yog.directed()
    output = Render.to_dot(graph)

    assert String.starts_with?(output, "digraph G {\n")
    assert String.ends_with?(output, "\n}")
  end

  test "empty_undirected_dot_test" do
    graph = Yog.undirected()
    output = Render.to_dot(graph)

    assert String.starts_with?(output, "graph G {\n")
  end

  test "single_node_dot_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")

    output = Render.to_dot(graph)

    assert String.contains?(output, "1 [label=\"1\"]")
  end

  test "single_directed_edge_dot_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_edge(from: 1, to: 2, with: "10")

    output = Render.to_dot(graph)

    # Should use -> for directed edge
    assert String.contains?(output, "1 -> 2 [label=\"10\"]")
  end

  test "single_undirected_edge_dot_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_edge(from: 1, to: 2, with: "10")

    output = Render.to_dot(graph)

    # Should use -- for undirected edge
    assert String.contains?(output, "1 -- 2 [label=\"10\"]")

    # Should NOT show the reverse edge
    refute String.contains?(output, "2 -- 1 [label=\"10\"]")
  end

  test "custom_node_label_dot_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Start")
      |> Yog.add_node(2, "End")

    output =
      Render.to_dot(graph,
        node_label: fn id, data -> "#{data} (#{id})" end
      )

    assert String.contains?(output, "1 [label=\"Start (1)\"]")
    assert String.contains?(output, "2 [label=\"End (2)\"]")
  end

  test "custom_edge_label_dot_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: "100")

    output =
      Render.to_dot(graph,
        node_shape: "box",
        edge_label: fn weight -> "#{weight} km" end
      )

    assert String.contains?(output, "1 -> 2 [label=\"100 km\"]")
    assert String.contains?(output, "node [shape=box]")
  end

  test "highlight_single_node_dot_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")

    output =
      Render.to_dot(graph,
        options: %{highlighted_nodes: [2]}
      )

    # Node 2 should be highlighted with fillcolor
    assert String.contains?(output, "2 [label=\"2\" fillcolor=\"red\", style=filled]")

    # Node 1 should not be highlighted
    assert String.contains?(output, "1 [label=\"1\"];")
  end

  test "highlight_edges_dot_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: "5")
      |> Yog.add_edge(from: 2, to: 3, with: "10")

    output =
      Render.to_dot(graph,
        options: %{highlighted_edges: [{1, 2}]}
      )

    assert String.contains?(output, "1 -> 2 [label=\"5\" color=\"red\", penwidth=2]")

    # Edge 2->3 should not be highlighted
    assert String.contains?(output, "2 -> 3 [label=\"10\"];")
  end

  # ============= JSON Rendering Tests =============

  test "empty_directed_json_test" do
    graph = Yog.directed()
    output = Render.to_json(graph)

    assert String.contains?(output, "\"nodes\":[]")
    assert String.contains?(output, "\"edges\":[]")
  end

  test "single_node_json_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")

    output = Render.to_json(graph)

    assert String.contains?(output, "\"id\":1")
    assert String.contains?(output, "\"label\":\"Node A\"")
  end

  test "multiple_nodes_json_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_node(3, "Carol")

    output = Render.to_json(graph)

    assert String.contains?(output, "\"id\":1")
    assert String.contains?(output, "\"label\":\"Alice\"")
    assert String.contains?(output, "\"id\":2")
    assert String.contains?(output, "\"label\":\"Bob\"")
    assert String.contains?(output, "\"id\":3")
    assert String.contains?(output, "\"label\":\"Carol\"")
  end

  test "single_directed_edge_json_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_edge(from: 1, to: 2, with: "10")

    output = Render.to_json(graph)

    assert String.contains?(output, "\"source\":1")
    assert String.contains?(output, "\"target\":2")
    assert String.contains?(output, "\"weight\":\"10\"")
  end

  test "single_undirected_edge_json_test" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_edge(from: 1, to: 2, with: "10")

    output = Render.to_json(graph)

    # Should have the edge once
    assert String.contains?(output, "\"source\":1")
    assert String.contains?(output, "\"target\":2")

    # Count the occurrences of "source" field (should be 1 for undirected)
    edge_count =
      output
      |> String.split("\"source\":")
      |> length()
      |> Kernel.-(1)

    assert edge_count == 1
  end

  test "multiple_edges_json_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, with: "5")
      |> Yog.add_edge(from: 2, to: 3, with: "10")
      |> Yog.add_edge(from: 1, to: 3, with: "15")

    output = Render.to_json(graph)

    # Count the occurrences of "source" field (should be 3)
    edge_count =
      output
      |> String.split("\"source\":")
      |> length()
      |> Kernel.-(1)

    assert edge_count == 3

    # Verify all edges are present
    assert String.contains?(output, "\"weight\":\"5\"")
    assert String.contains?(output, "\"weight\":\"10\"")
    assert String.contains?(output, "\"weight\":\"15\"")
  end

  test "custom_node_mapper_json_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")

    output =
      Render.to_json(graph,
        node_mapper: fn id, data ->
          :gleam@json.object([
            {"node_id", :gleam@json.int(id)},
            {"name", :gleam@json.string(data)},
            {"type", :gleam@json.string("person")}
          ])
        end
      )

    assert String.contains?(output, "\"node_id\":1")
    assert String.contains?(output, "\"name\":\"Alice\"")
    assert String.contains?(output, "\"type\":\"person\"")
  end

  test "custom_edge_mapper_json_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge(from: 1, to: 2, with: "follows")

    output =
      Render.to_json(graph,
        edge_mapper: fn from, to, weight ->
          :gleam@json.object([
            {"from_node", :gleam@json.int(from)},
            {"to_node", :gleam@json.int(to)},
            {"relationship", :gleam@json.string(weight)}
          ])
        end
      )

    assert String.contains?(output, "\"from_node\":1")
    assert String.contains?(output, "\"to_node\":2")
    assert String.contains?(output, "\"relationship\":\"follows\"")
  end

  test "complex_graph_json_test" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_node(4, "D")
      |> Yog.add_edge(from: 1, to: 2, with: "1")
      |> Yog.add_edge(from: 1, to: 3, with: "4")
      |> Yog.add_edge(from: 2, to: 3, with: "2")
      |> Yog.add_edge(from: 2, to: 4, with: "5")
      |> Yog.add_edge(from: 3, to: 4, with: "1")

    output = Render.to_json(graph)

    # Verify all nodes are present
    assert String.contains?(output, "\"id\":1")
    assert String.contains?(output, "\"id\":4")

    # Count nodes (should be 4)
    node_count =
      output
      |> String.split("\"id\":")
      |> length()
      |> Kernel.-(1)

    assert node_count == 4

    # Count edges (should be 5)
    edge_count =
      output
      |> String.split("\"source\":")
      |> length()
      |> Kernel.-(1)

    assert edge_count == 5
  end
end
