defmodule Yog.Eulerian do
  @moduledoc """
  Algorithms for Eulerian paths and circuits.
  """

  @doc """
  Checks if the graph has an Eulerian circuit (a path that visits every edge exactly once and returns to the start).
  """
  @spec has_eulerian_circuit?(Yog.graph()) :: boolean()
  def has_eulerian_circuit?(graph) do
    :yog@eulerian.has_eulerian_circuit(graph)
  end

  @doc """
  Checks if the graph has an Eulerian path (visits every edge exactly once, but may not return to start).
  """
  @spec has_eulerian_path?(Yog.graph()) :: boolean()
  def has_eulerian_path?(graph) do
    :yog@eulerian.has_eulerian_path(graph)
  end

  @doc """
  Finds an Eulerian path in the graph, if one exists.

  Returns `{:ok, path_of_node_ids}` or `{:error, :no_eulerian_path}`.
  """
  @spec find_eulerian_path(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, :no_eulerian_path}
  def find_eulerian_path(graph) do
    case :yog@eulerian.find_eulerian_path(graph) do
      {:some, path} -> {:ok, path}
      :none -> {:error, :no_eulerian_path}
    end
  end

  @doc """
  Finds an Eulerian path or raises if one does not exist.
  """
  @spec find_eulerian_path!(Yog.graph()) :: [Yog.node_id()]
  def find_eulerian_path!(graph) do
    case find_eulerian_path(graph) do
      {:ok, path} -> path
      {:error, :no_eulerian_path} -> raise "Graph does not contain an Eulerian path."
    end
  end

  @doc """
  Finds an Eulerian circuit in the graph, if one exists.

  Returns `{:ok, path_of_node_ids}` or `{:error, :no_eulerian_circuit}`.
  """
  @spec find_eulerian_circuit(Yog.graph()) ::
          {:ok, [Yog.node_id()]} | {:error, :no_eulerian_circuit}
  def find_eulerian_circuit(graph) do
    case :yog@eulerian.find_eulerian_circuit(graph) do
      {:some, path} -> {:ok, path}
      :none -> {:error, :no_eulerian_circuit}
    end
  end

  @doc """
  Finds an Eulerian circuit or raises if one does not exist.
  """
  @spec find_eulerian_circuit!(Yog.graph()) :: [Yog.node_id()]
  def find_eulerian_circuit!(graph) do
    case find_eulerian_circuit(graph) do
      {:ok, path} -> path
      {:error, :no_eulerian_circuit} -> raise "Graph does not contain an Eulerian circuit."
    end
  end
end
