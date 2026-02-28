defmodule Yog.MST do
  @moduledoc """
  Algorithms for Minimum Spanning Trees (MST).
  """

  @doc """
  Finds the Minimum Spanning Tree of an undirected graph using Kruskal's algorithm.

  Requires options: `:in` (graph) and `:compare` (function).

  Returns a list of `%{from: src, to: dst, weight: weight}` maps.
  """
  @spec kruskal(keyword()) :: [%{from: Yog.node_id(), to: Yog.node_id(), weight: term()}]
  def kruskal(opts) do
    graph = Keyword.fetch!(opts, :in)
    compare = Keyword.fetch!(opts, :compare)

    # Calling the internal MST solver which uses DisjointSets
    # Returns List(#(NodeId, NodeId, e)) or similar Edge record
    edges = :yog@mst.kruskal(graph, compare)

    Enum.map(edges, fn {:edge, from, to, weight} ->
      %{from: from, to: to, weight: weight}
    end)
  end
end
