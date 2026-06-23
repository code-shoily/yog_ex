defmodule Yog.Render.SVGTest do
  use ExUnit.Case, async: true

  doctest Yog.Render.SVG

  alias Yog.Layout
  alias Yog.Render.SVG

  test "generates raw XML/SVG string representing a graph" do
    graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {2, 3}])
    pos = Layout.circular(graph)

    svg = SVG.to_svg(graph, pos, width: 800, height: 600, show_labels: true)

    assert String.starts_with?(svg, "<svg")
    assert String.ends_with?(String.trim(svg), "</svg>")

    # Check that it contains standard SVG tags
    assert String.contains?(svg, "<path")
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
    refute String.contains?(svg, "<path")
    refute String.contains?(svg, "<circle")
  end

  test "supports directed graphs with arrow markers and path shortening" do
    graph = Yog.from_unweighted_edges(:directed, [{1, 2}])
    pos = Layout.circular(graph)

    svg = SVG.to_svg(graph, pos)

    assert String.contains?(svg, "<defs>")
    assert String.contains?(svg, "<marker id=\"arrow\"")
    assert String.contains?(svg, "marker-end=\"url(#arrow)\"")
  end

  test "supports multigraph layouts with curvy edges and self-loops" do
    multi = Yog.Multi.undirected()
    multi = Yog.Multi.add_node(multi, 1)
    multi = Yog.Multi.add_node(multi, 2)
    {multi, _} = Yog.Multi.add_edge(multi, 1, 2, nil)
    # parallel edge
    {multi, _} = Yog.Multi.add_edge(multi, 1, 2, nil)
    # self-loop
    {multi, _} = Yog.Multi.add_edge(multi, 1, 1, nil)

    # Layout computed on simple graph version
    simple = Yog.Multi.to_simple_graph(multi)
    pos = Layout.circular(simple)

    svg = SVG.to_svg(multi, pos)

    # Must contain path definitions
    assert String.contains?(svg, "<path")

    # Check for presence of curve indicators: Q for quadratic curves, C for cubic loops
    assert String.contains?(svg, " Q ")
    assert String.contains?(svg, " C ")
  end
end
