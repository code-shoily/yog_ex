defmodule Yog.Zog do
  @moduledoc """
  Native graph algorithms via Zog (Zig) and Zigler.

  This module provides conversion functions between Yog's Elixir graph
  structures and the flat-array format consumed by Zog's native SoA
  `ArrayGraph`.

  ## Workflow

  1. Build or convert a graph using `Zog`.
  2. Pass it directly to a module under `Yog.Zog.*` (e.g.
     `Yog.Zog.Centrality.betweenness_unweighted/1`).
  3. Results are returned with original labels restored automatically.

  ## Conversion helpers

      # From an existing Yog.Graph
      builder = Yog.Zog.from_graph(my_graph)

      # From a Labeled builder
      builder = Yog.Zog.from_labeled(labeled_builder)

      # Back to a Yog.Graph
      graph = Yog.Zog.to_graph(builder)

  """
  alias Yog.Builder.Zog

  @doc """
  Converts a `Yog.Graph` into a `Zog`.
  """
  @spec from_graph(Yog.graph()) :: Zog.t()
  def from_graph(graph), do: Zog.from_graph(graph)

  @doc """
  Converts a `Yog.Builder.Labeled` into a `Zog`.
  """
  @spec from_labeled(Yog.Builder.Labeled.t()) :: Zog.t()
  def from_labeled(labeled), do: Zog.from_labeled(labeled)

  @doc """
  Converts a `Zog` back into a `Yog.Graph`.
  """
  @spec to_graph(Zog.t()) :: Yog.graph()
  def to_graph(builder), do: Zog.to_graph(builder)
end
