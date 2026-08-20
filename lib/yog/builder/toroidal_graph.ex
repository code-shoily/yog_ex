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
          graph: Yog.graph(),
          rows: non_neg_integer(),
          cols: non_neg_integer(),
          topology: atom()
        }

  @doc """
  Creates a new toroidal graph result.
  """
  @spec new(Yog.graph(), non_neg_integer(), non_neg_integer(), atom()) :: t()
  def new(graph, rows, cols, topology \\ :rook)

  def new(graph, rows, cols, topology)
      when is_integer(rows) and rows >= 0 and is_integer(cols) and cols >= 0 and is_atom(topology) do
    target_graph = validate_graph!(graph)

    %__MODULE__{
      graph: target_graph,
      rows: rows,
      cols: cols,
      topology: topology
    }
  end

  def new(_graph, rows, cols, _topology)
      when not is_integer(rows) or rows < 0 or not is_integer(cols) or cols < 0 do
    raise ArgumentError,
          "expected non-negative integer rows and cols, got: #{inspect({rows, cols})}"
  end

  @doc """
  Converts to a standard GridGraph.
  """
  @spec to_grid_graph(t()) :: GridGraph.t()
  def to_grid_graph(%__MODULE__{} = toroidal) do
    GridGraph.new(toroidal.graph, toroidal.rows, toroidal.cols, toroidal.topology)
  end

  def to_grid_graph(other), do: raise_struct_error(other)

  # Delegate common functions to GridGraph or implement them directly
  # for consistent access.

  @doc """
  Unwraps to a plain graph.
  """
  @spec to_graph(t()) :: Yog.graph()
  def to_graph(%__MODULE__{graph: graph}), do: graph
  def to_graph(other), do: raise_struct_error(other)

  @doc """
  Converts coordinate to ID.
  """
  def coord_to_id(%__MODULE__{} = grid, row, col) do
    GridGraph.coord_to_id(to_grid_graph(grid), row, col)
  end

  def coord_to_id(other, _row, _col), do: raise_struct_error(other)

  @doc """
  Converts ID to coordinate.
  """
  def id_to_coord(%__MODULE__{} = grid, id) do
    GridGraph.id_to_coord(to_grid_graph(grid), id)
  end

  def id_to_coord(other, _id), do: raise_struct_error(other)

  defp validate_graph!(%Yog.Graph{} = g), do: g
  defp validate_graph!(%Yog.DAG{graph: g}), do: g

  defp validate_graph!(other) do
    raise ArgumentError, "expected a Yog.Graph or Yog.DAG struct, got: #{inspect(other)}"
  end

  defp raise_struct_error(other) do
    raise ArgumentError, "expected a Yog.Builder.ToroidalGraph struct, got: #{inspect(other)}"
  end
end
