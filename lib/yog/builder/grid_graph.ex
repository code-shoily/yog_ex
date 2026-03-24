defmodule Yog.Builder.GridGraph do
  @moduledoc """
  Grid graph builder result.

  A grid graph is a structured graph where nodes are arranged in a 2D grid
  with edges connecting adjacent cells according to a specified topology.

  ## Fields

  - `graph` - The underlying Yog graph
  - `rows` - Number of rows in the grid
  - `cols` - Number of columns in the grid
  - `topology` - Connection pattern (`:rook`, `:queen`, `:king`, etc.)
  - `predicate` - Optional function to filter valid cells

  ## Topologies

  - `:rook` - 4-connected (up, down, left, right)
  - `:queen` - 8-connected (rook + diagonals)
  - `:king` - Same as queen
  - `:bishop` - Diagonal connections only

  ## Examples

      iex> grid = %Yog.Builder.GridGraph{
      ...>   graph: graph,
      ...>   rows: 3,
      ...>   cols: 3,
      ...>   topology: :rook
      ...> }
      iex> grid.rows
      3
      iex> Yog.Builder.GridGraph.coord_to_id(grid, 0, 0)
      0
  """

  @enforce_keys [:graph, :rows, :cols]
  defstruct [:graph, :rows, :cols, topology: :rook, predicate: nil]

  @type t :: %__MODULE__{
          graph: Yog.graph(),
          rows: non_neg_integer(),
          cols: non_neg_integer(),
          topology: atom(),
          predicate: (non_neg_integer(), non_neg_integer() -> boolean()) | nil
        }

  @doc """
  Creates a new grid graph result.

  ## Examples

      iex> graph = Yog.undirected()
      iex> grid = Yog.Builder.GridGraph.new(graph, 3, 4)
      iex> grid.rows
      3
      iex> grid.cols
      4
      iex> grid.topology
      :rook
  """
  @spec new(Yog.graph(), non_neg_integer(), non_neg_integer()) :: t()
  def new(graph, rows, cols) do
    %__MODULE__{
      graph: graph,
      rows: rows,
      cols: cols
    }
  end

  @doc """
  Creates a new grid graph result with topology.

  ## Examples

      iex> graph = Yog.undirected()
      iex> grid = Yog.Builder.GridGraph.new(graph, 3, 4, :queen)
      iex> grid.topology
      :queen
  """
  @spec new(Yog.graph(), non_neg_integer(), non_neg_integer(), atom()) :: t()
  def new(graph, rows, cols, topology) do
    %__MODULE__{
      graph: graph,
      rows: rows,
      cols: cols,
      topology: topology
    }
  end

  @doc """
  Unwraps the grid graph to return the plain graph.

  ## Examples

      iex> grid = %Yog.Builder.GridGraph{graph: graph, rows: 2, cols: 2}
      iex> Yog.Builder.GridGraph.to_graph(grid)
      graph
  """
  @spec to_graph(t()) :: Yog.graph()
  def to_graph(%__MODULE__{graph: graph}), do: graph

  @doc """
  Gets the cell data at a specific grid coordinate.

  Returns `{:ok, data}` if the cell exists, or `{:error, nil}` otherwise.

  ## Examples

      iex> grid = %Yog.Builder.GridGraph{graph: graph, rows: 3, cols: 3}
      iex> Yog.Builder.GridGraph.get_cell(grid, 1, 1)
      {:ok, some_data}
      iex> Yog.Builder.GridGraph.get_cell(grid, 10, 10)
      {:error, nil}
  """
  @spec get_cell(t(), non_neg_integer(), non_neg_integer()) :: {:ok, term()} | {:error, nil}
  def get_cell(%__MODULE__{graph: graph, rows: rows, cols: cols}, row, col) do
    if valid_coord?(rows, cols, row, col) do
      node_id = coord_to_id_raw(cols, row, col)

      case Yog.Model.node(graph, node_id) do
        nil -> {:error, nil}
        data -> {:ok, data}
      end
    else
      {:error, nil}
    end
  end

  @doc """
  Converts grid coordinates to a node ID.

  The default mapping is: `row * cols + col`

  ## Examples

      iex> grid = %Yog.Builder.GridGraph{graph: graph, rows: 3, cols: 4}
      iex> Yog.Builder.GridGraph.coord_to_id(grid, 0, 0)
      0
      iex> Yog.Builder.GridGraph.coord_to_id(grid, 1, 2)
      6
      iex> Yog.Builder.GridGraph.coord_to_id(grid, 2, 3)
      11
  """
  @spec coord_to_id(t(), non_neg_integer(), non_neg_integer()) :: Yog.Model.node_id()
  def coord_to_id(%__MODULE__{cols: cols}, row, col) do
    coord_to_id_raw(cols, row, col)
  end

  @doc """
  Converts a node ID back to grid coordinates.

  Returns `{row, col}`.

  ## Examples

      iex> grid = %Yog.Builder.GridGraph{graph: graph, rows: 3, cols: 4}
      iex> Yog.Builder.GridGraph.id_to_coord(grid, 0)
      {0, 0}
      iex> Yog.Builder.GridGraph.id_to_coord(grid, 6)
      {1, 2}
      iex> Yog.Builder.GridGraph.id_to_coord(grid, 11)
      {2, 3}
  """
  @spec id_to_coord(t(), Yog.Model.node_id()) :: {non_neg_integer(), non_neg_integer()}
  def id_to_coord(%__MODULE__{cols: cols}, node_id) when is_integer(node_id) do
    row = div(node_id, cols)
    col = rem(node_id, cols)
    {row, col}
  end

  @doc """
  Checks if a coordinate is within the grid bounds.

  ## Examples

      iex> grid = %Yog.Builder.GridGraph{graph: graph, rows: 3, cols: 4}
      iex> Yog.Builder.GridGraph.valid_coord?(grid, 1, 2)
      true
      iex> Yog.Builder.GridGraph.valid_coord?(grid, 5, 5)
      false
  """
  @spec valid_coord?(t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def valid_coord?(%__MODULE__{rows: rows, cols: cols}, row, col) do
    valid_coord?(rows, cols, row, col)
  end

  @doc """
  Backward compatibility: convert from legacy map format.
  """
  @spec from_map(map()) :: t()
  def from_map(%{graph: g, rows: r, cols: c} = map) do
    topology = Map.get(map, :topology, :rook)
    predicate = Map.get(map, :predicate)

    %__MODULE__{
      graph: g,
      rows: r,
      cols: c,
      topology: topology,
      predicate: predicate
    }
  end

  @doc """
  Convert to legacy map format.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = grid) do
    %{
      graph: grid.graph,
      rows: grid.rows,
      cols: grid.cols
    }
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp coord_to_id_raw(cols, row, col), do: row * cols + col

  defp valid_coord?(rows, cols, row, col) do
    row >= 0 and row < rows and col >= 0 and col < cols
  end
end
