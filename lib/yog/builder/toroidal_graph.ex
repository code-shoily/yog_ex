defmodule Yog.Builder.ToroidalGraph do
  @moduledoc """
  A specialized grid graph result for toroidal (wrapping) grids.

  Structurally identical to `Yog.Builder.GridGraph`, but with its own type
  to allow specialized rendering and behavioral hints.

  ## Fields

  - `graph` - The underlying Yog graph
  - `rows` - Number of rows in the grid
  - `cols` - Number of columns in the grid
  - `topology` - Connection pattern (`:rook`, `:queen`, etc.)
  """

  alias Yog.Builder.GridGraph

  @enforce_keys [:graph, :rows, :cols]
  defstruct [:graph, :rows, :cols, topology: :rook]

  @type t :: %__MODULE__{
          graph: Yog.Graph.t(),
          rows: non_neg_integer(),
          cols: non_neg_integer(),
          topology: atom()
        }

  @doc """
  Creates a new toroidal graph result.
  """
  @spec new(Yog.Graph.t(), non_neg_integer(), non_neg_integer(), atom()) :: t()
  def new(graph, rows, cols, topology \\ :rook) do
    %__MODULE__{
      graph: graph,
      rows: rows,
      cols: cols,
      topology: topology
    }
  end

  @doc """
  Converts to a standard GridGraph.
  """
  @spec to_grid_graph(t()) :: GridGraph.t()
  def to_grid_graph(%__MODULE__{} = toroidal) do
    GridGraph.new(toroidal.graph, toroidal.rows, toroidal.cols, toroidal.topology)
  end

  # Delegate common functions to GridGraph or implement them directly
  # for consistent access.

  @doc """
  Unwraps to a plain graph.
  """
  @spec to_graph(t()) :: Yog.Graph.t()
  def to_graph(%__MODULE__{graph: graph}), do: graph

  @doc """
  Converts coordinate to ID.
  """
  def coord_to_id(%__MODULE__{} = grid, row, col) do
    GridGraph.coord_to_id(to_grid_graph(grid), row, col)
  end

  @doc """
  Converts ID to coordinate.
  """
  def id_to_coord(%__MODULE__{} = grid, id) do
    GridGraph.id_to_coord(to_grid_graph(grid), id)
  end
end
