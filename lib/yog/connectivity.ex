defmodule Yog.Connectivity do
  @moduledoc """
  Graph connectivity analysis routines.
  """

  @type bridge :: {Yog.node_id(), Yog.node_id()}
  @type connectivity_results :: %{
          bridges: [bridge()],
          articulation_points: [Yog.node_id()]
        }

  @doc """
  Finds bridges and articulation points in an **undirected** graph using Tarjan's
  bridge-finding algorithm.

  A bridge is an edge whose removal disconnected the graph.
  An articulation point (cut vertex) is a node whose removal disconnects the graph.

  Returns a map containing lists of `:bridges` and `:articulation_points`.
  """
  @spec analyze(Keyword.t()) :: connectivity_results()
  def analyze(options \\ []) do
    graph = Keyword.fetch!(options, :in)
    {:connectivity_results, bridges, points} = :yog@connectivity.analyze(graph)
    %{bridges: bridges, articulation_points: points}
  end
end
