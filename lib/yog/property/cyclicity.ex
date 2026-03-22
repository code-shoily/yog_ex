defmodule Yog.Property.Cyclicity do
  @moduledoc """
  Graph cyclicity and Directed Acyclic Graph (DAG) analysis.
  """

  @doc """
  Checks if the graph is a Directed Acyclic Graph (DAG) or has no cycles if undirected.
  """
  @spec acyclic?(Yog.graph()) :: boolean()
  defdelegate acyclic?(graph), to: Yog.Traversal, as: :is_acyclic

  @doc """
  Checks if the graph contains at least one cycle.
  """
  @spec cyclic?(Yog.graph()) :: boolean()
  defdelegate cyclic?(graph), to: Yog.Traversal, as: :is_cyclic
end
