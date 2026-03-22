defmodule Yog.Property.Bipartite do
  @moduledoc """
  Algorithms for checking bipartiteness and 2-coloring graphs.
  """

  @doc """
  Determines if a graph is bipartite (2-colorable).
  Works for both directed and undirected graphs.
  """
  @spec bipartite?(Yog.graph()) :: boolean()
  def bipartite?(graph), do: :yog@property@bipartite.is_bipartite(graph)

  @doc """
  Returns the two partitions of a bipartite graph, or nil if not bipartite.
  """
  @spec partition(Yog.graph()) ::
          {:ok, %{left: MapSet.t(), right: MapSet.t()}} | {:error, :not_bipartite}
  def partition(graph) do
    case :yog@property@bipartite.partition(graph) do
      {:some, {:partition, left, right}} ->
        {:ok,
         %{
           left: left |> :gleam@set.to_list() |> MapSet.new(),
           right: right |> :gleam@set.to_list() |> MapSet.new()
         }}

      :none ->
        {:error, :not_bipartite}
    end
  end

  @doc """
  Finds a 2-coloring of a graph if it is bipartite.
  """
  @spec coloring(Yog.graph()) :: {:ok, map()} | {:error, :not_bipartite}
  def coloring(graph) do
    case partition(graph) do
      {:ok, %{left: left, right: right}} ->
        left_map = Map.new(left, fn id -> {id, 0} end)
        right_map = Map.new(right, fn id -> {id, 1} end)
        {:ok, Map.merge(left_map, right_map)}

      {:error, _} ->
        {:error, :not_bipartite}
    end
  end

  @doc """
  Finds a maximum matching in a bipartite graph.
  """
  @spec maximum_matching(Yog.graph(), %{left: MapSet.t(), right: MapSet.t()}) :: [
          {Yog.node_id(), Yog.node_id()}
        ]
  def maximum_matching(graph, partition_map) do
    left = partition_map.left |> MapSet.to_list() |> :gleam@set.from_list()
    right = partition_map.right |> MapSet.to_list() |> :gleam@set.from_list()
    gleam_partition = {:partition, left, right}

    :yog@property@bipartite.maximum_matching(graph, gleam_partition)
    |> Enum.map(fn {u, v} -> {u, v} end)
  end

  @doc """
  Finds a stable matching given preference lists for two groups.
  Returns a map of matches (bidirectional).
  """
  def stable_marriage(left_prefs, right_prefs) when is_map(left_prefs) and is_map(right_prefs) do
    {:stable_marriage, matches} = :yog@property@bipartite.stable_marriage(left_prefs, right_prefs)
    matches
  end

  def stable_marriage(opts) when is_list(opts) do
    left = Keyword.fetch!(opts, :left_prefs)
    right = Keyword.fetch!(opts, :right_prefs)
    stable_marriage(left, right)
  end

  @doc """
  Gets the partner of a person in a stable matching.
  """
  def get_partner(matches, person) when is_map(matches) do
    Map.get(matches, person)
  end

  def get_partner({:stable_marriage, matches}, person) do
    Map.get(matches, person)
  end
end

defmodule Yog.Bipartite do
  @moduledoc "Deprecated. Use `Yog.Property.Bipartite` instead."
  defdelegate bipartite?(graph), to: Yog.Property.Bipartite
  defdelegate coloring(graph), to: Yog.Property.Bipartite
  defdelegate partition(graph), to: Yog.Property.Bipartite
  defdelegate maximum_matching(graph, partition), to: Yog.Property.Bipartite
  defdelegate stable_marriage(opts), to: Yog.Property.Bipartite
  defdelegate stable_marriage(l, r), to: Yog.Property.Bipartite
  defdelegate get_partner(marriage, person), to: Yog.Property.Bipartite
end
