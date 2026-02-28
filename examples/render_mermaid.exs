defmodule RenderMermaid do
  @moduledoc """
  Mermaid Rendering Example

  Demonstrates generating Mermaid diagrams
  """

  require Yog

  def run do
    # Create a sample graph
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Home")
      |> Yog.add_node(2, "Gym")
      |> Yog.add_node(3, "Office")
      |> Yog.add_edge(from: 1, to: 2, weight: 10)
      |> Yog.add_edge(from: 2, to: 3, weight: 5)
      |> Yog.add_edge(from: 1, to: 3, weight: 20)

    # 1. Basic Mermaid output
    IO.puts("--- Basic Mermaid Output ---")
    mermaid_basic = Yog.Render.to_mermaid(graph)
    IO.puts("```mermaid")
    IO.puts(mermaid_basic)
    IO.puts("```")

    # 2. Mermaid with path visualization
    IO.puts("\n--- Finding Shortest Path ---")

    result = Yog.Pathfinding.shortest_path(
      in: graph,
      from: 1,
      to: 3,
      zero: 0,
      add: &(&1 + &2),
      compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
    )

    case result do
      {:some, {:path, _nodes, total_weight}} ->
        IO.puts("Shortest path found with total weight: #{total_weight} km")
        IO.puts("(Path highlighting can be added via Mermaid CSS classes)")

      :none ->
        IO.puts("No path found")
    end

    IO.puts("\nTip: Paste the output into a GitHub markdown file or")
    IO.puts("the Mermaid Live Editor (https://mermaid.live/) to see it rendered.")
  end
end

RenderMermaid.run()
