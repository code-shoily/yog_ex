defmodule Yog.Builder.Grid do
  @moduledoc """
  Convenience builder for 2D Grid graphs from nested lists.

  Supports custom movement topologies (rook, bishop, queen, knight)
  and movement predicates (walkable, avoiding, always).

  ## Example

  Create a maze grid:

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

  alias Yog.Builder.GridGraph
  alias Yog.Modifiable, as: Mutator
  alias Yog.Queryable, as: Model
  alias Yog.Transformable

  @typedoc "Grid builder type: {:grid_builder, graph, rows, cols}"
  @type grid :: {:grid_builder, Yog.Graph.t(), integer(), integer()}

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

  ## Examples

      iex> maze = [[".", ".", "#"], [".", "#", "."], [".", ".", "."]]
      iex> grid = Yog.Builder.Grid.from_2d_list(maze, :undirected, Yog.Builder.Grid.walkable("."))
      iex> is_struct(grid, Yog.Builder.GridGraph)
      true
  """
  @spec from_2d_list(
          [[term()]],
          :directed | :undirected,
          (term(), term() -> boolean()),
          keyword()
        ) ::
          GridGraph.t()
  def from_2d_list(grid_data, graph_type, can_move_fn, opts \\ []) do
    from_2d_list_with_topology(grid_data, graph_type, rook(), can_move_fn, opts)
  end

  @doc """
  Creates a grid graph using a custom movement topology.

  The topology is a list of `{row_delta, col_delta}` tuples defining
  which neighbors each cell can reach. Use presets like `rook/0`, `bishop/0`,
  `queen/0`, or `knight/0`.

  ## Examples

      iex> grid_data = [[1, 2], [3, 4]]
      iex> grid = Yog.Builder.Grid.from_2d_list_with_topology(
      ...>   grid_data,
      ...>   :directed,
      ...>   Yog.Builder.Grid.queen(),
      ...>   Yog.Builder.Grid.always()
      ...> )
      iex> is_struct(grid, Yog.Builder.GridGraph)
      true
  """
  @spec from_2d_list_with_topology(
          [[term()]],
          :directed | :undirected,
          topology(),
          (term(), term() -> boolean()),
          keyword()
        ) ::
          GridGraph.t()
  def from_2d_list_with_topology(grid_data, graph_type, topology, can_move_fn, opts \\ []) do
    rows = length(grid_data)

    cols =
      case grid_data do
        [first_row | _] -> length(first_row)
        [] -> 0
      end

    # Flatten grid data into a list of {row, col, cell} tuples
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

    # Create graph with all nodes
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

    # Add edges based on topology
    graph_with_edges =
      Enum.reduce(cells, graph_with_nodes, fn {row, col, from_data}, g ->
        from_id = coord_to_id(row, col, cols)

        Enum.reduce(topology, g, fn {d_row, d_col}, acc_g ->
          n_row = row + d_row
          n_col = col + d_col

          if n_row >= 0 && n_row < rows && n_col >= 0 && n_col < cols do
            to_id = coord_to_id(n_row, n_col, cols)
            to_data = Model.node(acc_g, to_id)

            if to_data != nil && can_move_fn.(from_data, to_data) do
              Mutator.add_edge(acc_g, from_id, to_id, 1) |> Yog.Utils.unwrap_mutate!()
            else
              acc_g
            end
          else
            acc_g
          end
        end)
      end)

    GridGraph.new(graph_with_edges, rows, cols, :rook)
  end

  @doc """
  Converts a grid builder into a usable Graph for algorithms.
  """
  @spec to_graph(GridGraph.t() | grid() | {:grid, Yog.Graph.t(), integer(), integer()}) ::
          Yog.Graph.t()
  def to_graph(%GridGraph{} = grid) do
    GridGraph.to_graph(grid)
  end

  def to_graph({:grid_builder, graph, _rows, _cols}) do
    graph
  end

  # Support legacy Gleam format
  def to_graph({:grid, graph, _rows, _cols}) do
    graph
  end

  # ============= Cell Access =============

  @doc """
  Gets the cell data at a specific row and column.

  Returns `{:ok, cell_data}` or `{:error, nil}` if out of bounds.
  """
  @spec get_cell(
          GridGraph.t() | grid() | {:grid, Yog.Graph.t(), integer(), integer()},
          integer(),
          integer()
        ) ::
          {:ok, term()} | {:error, nil}
  def get_cell(%GridGraph{} = grid, row, col) do
    GridGraph.get_cell(grid, row, col)
  end

  def get_cell({:grid_builder, graph, rows, cols}, row, col) do
    do_get_cell(graph, rows, cols, row, col)
  end

  # Support legacy Gleam format
  def get_cell({:grid, graph, rows, cols}, row, col) do
    do_get_cell(graph, rows, cols, row, col)
  end

  defp do_get_cell(graph, rows, cols, row, col) do
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

  ## Examples

      iex> grid = Yog.Builder.Grid.from_2d_list([["S", "."]], :undirected, Yog.Builder.Grid.always())
      iex> {:ok, start_id} = Yog.Builder.Grid.find_node(grid, fn cell -> cell == "S" end)
      iex> is_integer(start_id)
      true
  """
  @spec find_node(
          GridGraph.t() | grid() | {:grid, Yog.Graph.t(), integer(), integer()},
          (term() ->
             boolean())
        ) ::
          {:ok, Yog.node_id()} | {:error, nil}
  def find_node(%GridGraph{graph: graph, rows: rows, cols: cols}, predicate) do
    do_find_node(graph, rows, cols, predicate)
  end

  def find_node({:grid_builder, graph, rows, cols}, predicate) do
    do_find_node(graph, rows, cols, predicate)
  end

  # Support legacy Gleam format
  def find_node({:grid, graph, rows, cols}, predicate) do
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

  ## Examples

      iex> Yog.Builder.Grid.coord_to_id(2, 3, 10)
      23
  """
  @spec coord_to_id(integer(), integer(), integer()) :: Yog.node_id()
  def coord_to_id(row, col, cols) do
    row * cols + col
  end

  @doc """
  Converts a node ID back to grid coordinates `{row, col}`.

  ## Examples

      iex> Yog.Builder.Grid.id_to_coord(23, 10)
      {2, 3}
  """
  @spec id_to_coord(Yog.node_id(), integer()) :: {integer(), integer()}
  def id_to_coord(id, cols) do
    {div(id, cols), rem(id, cols)}
  end

  # ============= Distance Heuristics =============

  @doc """
  Calculates the Manhattan distance between two grid node IDs.

  Use with 4-way (rook) movement. Diagonal movement is not allowed.

  ## Formula

      distance = |row1 - row2| + |col1 - col2|
  """
  @spec manhattan_distance(Yog.node_id(), Yog.node_id(), integer()) :: integer()
  def manhattan_distance(from_id, to_id, cols) do
    {from_row, from_col} = id_to_coord(from_id, cols)
    {to_row, to_col} = id_to_coord(to_id, cols)

    row_diff = abs(from_row - to_row)
    col_diff = abs(from_col - to_col)

    row_diff + col_diff
  end

  @doc """
  Calculates the Chebyshev distance between two grid node IDs.

  Use with 8-way (queen) movement where diagonal costs equal cardinal costs.

  ## Formula

      distance = max(|row1 - row2|, |col1 - col2|)
  """
  @spec chebyshev_distance(Yog.node_id(), Yog.node_id(), integer()) :: integer()
  def chebyshev_distance(from_id, to_id, cols) do
    {from_row, from_col} = id_to_coord(from_id, cols)
    {to_row, to_col} = id_to_coord(to_id, cols)

    row_diff = abs(from_row - to_row)
    col_diff = abs(from_col - to_col)

    max(row_diff, col_diff)
  end

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
  def octile_distance(from_id, to_id, cols) do
    {from_row, from_col} = id_to_coord(from_id, cols)
    {to_row, to_col} = id_to_coord(to_id, cols)

    row_diff = abs(from_row - to_row)
    col_diff = abs(from_col - to_col)

    min_d = min(row_diff, col_diff)
    max_d = max(row_diff, col_diff)

    # √2 ≈ 1.414213562373095
    min_d * 1.414213562373095 + (max_d - min_d)
  end

  # ============= Topology Presets =============

  @doc """
  4-way cardinal movement (up, down, left, right).

  Default for `from_2d_list/3`. Movement offsets: `{-1,0}, {1,0}, {0,-1}, {0,1}`
  """
  @spec rook() :: topology()
  def rook do
    [{-1, 0}, {1, 0}, {0, -1}, {0, 1}]
  end

  @doc """
  4-way diagonal movement.

  Movement offsets: `{-1,-1}, {-1,1}, {1,-1}, {1,1}`
  """
  @spec bishop() :: topology()
  def bishop do
    [{-1, -1}, {-1, 1}, {1, -1}, {1, 1}]
  end

  @doc """
  8-way movement (cardinal + diagonal).

  Combines `rook/0` and `bishop/0`. Use with appropriate distance heuristic.
  """
  @spec queen() :: topology()
  def queen do
    [
      {-1, -1},
      {-1, 0},
      {-1, 1},
      {0, -1},
      {0, 1},
      {1, -1},
      {1, 0},
      {1, 1}
    ]
  end

  @doc """
  L-shaped knight jumps in all 8 orientations.

  Chess knight movement: `{-2,-1}, {-2,1}, {-1,-2}, {-1,2}, {1,-2}, {1,2}, {2,-1}, {2,1}`
  """
  @spec knight() :: topology()
  def knight do
    [
      {-2, -1},
      {-2, 1},
      {-1, -2},
      {-1, 2},
      {1, -2},
      {1, 2},
      {2, -1},
      {2, 1}
    ]
  end

  # ============= Movement Predicates =============

  @doc """
  Creates a predicate that only allows movement into cells matching `valid_value`.

  ## Examples

      iex> can_move = Yog.Builder.Grid.walkable(".")
      iex> can_move.(".", ".")
      true
      iex> can_move.(".", "#")
      false
  """
  @spec walkable(term()) :: (term(), term() -> boolean())
  def walkable(valid_value) do
    fn from, to -> from == valid_value && to == valid_value end
  end

  @doc """
  Creates a predicate that allows movement into any cell except `wall_value`.

  ## Examples

      iex> can_move = Yog.Builder.Grid.avoiding("#")
      iex> can_move.(".", ".")
      true
      iex> can_move.(".", "#")
      false
  """
  @spec avoiding(term()) :: (term(), term() -> boolean())
  def avoiding(wall_value) do
    fn from, to -> from != wall_value && to != wall_value end
  end

  @doc """
  Creates a predicate that allows movement into any of the specified values.

  ## Examples

      iex> can_move = Yog.Builder.Grid.including([".", "S", "G"])
      iex> can_move.(".", "S")
      true
      iex> can_move.(".", "#")
      false
  """
  @spec including([term()]) :: (term(), term() -> boolean())
  def including(valid_values) do
    fn from, to -> from in valid_values && to in valid_values end
  end

  @doc """
  Always allows movement between adjacent cells.

  ## Examples

      iex> can_move = Yog.Builder.Grid.always()
      iex> can_move.("anything", "works")
      true
  """
  @spec always() :: (term(), term() -> boolean())
  def always do
    fn _from, _to -> true end
  end
end
