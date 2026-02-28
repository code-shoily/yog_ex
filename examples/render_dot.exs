defmodule RenderDot do
  @moduledoc """
  DOT Rendering Example

  Demonstrates exporting graphs to Graphviz format
  """

  require Yog

  def run do
    # Create a sample graph
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Start")
      |> Yog.add_node(2, "Middle")
      |> Yog.add_node(3, "End")
      |> Yog.add_edge(from: 1, to: 2, with: 5)
      |> Yog.add_edge(from: 2, to: 3, with: 3)
      |> Yog.add_edge(from: 1, to: 3, with: 10)

    # 1. Basic DOT output
    IO.puts("--- Basic DOT Output ---")
    dot_basic = Yog.Render.to_dot(graph)
    IO.puts(dot_basic)

    # 2. Find shortest path and highlight it
    IO.puts("\n--- DOT with Path Highlighting ---")

    result = Yog.Pathfinding.shortest_path(
      in: graph,
      from: 1,
      to: 3,
      zero: 0,
      add: &(&1 + &2),
      compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
    )

    case result do
      {:some, {:path, nodes, _total}} ->
        # Highlight the path
        dot_highlighted = Yog.Render.to_dot(
          graph,
          options: %{
            highlighted_nodes: nodes,
            highlighted_edges: path_to_edges(nodes)
          }
        )
        IO.puts(dot_highlighted)
        IO.puts("\nSave this output to a file and run:")
        IO.puts("  dot -Tpng -o graph.png graph.dot")

      :none ->
        IO.puts("No path found")
    end
  end

  defp path_to_edges([]), do: []
  defp path_to_edges([_]), do: []
  defp path_to_edges([a, b | rest]) do
    [{a, b} | path_to_edges([b | rest])]
  end
end

RenderDot.run()
