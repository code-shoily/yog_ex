defmodule Yog.Property.Eulerian do
  @moduledoc """
  Algorithms for checking Eulerian circuits and paths.
  """

  @doc """
  Checks if the graph contains an Eulerian circuit.
  """
  @spec has_eulerian_circuit?(Yog.graph()) :: boolean()
  def has_eulerian_circuit?(graph), do: :yog@property@eulerian.has_eulerian_circuit(graph)

  @doc """
  Checks if the graph contains an Eulerian path.
  """
  @spec has_eulerian_path?(Yog.graph()) :: boolean()
  def has_eulerian_path?(graph), do: :yog@property@eulerian.has_eulerian_path(graph)

  @doc """
  Finds an Eulerian circuit in the graph if it exists.
  """
  @spec eulerian_circuit(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, any()}
  def eulerian_circuit(graph) do
    case :yog@property@eulerian.find_eulerian_circuit(graph) do
      {:some, circuit} -> {:ok, circuit}
      :none -> {:error, :no_eulerian_circuit}
    end
  end

  defdelegate find_eulerian_circuit(graph), to: __MODULE__, as: :eulerian_circuit

  @doc """
  Finds an Eulerian path in the graph if it exists.
  """
  @spec eulerian_path(Yog.graph()) :: {:ok, [Yog.node_id()]} | {:error, any()}
  def eulerian_path(graph) do
    case :yog@property@eulerian.find_eulerian_path(graph) do
      {:some, path} -> {:ok, path}
      :none -> {:error, :no_eulerian_path}
    end
  end

  defdelegate find_eulerian_path(graph), to: __MODULE__, as: :eulerian_path
end

defmodule Yog.Eulerian do
  @moduledoc "Deprecated. Use `Yog.Property.Eulerian` instead."
  defdelegate has_eulerian_circuit?(graph), to: Yog.Property.Eulerian
  defdelegate has_eulerian_path?(graph), to: Yog.Property.Eulerian
  defdelegate eulerian_circuit(graph), to: Yog.Property.Eulerian
  defdelegate find_eulerian_circuit(graph), to: Yog.Property.Eulerian
  defdelegate eulerian_path(graph), to: Yog.Property.Eulerian
  defdelegate find_eulerian_path(graph), to: Yog.Property.Eulerian
end
