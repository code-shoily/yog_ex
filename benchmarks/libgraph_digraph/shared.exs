# Shared helper functions for libgraph/digraph/yog benchmarks

defmodule Benchmarks.LibgraphDigraph.Shared do
  @moduledoc """
  Shared helper functions for comparing Yog, libgraph, and :digraph.
  """

  alias Yog.Generator.Random

  @doc """
  Generates comparable graphs for Yog, libgraph, and :digraph.
  Returns {yog_graph, libgraph_graph, digraph}.
  """
  def generate_graphs(n, m, type) do
    # Yog
    yog = Random.erdos_renyi_gnp_with_type(n, m / (n * (n - 1)), type, 42)

    # libgraph
    libgraph = Graph.new(type: type)
    libgraph = Enum.reduce(0..(n - 1), libgraph, fn i, g -> Graph.add_vertex(g, i) end)
    yog_edges = Yog.Model.all_edges(yog)

    libgraph =
      Enum.reduce(yog_edges, libgraph, fn {u, v, w}, g ->
        Graph.add_edge(g, u, v, weight: w)
      end)

    # :digraph
    dg = if type == :undirected, do: :digraph.new([:cyclic]), else: :digraph.new()
    Enum.each(0..(n - 1), fn i -> :digraph.add_vertex(dg, i) end)
    Enum.each(yog_edges, fn {u, v, _w} -> :digraph.add_edge(dg, u, v) end)

    if type == :undirected do
      Enum.each(yog_edges, fn {u, v, _w} -> :digraph.add_edge(dg, v, u) end)
    end

    {yog, libgraph, dg}
  end

  @doc """
  Cleans up digraph resources.
  """
  def cleanup_digraphs(digraphs) when is_list(digraphs) do
    Enum.each(digraphs, fn dg -> :digraph.delete(dg) end)
  end

  def cleanup_digraphs({_, _, dg}), do: :digraph.delete(dg)
end
