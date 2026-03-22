defmodule Yog.MST do
  @moduledoc """
  Algorithms for Minimum Spanning Trees (MST).

  - `kruskal/1` — Kruskal's algorithm (O(E log E))
  - `prim/1` — Prim's algorithm (O(E log V))
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

    edges = :yog@mst.kruskal(graph, compare)

    Enum.map(edges, fn {:edge, from, to, weight} ->
      %{from: from, to: to, weight: weight}
    end)
  end

  @doc """
  Finds the Minimum Spanning Tree using Prim's algorithm.

  Grows MST from a starting node by repeatedly adding minimum-weight edges.

  Requires options: `:in` (graph) and `:compare` (function).

  Returns a list of `%{from: src, to: dst, weight: weight}` maps.
  """
  @spec prim(keyword()) :: [%{from: Yog.node_id(), to: Yog.node_id(), weight: term()}]
  def prim(opts) do
    graph = Keyword.fetch!(opts, :in)
    compare = Keyword.fetch!(opts, :compare)

    edges = :yog@mst.prim(graph, compare)

    Enum.map(edges, fn {:edge, from, to, weight} ->
      %{from: from, to: to, weight: weight}
    end)
  end
end
