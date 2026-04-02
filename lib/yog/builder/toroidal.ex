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

  ## Example Usage

      # Create a 3x3 toroidal grid
      data = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
      ]

      # Create toroidal grid where all moves wrap
      grid = Yog.Builder.Toroidal.from_2d_list(
        data,
        :directed,
        Yog.Builder.Toroidal.always()
      )

      # Distance from (0,0) to (2,2) goes "around" the grid
      # On 3x3: direct is 4, but wrapping is 2 (up 1 + left 1)
      start = Yog.Builder.Toroidal.coord_to_id(0, 0, 3)
      goal = Yog.Builder.Toroidal.coord_to_id(2, 2, 3)
      dist = Yog.Builder.Toroidal.toroidal_manhattan_distance(start, goal, 3, 3)
      # dist = 2


  """

  alias Yog.Builder.Grid
  alias Yog.Builder.GridGraph
  alias Yog.Builder.ToroidalGraph
  alias Yog.Modifiable, as: Mutator
  alias Yog.Queryable, as: Model
  alias Yog.Transformable

  @typedoc "Toroidal grid type (now using ToroidalGraph)"
  @type toroidal_grid :: ToroidalGraph.t()

  @typedoc "Topology is a list of {row_delta, col_delta} movement offsets"
  @type topology :: [{integer(), integer()}]

  # ============= Builders =============

  @doc """
  Creates a toroidal graph from a 2D list using 4-directional (rook) movement.

  Movement wraps at boundaries: moving right from the rightmost column
  brings you to the leftmost column, and similarly for vertical movement.

  ## Examples

      data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      grid = Yog.Builder.Toroidal.from_2d_list(
        data,
        :directed,
        Yog.Builder.Toroidal.always()
      )

  ## Time Complexity

  O(rows × cols)
  """
  @spec from_2d_list(
          [[term()]],
          :directed | :undirected,
          (term(), term() -> boolean()),
          keyword()
        ) ::
          ToroidalGraph.t()
  def from_2d_list(grid_data, graph_type, can_move_fn, opts \\ []) do
    from_2d_list_with_topology(grid_data, graph_type, rook(), can_move_fn, opts)
  end

  @doc """
  Creates a toroidal graph from a 2D list using a custom movement topology.

  Like `from_2d_list`, but allows custom movement patterns. All movement
  wraps at boundaries.

  ## Examples

      # 8-way movement on a toroidal grid
      grid = Yog.Builder.Toroidal.from_2d_list_with_topology(
        data,
        :directed,
        Yog.Builder.Toroidal.queen(),
        Yog.Builder.Toroidal.always()
      )
  """
  @spec from_2d_list_with_topology(
          [[term()]],
          :directed | :undirected,
          topology(),
          (term(), term() -> boolean()),
          keyword()
        ) ::
          ToroidalGraph.t()
  def from_2d_list_with_topology(grid_data, graph_type, topology, can_move_fn, opts \\ []) do
    rows = length(grid_data)

    cols =
      case grid_data do
        [first_row | _] -> length(first_row)
        [] -> 0
      end

    # Flatten grid into list of cells with coordinates
    cells =
      grid_data
      |> Enum.with_index()
      |> Enum.flat_map(fn {row, row_idx} ->
        row
        |> Enum.with_index()
        |> Enum.map(fn {cell, col_idx} ->
          {row_idx, col_idx, cell}
        end)
      end)

    # Add all nodes
    init =
      case Keyword.get(opts, :into) do
        nil -> Yog.Graph.new(graph_type)
        template -> Transformable.empty(template, graph_type)
      end

    graph_with_nodes =
      Enum.reduce(cells, init, fn {row, col, data}, g ->
        id = coord_to_id(row, col, cols)
        Mutator.add_node(g, id, data)
      end)

    # Add edges with wrapping
    graph_with_edges =
      Enum.reduce(cells, graph_with_nodes, fn {row, col, from_data}, g ->
        from_id = coord_to_id(row, col, cols)

        Enum.reduce(topology, g, fn {d_row, d_col}, acc_g ->
          # Wrap coordinates using modulo
          n_row = wrap_coordinate(row + d_row, rows)
          n_col = wrap_coordinate(col + d_col, cols)

          to_id = coord_to_id(n_row, n_col, cols)
          to_data = Model.node(acc_g, to_id)

          if to_data != nil && can_move_fn.(from_data, to_data) do
            Mutator.add_edge(acc_g, from_id, to_id, 1) |> Yog.Utils.unwrap_mutate!()
          else
            acc_g
          end
        end)
      end)

    ToroidalGraph.new(graph_with_edges, rows, cols, :rook)
  end

  @doc """
  Converts a toroidal grid into a standard Graph.
  """
  @spec to_graph(
          toroidal_grid()
          | GridGraph.t()
          | {:toroidal_grid, Yog.Graph.t(), integer(), integer()}
        ) :: Yog.Graph.t()
  def to_graph(%ToroidalGraph{graph: graph}), do: graph

  def to_graph(%GridGraph{graph: graph}), do: graph

  def to_graph({:toroidal_grid, graph, _rows, _cols}) do
    graph
  end

  # ============= Cell Access =============

  @doc """
  Gets the cell data at a specific row and column.

  Returns `{:ok, cell_data}` or `{:error, nil}` if out of bounds.
  """
  @spec get_cell(
          toroidal_grid() | GridGraph.t() | {:toroidal_grid, Yog.Graph.t(), integer(), integer()},
          integer(),
          integer()
        ) ::
          {:ok, term()} | {:error, nil}
  def get_cell(%ToroidalGraph{} = grid, row, col) do
    ToroidalGraph.to_grid_graph(grid) |> GridGraph.get_cell(row, col)
  end

  def get_cell(%GridGraph{} = grid, row, col) do
    GridGraph.get_cell(grid, row, col)
  end

  def get_cell({:toroidal_grid, graph, rows, cols}, row, col) do
    if row >= 0 && row < rows && col >= 0 && col < cols do
      id = coord_to_id(row, col, cols)
      data = Model.node(graph, id)

      if data != nil do
        {:ok, data}
      else
        {:error, nil}
      end
    else
      {:error, nil}
    end
  end

  @doc """
  Finds a node in the grid where the cell data matches a predicate.

  Returns `{:ok, node_id}` or `{:error, nil}`.
  """
  @spec find_node(
          toroidal_grid() | GridGraph.t() | {:toroidal_grid, Yog.graph(), integer(), integer()},
          (term() -> boolean())
        ) ::
          {:ok, Yog.node_id()} | {:error, nil}
  def find_node(%ToroidalGraph{graph: graph, rows: rows, cols: cols}, predicate) do
    do_find_node(graph, rows, cols, predicate)
  end

  def find_node(%GridGraph{graph: graph, rows: rows, cols: cols}, predicate) do
    do_find_node(graph, rows, cols, predicate)
  end

  def find_node({:toroidal_grid, graph, rows, cols}, predicate) do
    do_find_node(graph, rows, cols, predicate)
  end

  defp do_find_node(graph, rows, cols, predicate) do
    max_id = rows * cols - 1

    result =
      Enum.find_value(0..max_id, fn id ->
        case Model.node(graph, id) do
          nil -> nil
          data -> if predicate.(data), do: {:ok, id}, else: nil
        end
      end)

    case result do
      {:ok, id} -> {:ok, id}
      nil -> {:error, nil}
    end
  end

  # ============= Coordinate Conversion =============

  @doc """
  Converts grid coordinates `{row, col}` to a node ID.

  Delegates to `Yog.Builder.Grid.coord_to_id/3`.
  """
  @spec coord_to_id(integer(), integer(), integer()) :: Yog.node_id()
  def coord_to_id(row, col, cols) do
    Grid.coord_to_id(row, col, cols)
  end

  @doc """
  Converts a node ID back to grid coordinates `{row, col}`.

  Delegates to `Yog.Builder.Grid.id_to_coord/2`.
  """
  @spec id_to_coord(Yog.node_id(), integer()) :: {integer(), integer()}
  def id_to_coord(id, cols) do
    Grid.id_to_coord(id, cols)
  end

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
  def toroidal_manhattan_distance(from_id, to_id, cols, rows) do
    {from_row, from_col} = id_to_coord(from_id, cols)
    {to_row, to_col} = id_to_coord(to_id, cols)

    row_diff = abs(from_row - to_row)
    col_diff = abs(from_col - to_col)

    # Take the shorter path (direct or wrapped)
    min_row_dist = min(row_diff, rows - row_diff)
    min_col_dist = min(col_diff, cols - col_diff)

    min_row_dist + min_col_dist
  end

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
  def toroidal_chebyshev_distance(from_id, to_id, cols, rows) do
    {from_row, from_col} = id_to_coord(from_id, cols)
    {to_row, to_col} = id_to_coord(to_id, cols)

    row_diff = abs(from_row - to_row)
    col_diff = abs(from_col - to_col)

    # Take the shorter path (direct or wrapped)
    min_row_dist = min(row_diff, rows - row_diff)
    min_col_dist = min(col_diff, cols - col_diff)

    max(min_row_dist, min_col_dist)
  end

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
  def toroidal_octile_distance(from_id, to_id, cols, rows) do
    {from_row, from_col} = id_to_coord(from_id, cols)
    {to_row, to_col} = id_to_coord(to_id, cols)

    row_diff = abs(from_row - to_row)
    col_diff = abs(from_col - to_col)

    # Take the shorter path (direct or wrapped)
    min_row_dist = min(row_diff, rows - row_diff)
    min_col_dist = min(col_diff, cols - col_diff)

    min_d = min(min_row_dist, min_col_dist)
    max_d = max(min_row_dist, min_col_dist)

    # √2 ≈ 1.414213562373095
    min_d * 1.414213562373095 + (max_d - min_d)
  end

  # ============= Topology Presets =============

  @doc """
  4-way cardinal movement (up, down, left, right) with wrapping.

  Default for `from_2d_list/3`. Movement offsets: `{-1,0}, {1,0}, {0,-1}, {0,1}`
  """
  @spec rook() :: topology()
  def rook do
    Grid.rook()
  end

  @doc """
  4-way diagonal movement with wrapping.

  Movement offsets: `{-1,-1}, {-1,1}, {1,-1}, {1,1}`
  """
  @spec bishop() :: topology()
  def bishop do
    Grid.bishop()
  end

  @doc """
  8-way movement (cardinal + diagonal) with wrapping.

  Combines `rook/0` and `bishop/0`.
  """
  @spec queen() :: topology()
  def queen do
    Grid.queen()
  end

  @doc """
  L-shaped knight jumps in all 8 orientations with wrapping.

  Chess knight movement: `{-2,-1}, {-2,1}, {-1,-2}, {-1,2}, {1,-2}, {1,2}, {2,-1}, {2,1}`
  """
  @spec knight() :: topology()
  def knight do
    Grid.knight()
  end

  # ============= Movement Predicates =============

  @doc """
  Creates a predicate that only allows movement into cells matching `valid_value`.
  """
  @spec walkable(term()) :: (term(), term() -> boolean())
  def walkable(valid_value) do
    Grid.walkable(valid_value)
  end

  @doc """
  Creates a predicate that allows movement into any cell except `wall_value`.
  """
  @spec avoiding(term()) :: (term(), term() -> boolean())
  def avoiding(wall_value) do
    Grid.avoiding(wall_value)
  end

  @doc """
  Creates a predicate that allows movement into any of the specified values.
  """
  @spec including([term()]) :: (term(), term() -> boolean())
  def including(valid_values) do
    Grid.including(valid_values)
  end

  @doc """
  Always allows movement between adjacent cells.
  """
  @spec always() :: (term(), term() -> boolean())
  def always do
    Grid.always()
  end

  # ============= Private Helpers =============

  # Wraps a coordinate to stay within bounds [0, size)
  # Handles negative values correctly for wrapping
  defp wrap_coordinate(coord, size) do
    rem_result = rem(coord, size)

    if rem_result < 0 do
      rem_result + size
    else
      rem_result
    end
  end
end
