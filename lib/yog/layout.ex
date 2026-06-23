defmodule Yog.Layout do
  @moduledoc """
  Algorithms for calculating 2D coordinates for graph nodes.

  Calculates coordinates mapping node IDs to `{x, y}` float coordinate tuples.
  Useful for rendering graphs visually via SVG or other graphical frontends.
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
