defmodule Yog.Pathfinding.Path do
  @moduledoc """
  Result of pathfinding algorithms (Dijkstra, A*, BFS, etc.).

  Represents a path through the graph as a sequence of nodes with
  a total weight and metadata about how the path was found.

  ## Fields

  - `nodes` - Ordered list of node IDs forming the path
  - `weight` - Total weight/cost of the path
  - `algorithm` - Name of the algorithm used (optional)
  - `metadata` - Optional metadata (visited nodes, iterations, time, etc.)

  ## Examples

      iex> path = %Yog.Pathfinding.Path{
      ...>   nodes: [1, 2, 3, 4],
      ...>   weight: 15.5,
      ...>   algorithm: :dijkstra
      ...> }
      iex> path.weight
      15.5
      iex> Yog.Pathfinding.Path.length(path)
      3
      iex> Yog.Pathfinding.Path.start(path)
      1
      iex> Yog.Pathfinding.Path.finish(path)
      4
  """

  @enforce_keys [:nodes, :weight]
  defstruct [:nodes, :weight, algorithm: :unknown, metadata: %{}]

  @type t :: %__MODULE__{
          nodes: [Yog.Model.node_id()],
          weight: any(),
          algorithm: atom(),
          metadata: map()
        }

  @doc """
  Creates a new path result.

  ## Examples

      iex> path = Yog.Pathfinding.Path.new([1, 2, 3], 10)
      iex> path.nodes
      [1, 2, 3]
      iex> path.weight
      10
  """
  @spec new([Yog.Model.node_id()], any()) :: t()
  def new(nodes, weight) when is_list(nodes) do
    %__MODULE__{
      nodes: nodes,
      weight: weight
    }
  end

  @doc """
  Creates a new path result with algorithm name.

  ## Examples

      iex> path = Yog.Pathfinding.Path.new([1, 2, 3], 10, :dijkstra)
      iex> path.algorithm
      :dijkstra
  """
  @spec new([Yog.Model.node_id()], any(), atom()) :: t()
  def new(nodes, weight, algorithm)
      when is_list(nodes) and is_atom(algorithm) do
    %__MODULE__{
      nodes: nodes,
      weight: weight,
      algorithm: algorithm
    }
  end

  @doc """
  Creates a new path result with algorithm and metadata.

  ## Examples

      iex> path = Yog.Pathfinding.Path.new([1, 2, 3], 10, :astar, %{visited: 42})
      iex> path.metadata
      %{visited: 42}
  """
  @spec new([Yog.Model.node_id()], any(), atom(), map()) :: t()
  def new(nodes, weight, algorithm, metadata)
      when is_list(nodes) and is_atom(algorithm) and is_map(metadata) do
    %__MODULE__{
      nodes: nodes,
      weight: weight,
      algorithm: algorithm,
      metadata: metadata
    }
  end

  @doc """
  Checks if the path is empty (contains no nodes).

  ## Examples

      iex> path = Yog.Pathfinding.Path.new([], 0)
      iex> Yog.Pathfinding.Path.empty?(path)
      true
      iex> path = Yog.Pathfinding.Path.new([1, 2], 5)
      iex> Yog.Pathfinding.Path.empty?(path)
      false
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{nodes: nodes}), do: nodes == []

  @doc """
  Returns the length of the path (number of edges).

  The length is the number of nodes minus 1. An empty path or
  single-node path has length 0.

  ## Examples

      iex> path = Yog.Pathfinding.Path.new([1, 2, 3, 4], 15)
      iex> Yog.Pathfinding.Path.length(path)
      3
      iex> path = Yog.Pathfinding.Path.new([1], 0)
      iex> Yog.Pathfinding.Path.length(path)
      0
      iex> path = Yog.Pathfinding.Path.new([], 0)
      iex> Yog.Pathfinding.Path.length(path)
      0
  """
  @spec length(t()) :: non_neg_integer()
  def length(%__MODULE__{nodes: nodes}) do
    max(0, Kernel.length(nodes) - 1)
  end

  @doc """
  Returns the starting node of the path.

  Returns `nil` if the path is empty.

  ## Examples

      iex> path = Yog.Pathfinding.Path.new([1, 2, 3], 10)
      iex> Yog.Pathfinding.Path.start(path)
      1
      iex> path = Yog.Pathfinding.Path.new([], 0)
      iex> Yog.Pathfinding.Path.start(path)
      nil
  """
  @spec start(t()) :: Yog.Model.node_id() | nil
  def start(%__MODULE__{nodes: []}), do: nil
  def start(%__MODULE__{nodes: [first | _]}), do: first

  @doc """
  Returns the ending node of the path.

  Returns `nil` if the path is empty.

  ## Examples

      iex> path = Yog.Pathfinding.Path.new([1, 2, 3], 10)
      iex> Yog.Pathfinding.Path.finish(path)
      3
      iex> path = Yog.Pathfinding.Path.new([], 0)
      iex> Yog.Pathfinding.Path.finish(path)
      nil
  """
  @spec finish(t()) :: Yog.Model.node_id() | nil
  def finish(%__MODULE__{nodes: []}), do: nil
  def finish(%__MODULE__{nodes: nodes}), do: List.last(nodes)

  @doc """
  Reverses the path (both node order and preserves weight).

  ## Examples

      iex> path = Yog.Pathfinding.Path.new([1, 2, 3], 10, :dijkstra)
      iex> reversed = Yog.Pathfinding.Path.reverse(path)
      iex> reversed.nodes
      [3, 2, 1]
      iex> reversed.weight
      10
      iex> reversed.algorithm
      :dijkstra
  """
  @spec reverse(t()) :: t()
  def reverse(%__MODULE__{nodes: nodes, weight: weight, algorithm: algo, metadata: meta}) do
    %__MODULE__{
      nodes: Enum.reverse(nodes),
      weight: weight,
      algorithm: algo,
      metadata: meta
    }
  end

  @doc """
  Creates a path from the legacy tuple format `{:path, nodes, weight}`.

  ## Examples

      iex> path = Yog.Pathfinding.Path.from_tuple({:path, [1, 2, 3], 10})
      iex> path.nodes
      [1, 2, 3]
      iex> path.weight
      10
  """
  @spec from_tuple({:path, [Yog.Model.node_id()], any()}) :: t()
  def from_tuple({:path, nodes, weight}) when is_list(nodes) do
    new(nodes, weight)
  end

  @doc """
  Converts the path to a legacy tuple format `{:path, nodes, weight}`.

  ## Examples

      iex> path = Yog.Pathfinding.Path.new([1, 2, 3], 10)
      iex> Yog.Pathfinding.Path.to_tuple(path)
      {:path, [1, 2, 3], 10}
  """
  @spec to_tuple(t()) :: {:path, [Yog.Model.node_id()], any()}
  def to_tuple(%__MODULE__{nodes: nodes, weight: weight}) do
    {:path, nodes, weight}
  end

  @doc """
  Backward compatibility: convert from legacy map format.
  """
  @spec from_map(map()) :: t()
  def from_map(%{nodes: n, weight: w} = map) do
    algorithm = Map.get(map, :algorithm, :unknown)
    metadata = Map.get(map, :metadata, %{})

    %__MODULE__{
      nodes: n,
      weight: w,
      algorithm: algorithm,
      metadata: metadata
    }
  end

  @doc """
  Convert to legacy map format.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{nodes: nodes, weight: weight}) do
    %{
      nodes: nodes,
      weight: weight
    }
  end

  @doc """
  Checks if a node is part of the path.

  ## Examples

      iex> path = Yog.Pathfinding.Path.new([1, 2, 3], 10)
      iex> Yog.Pathfinding.Path.contains?(path, 2)
      true
      iex> Yog.Pathfinding.Path.contains?(path, 5)
      false
  """
  @spec contains?(t(), Yog.Model.node_id()) :: boolean()
  def contains?(%__MODULE__{nodes: nodes}, node_id) do
    node_id in nodes
  end

  @doc """
  Returns the node at a specific position in the path (0-indexed).

  Returns `nil` if the index is out of bounds.

  ## Examples

      iex> path = Yog.Pathfinding.Path.new([1, 2, 3], 10)
      iex> Yog.Pathfinding.Path.at(path, 0)
      1
      iex> Yog.Pathfinding.Path.at(path, 2)
      3
      iex> Yog.Pathfinding.Path.at(path, 5)
      nil
  """
  @spec at(t(), non_neg_integer()) :: Yog.Model.node_id() | nil
  def at(%__MODULE__{nodes: nodes}, index) when is_integer(index) and index >= 0 do
    Enum.at(nodes, index)
  end

  @doc """
  Hydrates a path of node IDs with their corresponding edge attributes from the graph.

  This function transforms a list of node IDs representing a path (e.g., `[A, B, C]`)
  into a list of edge triplets `{u, v, data}` by looking up the edge
  metadata for each consecutive pair in the graph.

  This is particularly useful when you have a sequence of nodes (from a pathfinding
  algorithm) and you need to "hydrate" it with the actual edge weights or
  attributes used to traverse it.

  ## Examples

      iex> graph =
      ...>   Yog.directed()
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 10, default: nil)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 5, default: nil)
      iex> path = [1, 2, 3]
      iex> Yog.Pathfinding.Path.hydrate_path(graph, path)
      [{1, 2, 10}, {2, 3, 5}]

  """
  @spec hydrate_path(Yog.Model.graph(), [Yog.Model.node_id()]) :: list()
  def hydrate_path(graph, node_ids) do
    node_ids
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [u, v] ->
      {u, v, Yog.Model.edge_data(graph, u, v)}
    end)
  end
end
