defmodule Yog.Connectivity do
  @moduledoc """
  Algorithms for graph connectivity analysis, finding bridges, articulation points,
  and strongly connected components.
  """

  @type bridge :: {Yog.node_id(), Yog.node_id()}
  @type connectivity_results :: %{
          bridges: [bridge()],
          articulation_points: [Yog.node_id()]
        }

  @doc """
  Analyzes an **undirected graph** to find all bridges and articulation points
  using Tarjan's bridge-finding in a single DFS pass.

  Bridges are edges whose removal increases the number of connected components.
  Articulation points (cut vertices) are nodes whose removal increases it.
  """
  @spec analyze(keyword()) :: connectivity_results()
  def analyze(options \\ []) do
    graph = Keyword.fetch!(options, :in)
    {:connectivity_results, bridges, points} = :yog@connectivity.analyze(graph)
    %{bridges: bridges, articulation_points: points}
  end

  @doc """
  Finds the Strongly Connected Components (SCC) of a directed graph using
  Tarjan's algorithm. O(V + E) linear time.
  """
  @spec strongly_connected_components(Yog.graph()) :: [[Yog.node_id()]]
  defdelegate strongly_connected_components(graph), to: :yog@connectivity

  defdelegate scc(graph), to: :yog@connectivity, as: :strongly_connected_components

  @doc """
  Finds the Strongly Connected Components (SCC) using Kosaraju's algorithm.
  Two-pass DFS; transposes graph; O(V + E) linear time.
  """
  @spec kosaraju(Yog.graph()) :: [[Yog.node_id()]]
  defdelegate kosaraju(graph), to: :yog@connectivity
end
