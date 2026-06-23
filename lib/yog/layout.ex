defmodule Yog.Layout do
  @moduledoc """
  Algorithms for calculating 2D coordinates for graph nodes.

  Calculates coordinates mapping node IDs to `{x, y}` float coordinate tuples.
  These coordinates can be used for rendering graphs visually via custom SVG elements,
  exporting data for web dashboards (using Cytoscape.js or D3.js), or generating layouts.

  ## Overview

  | Algorithm | Function | Mathematical Model | Best For | Time Complexity |
  |-----------|----------|--------------------|----------|-----------------|
  | **Circular** | `circular/2` | Uniform spacing on unit circle | Symmetric/small graphs, cycles | $O(V)$ |
  | **Random** | `random/2` | Uniform distribution in bounding box | Initial states, baseline checks | $O(V)$ |
  | **Spring** | `spring/2` | Fruchterman-Reingold force model | Social networks, general graphs | $O(I \\cdot (V^2 + E))$ |

  ## Graph Layout Visualization (Spring vs. Circular)

  The layout determines the structural aesthetic. Spring layout cluster connected nodes together, whereas Circular layout focuses purely on ordering.

  <div class="graphviz">
  graph LayoutComparison {
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];

    subgraph cluster_spring {
      label="Spring (Force-Directed)";
      color="#10b981";
      s1 -- s2; s2 -- s3; s3 -- s1;
      s1 -- s4; s4 -- s5; s5 -- s1;
    }

    subgraph cluster_circular {
      label="Circular";
      color="#3b82f6";
      c1 -- c2 -- c3 -- c4 -- c5 -- c1;
    }
  }
  </div>

  ## Usage Example

  Below is an example showing how layout coordinates can be mapped directly to generate
  a visual representation:

      iex> graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {2, 3}])
      iex> pos = Yog.Layout.circular(graph, radius: 10.0)
      iex> Map.keys(pos) |> Enum.sort()
      [1, 2, 3]

  """

  alias Yog.Graph
  alias Yog.Layout.Circular
  alias Yog.Layout.Random
  alias Yog.Layout.Spring

  @doc """
  Positions nodes uniformly spaced on a circle.

  Delegates to `Yog.Layout.Circular.layout/2`.
  """
  @spec circular(Graph.t(), keyword()) :: %{Graph.node_id() => {float(), float()}}
  def circular(graph, opts \\ []) do
    Circular.layout(graph, opts)
  end

  @doc """
  Positions nodes randomly within a specified bounding box.

  Delegates to `Yog.Layout.Random.layout/2`.
  """
  @spec random(Graph.t(), keyword()) :: %{Graph.node_id() => {float(), float()}}
  def random(graph, opts \\ []) do
    Random.layout(graph, opts)
  end

  @doc """
  Positions nodes using a spring/force-directed model (Fruchterman-Reingold).

  Delegates to `Yog.Layout.Spring.layout/2`.
  """
  @spec spring(Graph.t(), keyword()) :: %{Graph.node_id() => {float(), float()}}
  def spring(graph, opts \\ []) do
    Spring.layout(graph, opts)
  end
end
