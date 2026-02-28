defmodule Yog.TopologicalSort do
  @moduledoc """
  Algorithms for topological sorting of directed acyclic graphs (DAGs).
  """

  @doc """
  Performs a standard topological sort using Kahn's algorithm.

  Returns `{:ok, [node_ids]}` if the graph is a DAG, or `{:error, :contains_cycle}` if
  the graph has a cycle (and therefore cannot be topologically sorted).
  """
  @spec sort(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def sort(graph) do
    case :yog@topological_sort.topological_sort(graph) do
      {:ok, order} -> {:ok, order}
      {:error, nil} -> {:error, :contains_cycle}
    end
  end

  @doc """
  Performs a lexicographical topological sort.

  When multiple nodes are available to be placed next in the sorted order, this
  variant strictly prefers the node with the "smallest" ID based on the provided
  `compare` function.
  """
  @spec lexicographical_sort(Yog.graph(), fun()) ::
          {:ok, [Yog.node_id()]} | {:error, :contains_cycle}
  def lexicographical_sort(graph, compare_fn) do
    case :yog@topological_sort.lexicographical_topological_sort(graph, compare_fn) do
      {:ok, order} -> {:ok, order}
      {:error, nil} -> {:error, :contains_cycle}
    end
  end
end
