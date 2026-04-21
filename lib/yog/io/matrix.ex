defmodule Yog.IO.Matrix do
  @moduledoc """
  Adjacency matrix import/export for graph serialization.

  This module provides functions to convert between `Yog.Graph` structures
  and adjacency matrix representations. Adjacency matrices are commonly
  used in graph databases (like House of Graphs), mathematical graph theory,
  and dense graph representations.

  ## Format

  An adjacency matrix is a square matrix where `matrix[i][j]` represents
  the weight of the edge from node `i` to node `j`. A value of `0` or `nil`
  indicates no edge.

  ## Example

      # Unweighted graph matrix (1 = edge exists, 0 = no edge)
      matrix = [
        [0, 1, 1, 0],
        [1, 0, 0, 1],
        [1, 0, 0, 1],
        [0, 1, 1, 0]
      ]

      graph = Yog.IO.Matrix.from_matrix(:undirected, matrix)

  ## Use Cases

  - Importing graphs from House of Graphs database
  - Working with mathematical graph definitions
  - Dense graph representations
  - Interoperability with matrix-based graph libraries

  ## Limitations

  Adjacency matrices are primarily designed for numerical edge weights. While
  `to_matrix/1` can return any Elixir term, `from_matrix/2` strictly expects
  numerical weights (or `0`/`nil` for no edge).

  ## See Also

  - `Yog.IO.JSON` - JSON graph format
  - `Yog.IO.GraphML` - GraphML (XML) format
  - `Yog.IO.GDF` - GUESS GDF format
  - `Yog.IO.MatrixMarket` - Matrix Market format
  """

  alias Yog.Model

  @doc """
  Creates a graph from an adjacency matrix.

  The adjacency matrix is a square matrix where `matrix[i][j]` represents
  the weight of the edge from node `i` to node `j`. A value of `0` or `nil`
  indicates no edge.

  ## Parameters

  - `type` - `:directed` or `:undirected`
  - `matrix` - Square matrix (list of lists) representing edge weights

  ## Examples

      iex> # Unweighted adjacency matrix (1 = edge exists)
      ...> matrix = [
      ...>   [0, 1, 1, 0],
      ...>   [1, 0, 0, 1],
      ...>   [1, 0, 0, 1],
      ...>   [0, 1, 1, 0]
      ...> ]
      iex> graph = Yog.IO.Matrix.from_matrix(:undirected, matrix)
      iex> Yog.Model.order(graph)
      4
      iex> Yog.Model.edge_count(graph)
      4

      iex> # Weighted adjacency matrix
      ...> weighted = [
      ...>   [0, 5, 3, 0],
      ...>   [0, 0, 0, 2],
      ...>   [0, 0, 0, 7],
      ...>   [0, 0, 0, 0]
      ...> ]
      iex> digraph = Yog.IO.Matrix.from_matrix(:directed, weighted)
      iex> Yog.Model.edge_count(digraph)
      4

  ## Notes

  - Node IDs are assigned as integers 0, 1, 2, ... based on matrix row indices
  - For undirected graphs, only the upper triangle is processed (i < j)
    to avoid duplicate edges
  - Zero values and `nil` are treated as "no edge"

  ## Raises

  - `ArgumentError` if the matrix is not square
  """
  @spec from_matrix(:directed | :undirected, [[number()]]) :: Yog.graph()
  def from_matrix(type, matrix) do
    unless type in [:directed, :undirected] do
      raise ArgumentError,
            "Invalid graph type: #{inspect(type)}. Expected :directed or :undirected"
    end

    unless is_list(matrix) do
      raise ArgumentError, "Adjacency matrix must be a list of lists, got: #{inspect(matrix)}"
    end

    n = length(matrix)

    # Handle empty matrix
    if n == 0 do
      Yog.new(type)
    else
      # Validate matrix is a list of lists and square
      if Enum.any?(matrix, fn row -> not is_list(row) or length(row) != n end) do
        raise ArgumentError, "Adjacency matrix must be a list of lists forming a square (n x n)"
      end

      base = Yog.new(type)

      # Add all nodes first
      graph =
        Enum.reduce(0..(n - 1), base, fn i, g ->
          Model.add_node(g, i, nil)
        end)

      # Build edges from matrix
      edges =
        case type do
          :undirected ->
            # For undirected, only process upper triangle (i < j)
            for i <- 0..(n - 1),
                j <- (i + 1)..(n - 1)//1,
                weight = get_entry(matrix, i, j),
                weight != 0 and weight != nil,
                do: {i, j, weight}

          :directed ->
            # For directed, process all entries
            for i <- 0..(n - 1),
                j <- 0..(n - 1)//1,
                i != j,
                weight = get_entry(matrix, i, j),
                weight != 0 and weight != nil,
                do: {i, j, weight}
        end

      Enum.reduce(edges, graph, fn {from, to, weight}, g ->
        Model.add_edge!(g, from, to, weight)
      end)
    end
  end

  @doc """
  Exports a graph to an adjacency matrix representation.

  Returns a tuple `{nodes, matrix}` where:
  - `nodes` is a list of node IDs in the order they appear in the matrix
  - `matrix` is the adjacency matrix (list of lists)

  ## Examples

      iex> graph = Yog.undirected()
      ...>   |> Yog.add_node(1, nil)
      ...>   |> Yog.add_node(2, nil)
      ...>   |> Yog.add_node(3, nil)
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 7)
      iex> {nodes, matrix} = Yog.IO.Matrix.to_matrix(graph)
      iex> nodes
      [1, 2, 3]
      iex> matrix
      [[0, 5, 0], [5, 0, 7], [0, 7, 0]]

  ## Notes

  - Unconnected node pairs have weight 0 in the matrix
  - For undirected graphs, the matrix is symmetric
  - Node order is deterministic (sorted by node ID)
  """
  @spec to_matrix(Yog.graph()) :: {[Yog.node_id()], [[number()]]}
  def to_matrix(%Yog.Graph{out_edges: out_edges} = graph) do
    nodes = Model.all_nodes(graph) |> Enum.sort()

    # Build matrix by looking up edge weights directly from out_edges
    matrix =
      for i <- nodes do
        inner_map = Map.get(out_edges, i, %{})

        for j <- nodes do
          if i == j do
            0
          else
            Map.get(inner_map, j, 0)
          end
        end
      end

    {nodes, matrix}
  end

  @doc """
  Exports a graph to a string representation of an adjacency matrix.

  ## Options

  - `weight_formatter` - Function to convert edge weights to strings (default: `&Kernel.to_string/1`)
  - `delimiter` - String to separate values (default: " ")

  ## Examples

      iex> graph = Yog.undirected()
      ...>   |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      ...>   |> Yog.add_edge_ensure(from: 2, to: 3, with: 7)
      iex> Yog.IO.Matrix.to_string(graph)
      "0 5 0\\n5 0 7\\n0 7 0"

      iex> # Using custom weight formatter for complex weights
      iex> graph = Yog.undirected()
      ...>   |> Yog.add_edge_with(1, 2, [weight: 10], & &1)
      iex> Yog.IO.Matrix.to_string(graph,
      ...>   weight_formatter: fn
      ...>     0 -> "0"
      ...>     [weight: w] -> "w\#{w}"
      ...>   end
      ...> )
      "0 w10\\nw10 0"
  """
  @spec to_string(Yog.graph(), keyword()) :: String.t()
  def to_string(graph, opts \\ []) do
    weight_fmt = Keyword.get(opts, :weight_formatter, &Kernel.to_string/1)
    delimiter = Keyword.get(opts, :delimiter, " ")

    {_nodes, matrix} = to_matrix(graph)

    matrix
    |> Enum.map_join("\n", fn row ->
      Enum.map_join(row, delimiter, weight_fmt)
    end)
  end

  # Helper to safely get matrix entry
  defp get_entry(matrix, row, col) do
    weight =
      matrix
      |> Enum.at(row)
      |> Enum.at(col)

    if weight != 0 and weight != nil and not is_number(weight) do
      raise ArgumentError,
            "Adjacency matrix entries must be numbers, got #{inspect(weight)} at [#{row}][#{col}]"
    end

    weight
  end
end
