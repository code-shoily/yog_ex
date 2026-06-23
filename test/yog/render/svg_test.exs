defmodule Yog.Render.SVGTest do
  use ExUnit.Case, async: true

  alias Yog.Layout
  alias Yog.Render.SVG

  test "generates raw XML/SVG string representing a graph" do
    graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {2, 3}])
    pos = Layout.circular(graph)

    svg = SVG.to_svg(graph, pos, width: 800, height: 600, show_labels: true)

    assert String.starts_with?(svg, "<svg")
    assert String.ends_with?(String.trim(svg), "</svg>")

    # Check that it contains standard SVG tags
    assert String.contains?(svg, "<line")
    assert String.contains?(svg, "<circle")
    assert String.contains?(svg, "<text")

    # Check for custom width/height in attributes
    assert String.contains?(svg, ~s(width="800"))
    assert String.contains?(svg, ~s(height="600"))

    # Check for scaled positions
    # Nodes are 1, 2, 3. Coordinates must be calculated.
    assert String.contains?(svg, ">1</text>")
    assert String.contains?(svg, ">2</text>")
    assert String.contains?(svg, ">3</text>")
  end

  test "handles empty graph layout" do
    svg = SVG.to_svg(Yog.undirected(), %{})
    assert String.starts_with?(svg, "<svg")
    refute String.contains?(svg, "<line")
    refute String.contains?(svg, "<circle")
  end
end
