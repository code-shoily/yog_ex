defmodule Yog.Components do
  @moduledoc """
  Algorithms for finding connected components in graphs.
  """

  @doc """
  Finds the Strongly Connected Components (SCC) of a directed graph using
  Tarjan's strongly connected components algorithm.

  Returns a list of components, where each component is a list of its node IDs.
  The components are returned in reverse topological order.
  """
  @spec scc(Yog.graph()) :: [[Yog.node_id()]]
  def scc(graph) do
    :yog@components.strongly_connected_components(graph)
  end
end
