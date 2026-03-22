defmodule Yog.Builder.Grid do
  @moduledoc """
  Convenience builder for 2D Grid graphs from nested lists.

  Supports custom movement topologies (rook, bishop, queen, knight)
  and movement predicates (walkable, avoiding, always).

  ## Example

      # Create a maze grid
      maze = [
        [".", ".", "#", "."],
        [".", "#", "#", "."],
        [".", ".", ".", "."]
      ]

      grid = Yog.Builder.Grid.from_2d_list(
        maze,
        :undirected,
        Yog.Builder.Grid.walkable(".")
      )

      graph = Yog.Builder.Grid.to_graph(grid)

  ## Distance Functions

  Use these with A* pathfinding on grids:

  - `manhattan_distance/3` - For 4-way (rook) movement
  - `chebyshev_distance/3` - For 8-way (queen) movement  
  - `octile_distance/3` - For 8-way with diagonal costs

  ## Movement Predicates

  - `walkable/1` - Only allow movement into specific cell values
  - `avoiding/1` - Allow movement except into specific cell values
  - `always/0` - Always allow movement
  - `including/1` - Allow movement into any of the specified values
  """

  @typedoc "A Grid builder containing the graph structure and grid metadata."
  @type grid :: term()

  @typedoc "Topology is a list of {row_delta, col_delta} movement offsets."
  @type topology :: [{integer(), integer()}]

  # ============= Builders =============

  @doc """
  Creates a labeled grid graph from a 2D list of cell data.

  Nodes are labeled as `{row, col}` tuples.
  Edges are created between adjacent cells (up, down, left, right) using
  the default rook (4-way) topology.

  ## Parameters

  - `grid_data` - 2D list of cell values
  - `graph_type` - `:directed` or `:undirected`
  - `can_move_fn` - Function `(from_cell, to_cell) -> boolean` determining if movement is allowed

  ## Example

      maze = [
        [".", ".", "#"],
        [".", "#", "."],
        [".", ".", "."]
      ]

      grid = Yog.Builder.Grid.from_2d_list(maze, :undirected, Yog.Builder.Grid.walkable("."))
  """
  @spec from_2d_list([[term()]], Yog.graph_type(), (term(), term() -> boolean())) :: grid()
  defdelegate from_2d_list(grid_data, graph_type, can_move_fn), to: :yog@builder@grid

  @doc """
  Creates a grid graph using a custom movement topology.

  The topology is a list of `{row_delta, col_delta}` tuples defining
  which neighbors each cell can reach. Use presets like `rook/0`, `bishop/0`,
  `queen/0`, or `knight/0`.

  ## Example

      # Allow diagonal movement
      grid = Yog.Builder.Grid.from_2d_list_with_topology(
        grid_data,
        :directed,
        Yog.Builder.Grid.queen(),
        Yog.Builder.Grid.always()
      )
  """
  @spec from_2d_list_with_topology([[term()]], Yog.graph_type(), topology(), (term(), term() ->
                                                                                boolean())) ::
          grid()
  defdelegate from_2d_list_with_topology(grid_data, graph_type, topology, can_move_fn),
    to: :yog@builder@grid

  @doc """
  Converts a grid builder into a usable Graph for algorithms.
  """
  @spec to_graph(grid()) :: Yog.graph()
  defdelegate to_graph(grid), to: :yog@builder@grid

  # ============= Cell Access =============

  @doc """
  Gets the cell data at a specific row and column.

  Returns `{:ok, cell_data}` or `{:error, nil}` if out of bounds.
  """
  @spec get_cell(grid(), integer(), integer()) :: {:ok, term()} | {:error, nil}
  defdelegate get_cell(grid, row, col), to: :yog@builder@grid

  @doc """
  Finds a node in the grid where the cell data matches a predicate.

  Returns `{:ok, node_id}` or `{:error, nil}`.

  ## Example

      # Find the node containing the start position
      {:ok, start_id} = Yog.Builder.Grid.find_node(grid, fn cell -> cell == "S" end)
  """
  @spec find_node(grid(), (term() -> boolean())) :: {:ok, Yog.node_id()} | {:error, nil}
  defdelegate find_node(grid, predicate), to: :yog@builder@grid

  # ============= Coordinate Conversion =============

  @doc """
  Converts grid coordinates `{row, col}` to a node ID.

  ## Example

      node_id = Yog.Builder.Grid.coord_to_id(2, 3, 10)  # row 2, col 3, 10 columns
  """
  @spec coord_to_id(integer(), integer(), integer()) :: Yog.node_id()
  defdelegate coord_to_id(row, col, cols), to: :yog@builder@grid

  @doc """
  Converts a node ID back to grid coordinates `{row, col}`.

  ## Example

      {row, col} = Yog.Builder.Grid.id_to_coord(node_id, 10)
  """
  @spec id_to_coord(Yog.node_id(), integer()) :: {integer(), integer()}
  defdelegate id_to_coord(id, cols), to: :yog@builder@grid

  # ============= Distance Heuristics =============

  @doc """
  Calculates the Manhattan distance between two grid node IDs.

  Use with 4-way (rook) movement. Diagonal movement is not allowed.

  ## Formula

      distance = |row1 - row2| + |col1 - col2|
  """
  @spec manhattan_distance(Yog.node_id(), Yog.node_id(), integer()) :: integer()
  defdelegate manhattan_distance(from_id, to_id, cols), to: :yog@builder@grid

  @doc """
  Calculates the Chebyshev distance between two grid node IDs.

  Use with 8-way (queen) movement where diagonal costs equal cardinal costs.

  ## Formula

      distance = max(|row1 - row2|, |col1 - col2|)
  """
  @spec chebyshev_distance(Yog.node_id(), Yog.node_id(), integer()) :: integer()
  defdelegate chebyshev_distance(from_id, to_id, cols), to: :yog@builder@grid

  @doc """
  Calculates the Octile distance between two grid node IDs.

  Use with 8-way movement where diagonal costs are sqrt(2) * cardinal cost.
  Returns a float for precise A* heuristics.

  ## Formula

      dx = |col1 - col2|
      dy = |row1 - row2|
      distance = max(dx, dy) + (sqrt(2) - 1) * min(dx, dy)
  """
  @spec octile_distance(Yog.node_id(), Yog.node_id(), integer()) :: float()
  defdelegate octile_distance(from_id, to_id, cols), to: :yog@builder@grid

  # ============= Topology Presets =============

  @doc """
  4-way cardinal movement (up, down, left, right).

  Default for `from_2d_list/3`. Movement offsets: `{-1,0}, {1,0}, {0,-1}, {0,1}`
  """
  @spec rook() :: topology()
  defdelegate rook(), to: :yog@builder@grid

  @doc """
  4-way diagonal movement.

  Movement offsets: `{-1,-1}, {-1,1}, {1,-1}, {1,1}`
  """
  @spec bishop() :: topology()
  defdelegate bishop(), to: :yog@builder@grid

  @doc """
  8-way movement (cardinal + diagonal).

  Combines `rook/0` and `bishop/0`. Use with appropriate distance heuristic.
  """
  @spec queen() :: topology()
  defdelegate queen(), to: :yog@builder@grid

  @doc """
  L-shaped knight jumps in all 8 orientations.

  Chess knight movement: `{-2,-1}, {-2,1}, {-1,-2}, {-1,2}, {1,-2}, {1,2}, {2,-1}, {2,1}`
  """
  @spec knight() :: topology()
  defdelegate knight(), to: :yog@builder@grid

  # ============= Movement Predicates =============

  @doc """
  Creates a predicate that only allows movement into cells matching `valid_value`.

  ## Example

      # Only allow walking on floor tiles
      can_move = Yog.Builder.Grid.walkable(".")
  """
  @spec walkable(term()) :: (term(), term() -> boolean())
  defdelegate walkable(valid_value), to: :yog@builder@grid

  @doc """
  Creates a predicate that allows movement into any cell except `wall_value`.

  ## Example

      # Walk anywhere except walls
      can_move = Yog.Builder.Grid.avoiding("#")
  """
  @spec avoiding(term()) :: (term(), term() -> boolean())
  defdelegate avoiding(wall_value), to: :yog@builder@grid

  @doc """
  Creates a predicate that allows movement into any of the specified values.

  ## Example

      # Walk on floors, start, or goal
      can_move = Yog.Builder.Grid.including([".", "S", "G"])
  """
  @spec including([term()]) :: (term(), term() -> boolean())
  defdelegate including(valid_values), to: :yog@builder@grid

  @doc """
  Always allows movement between adjacent cells.

  ## Example

      # No restrictions
      grid = Yog.Builder.Grid.from_2d_list(data, :undirected, Yog.Builder.Grid.always())
  """
  @spec always() :: (term(), term() -> boolean())
  defdelegate always(), to: :yog@builder@grid
end
