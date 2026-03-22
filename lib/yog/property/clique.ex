defmodule Yog.Property.Clique do
  @moduledoc """
  Algorithms for clique finding in graphs.
  """

  @doc """
  Finds the maximum clique in an undirected graph (largest subset of nodes where
  all nodes connect to each other).
  """
  @spec max_clique(Yog.graph()) :: MapSet.t(Yog.node_id())
  def max_clique(graph) do
    :yog@property@clique.max_clique(graph) |> :gleam@set.to_list() |> MapSet.new()
  end

  @doc """
  Finds all maximal cliques using the Bron-Kerbosch algorithm (optimized with pivoting).
  """
  @spec all_maximal_cliques(Yog.graph()) :: [MapSet.t(Yog.node_id())]
  def all_maximal_cliques(graph) do
    :yog@property@clique.all_maximal_cliques(graph)
    |> Enum.map(fn cl -> cl |> :gleam@set.to_list() |> MapSet.new() end)
  end

  @doc """
  Finds all cliques of size k.
  """
  @spec k_cliques(Yog.graph(), integer()) :: [MapSet.t(Yog.node_id())]
  def k_cliques(graph, k) do
    :yog@property@clique.k_cliques(graph, k)
    |> Enum.map(fn cl -> cl |> :gleam@set.to_list() |> MapSet.new() end)
  end
end

defmodule Yog.Clique do
  @moduledoc "Deprecated. Use `Yog.Property.Clique` instead."
  defdelegate max_clique(graph), to: Yog.Property.Clique
  defdelegate all_maximal_cliques(graph), to: Yog.Property.Clique
  defdelegate k_cliques(graph, k), to: Yog.Property.Clique
end
