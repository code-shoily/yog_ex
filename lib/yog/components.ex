defmodule Yog.Components do
  @moduledoc """
  Algorithms for finding connected components.
  Deprecated. Use `Yog.Connectivity` instead.
  """
  defdelegate scc(graph), to: Yog.Connectivity
  defdelegate strongly_connected_components(graph), to: Yog.Connectivity
  defdelegate kosaraju(graph), to: Yog.Connectivity
end
