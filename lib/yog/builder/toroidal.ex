defmodule Yog.Builder.Toroidal do
  @moduledoc """
  Toroidal grid builder - grids where edges wrap around.

  A toroidal grid is like a regular grid, but movement wraps at the boundaries:
  moving off the right edge brings you to the left edge, moving off the bottom
  brings you to the top. This creates a torus topology (like Pac-Man or Asteroids).

  ## Use Cases

  - **Games**: Pac-Man, Civilization, roguelikes with wrapping maps
  - **Cellular automata**: Conway's Game of Life without edge artifacts
  - **Simulations**: Physics simulations where boundaries shouldn't matter

  ## Distance Heuristics for Toroidal Grids

  Regular distance functions don't account for wrapping. Use these instead:

  - **Rook (4-way)** → `toroidal_manhattan_distance/5`
  - **Queen (8-way)** → `toroidal_chebyshev_distance/5`
  - **Weighted diagonals** → `toroidal_octile_distance/5`

  ## Example Usage (Not a doctest - delegates to Erlang)

      # grid_data = [
      #   [1, 2, 3],
      #   [4, 5, 6],
      #   [7, 8, 9]
      # ]

      # Create toroidal grid where all moves wrap
      # grid = Yog.Builder.Toroidal.from_2d_list(
      #   grid_data,
      #   :directed,
      #   Yog.Builder.Toroidal.always()
      # )

      # Distance from (0,0) to (2,2) goes "around" the grid
      # On 3x3: direct is 4, but wrapping is 2 (up 1 + left 1)
      # start = Yog.Builder.Toroidal.coord_to_id(0, 0, 3)
      # goal = Yog.Builder.Toroidal.coord_to_id(2, 2, 3)
      # dist = Yog.Builder.Toroidal.toroidal_manhattan_distance(start, goal, 3, 3)
      # dist = 2
  """

  @typedoc "Opaque toroidal grid type"
  @type toroidal_grid :: term()

  @typedoc "Topology is a list of {row_delta, col_delta} movement offsets"
  @type topology :: [{integer(), integer()}]

  # ============= Builders =============

  @doc """
  Creates a toroidal graph from a 2D list using 4-directional (rook) movement.

  Movement wraps at boundaries: moving right from the rightmost column
  brings you to the leftmost column, and similarly for vertical movement.

  ## Examples

      # Create grid from 2D list (delegates to Erlang)
      # data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      # grid = Yog.Builder.Toroidal.from_2d_list(
      #   data,
      #   :directed,
      #   Yog.Builder.Toroidal.always()
      # )

  ## Time Complexity

  O(rows × cols)
  """
  @spec from_2d_list([[term()]], Yog.graph_type(), (term(), term() -> boolean())) ::
          toroidal_grid()
  defdelegate from_2d_list(grid_data, graph_type, can_move_fn), to: :yog@builder@toroidal

  @doc """
  Creates a toroidal graph from a 2D list using a custom movement topology.

  ## Examples

      # 8-way movement on a toroidal grid (delegates to Erlang)
      # grid = Yog.Builder.Toroidal.from_2d_list_with_topology(
      #   data,
      #   :directed,
      #   Yog.Builder.Toroidal.queen(),
      #   Yog.Builder.Toroidal.always()
      # )
  """
  @spec from_2d_list_with_topology(
          [[term()]],
          Yog.graph_type(),
          topology(),
          (term(), term() -> boolean())
        ) ::
          toroidal_grid()
  defdelegate from_2d_list_with_topology(grid_data, graph_type, topology, can_move_fn),
    to: :yog@builder@toroidal

  @doc """
  Converts a toroidal grid into a standard Graph.
  """
  @spec to_graph(toroidal_grid()) :: Yog.graph()
  defdelegate to_graph(grid), to: :yog@builder@toroidal

  # ============= Cell Access =============

  @doc """
  Gets the cell data at a specific row and column.

  Returns `{:ok, cell_data}` or `{:error, nil}` if out of bounds.
  """
  @spec get_cell(toroidal_grid(), integer(), integer()) :: {:ok, term()} | {:error, nil}
  defdelegate get_cell(grid, row, col), to: :yog@builder@toroidal

  @doc """
  Finds a node in the grid where the cell data matches a predicate.

  Returns `{:ok, node_id}` or `{:error, nil}`.
  """
  @spec find_node(toroidal_grid(), (term() -> boolean())) :: {:ok, Yog.node_id()} | {:error, nil}
  defdelegate find_node(grid, predicate), to: :yog@builder@toroidal

  # ============= Coordinate Conversion =============

  @doc """
  Converts grid coordinates `{row, col}` to a node ID.
  """
  @spec coord_to_id(integer(), integer(), integer()) :: Yog.node_id()
  defdelegate coord_to_id(row, col, cols), to: :yog@builder@toroidal

  @doc """
  Converts a node ID back to grid coordinates `{row, col}`.
  """
  @spec id_to_coord(Yog.node_id(), integer()) :: {integer(), integer()}
  defdelegate id_to_coord(id, cols), to: :yog@builder@toroidal

  # ============= Toroidal Distance Heuristics =============

  @doc """
  Calculates the toroidal Manhattan distance between two grid node IDs.

  For 4-way (rook) movement on a wrapping grid.

  ## Formula

  Accounts for wrapping by considering the shorter path around the torus:

      dx = min(|col1 - col2|, cols - |col1 - col2|)
      dy = min(|row1 - row2|, rows - |row1 - row2|)
      distance = dx + dy
  """
  @spec toroidal_manhattan_distance(Yog.node_id(), Yog.node_id(), integer(), integer()) ::
          integer()
  defdelegate toroidal_manhattan_distance(from_id, to_id, cols, rows),
    to: :yog@builder@toroidal

  @doc """
  Calculates the toroidal Chebyshev distance between two grid node IDs.

  For 8-way (queen) movement on a wrapping grid where diagonal costs equal cardinal costs.

  ## Formula

      dx = min(|col1 - col2|, cols - |col1 - col2|)
      dy = min(|row1 - row2|, rows - |row1 - row2|)
      distance = max(dx, dy)
  """
  @spec toroidal_chebyshev_distance(Yog.node_id(), Yog.node_id(), integer(), integer()) ::
          integer()
  defdelegate toroidal_chebyshev_distance(from_id, to_id, cols, rows),
    to: :yog@builder@toroidal

  @doc """
  Calculates the toroidal Octile distance between two grid node IDs.

  For 8-way movement on a wrapping grid where diagonal costs are √2 × cardinal cost.

  ## Formula

      dx = min(|col1 - col2|, cols - |col1 - col2|)
      dy = min(|row1 - row2|, rows - |row1 - row2|)
      distance = max(dx, dy) + (√2 - 1) × min(dx, dy)
  """
  @spec toroidal_octile_distance(Yog.node_id(), Yog.node_id(), integer(), integer()) ::
          float()
  defdelegate toroidal_octile_distance(from_id, to_id, cols, rows),
    to: :yog@builder@toroidal

  # ============= Topology Presets =============

  @doc """
  4-way cardinal movement (up, down, left, right) with wrapping.

  Default for `from_2d_list/3`. Movement offsets: `{-1,0}, {1,0}, {0,-1}, {0,1}`
  """
  @spec rook() :: topology()
  defdelegate rook(), to: :yog@builder@toroidal

  @doc """
  4-way diagonal movement with wrapping.

  Movement offsets: `{-1,-1}, {-1,1}, {1,-1}, {1,1}`
  """
  @spec bishop() :: topology()
  defdelegate bishop(), to: :yog@builder@toroidal

  @doc """
  8-way movement (cardinal + diagonal) with wrapping.

  Combines `rook/0` and `bishop/0`.
  """
  @spec queen() :: topology()
  defdelegate queen(), to: :yog@builder@toroidal

  @doc """
  L-shaped knight jumps in all 8 orientations with wrapping.

  Chess knight movement: `{-2,-1}, {-2,1}, {-1,-2}, {-1,2}, {1,-2}, {1,2}, {2,-1}, {2,1}`
  """
  @spec knight() :: topology()
  defdelegate knight(), to: :yog@builder@toroidal

  # ============= Movement Predicates =============

  @doc """
  Creates a predicate that only allows movement into cells matching `valid_value`.
  """
  @spec walkable(term()) :: (term(), term() -> boolean())
  defdelegate walkable(valid_value), to: :yog@builder@toroidal

  @doc """
  Creates a predicate that allows movement into any cell except `wall_value`.
  """
  @spec avoiding(term()) :: (term(), term() -> boolean())
  defdelegate avoiding(wall_value), to: :yog@builder@toroidal

  @doc """
  Creates a predicate that allows movement into any of the specified values.
  """
  @spec including([term()]) :: (term(), term() -> boolean())
  defdelegate including(valid_values), to: :yog@builder@toroidal

  @doc """
  Always allows movement between adjacent cells.
  """
  @spec always() :: (term(), term() -> boolean())
  defdelegate always(), to: :yog@builder@toroidal
end
