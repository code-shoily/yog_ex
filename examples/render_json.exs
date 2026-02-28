defmodule RenderJson do
  @moduledoc """
  JSON Rendering Example

  Demonstrates exporting graphs to JSON for web use
  """

  require Yog

  def run do
    # Create a simple directed graph
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node A")
      |> Yog.add_node(2, "Node B")
      |> Yog.add_edge(from: 1, to: 2, with: "connects")

    # Basic JSON rendering
    IO.puts("--- Basic JSON Rendering ---")
    json_basic = Yog.Render.to_json(graph)
    IO.puts(json_basic)

    IO.puts("\nThis JSON can be used with D3.js, Cytoscape.js, or other visualization libraries.")
    IO.puts("For custom node/edge formats, you can process the JSON output with your own mappers.")
  end
end

RenderJson.run()
