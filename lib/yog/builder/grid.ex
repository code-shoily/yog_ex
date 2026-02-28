defmodule Yog.Builder.Grid do
  @moduledoc """
  Convenience builder for 2D Grid graphs from nested lists.
  """

  @doc """
  Creates a labeled grid graph from a 2D list of weights.

  Nodes are labeled as `{row, col}` tuples.
  Edges are created between adjacent cells (up, down, left, right) if the
  `is_passable` function returns true for the cell's weight.
  """
  @spec from_2d_list([[term()]], Yog.graph_type(), fun()) :: Yog.Builder.Labeled.builder()
  def from_2d_list(grid_data, graph_type, is_passable_fn) do
    # Gleam's Directed/Undirected compile to :directed/:undirected atoms
    :yog@builder@grid.from_2d_list(grid_data, graph_type, is_passable_fn)
  end

  @doc """
  Converts a labelled grid builder strictly into a usable Graph.
  """
  @spec to_graph(Yog.Builder.Labeled.builder()) :: Yog.graph()
  defdelegate to_graph(builder), to: :yog@builder@grid

  @doc """
  Calculates the Manhattan distance between two standard grid node IDs given the number of columns.
  """
  @spec manhattan_distance(Yog.node_id(), Yog.node_id(), integer()) :: integer()
  defdelegate manhattan_distance(from_id, to_id, cols), to: :yog@builder@grid

  @doc """
  Converts grid coordinates (row, col) to a node ID.
  """
  @spec coord_to_id(integer(), integer(), integer()) :: Yog.node_id()
  defdelegate coord_to_id(row, col, cols), to: :yog@builder@grid

  @doc """
  Converts a node ID back to grid coordinates (row, col).
  """
  @spec id_to_coord(Yog.node_id(), integer()) :: {integer(), integer()}
  defdelegate id_to_coord(id, cols), to: :yog@builder@grid
end
