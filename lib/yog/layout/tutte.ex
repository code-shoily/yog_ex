defmodule Yog.Layout.Tutte do
  @moduledoc """
  Tutte embedding (barycentric layout) algorithm for planar graphs in Elixir.

  Tutte's embedding theorem states that if a graph is 3-vertex-connected and planar,
  pinning its outer boundary to a convex polygon and placing every interior node at
  the average (barycenter) of its neighbors' positions yields a planar layout
  without any edge crossings.

  Rather than solving the large sparse linear system ($Ax = b$) directly via matrix
  inversion, this module uses **Gauss-Seidel relaxation** (iterative relaxation),
  which runs in pure Elixir without native matrix solver libraries.

  ## Mathematical Model

  1. **Boundary Nodes ($V_b$):** Pinned to a circle or regular polygon centered at $(c_x, c_y)$ with radius $R$.
  2. **Interior Nodes ($V_i = V \\setminus V_b$):** Positioned iteratively. For each interior node $u$:
     $$x_u = \\frac{1}{deg(u)} \\sum_{v \\in N(u)} x_v$$
     $$y_u = \\frac{1}{deg(u)} \\sum_{v \\in N(u)} y_v$$
     where $N(u)$ is the set of neighbors of $u$, and $deg(u)$ is the degree of $u$.

  ## Complexities

  * **Time Complexity:** $O(I \\cdot (V + E))$ where $I$ is iterations, $V$ is nodes, $E$ is edges.
  * **Space Complexity:** $O(V)$ auxiliary space.

  ## References

  * [Tutte 1963 - How to Draw a Graph](https://doi.org/10.1112/plms/s3-13.1.743)
  * [Wikipedia: Tutte embedding](https://en.wikipedia.org/wiki/Tutte_embedding)
  """

  alias Yog.Graph
  alias Yog.Model

  @doc """
  Positions nodes using Tutte's barycentric embedding.

  Requires a list of `boundary_nodes` (ordered) forming the outer convex boundary polygon.

  ## Options

    * `:iterations` - Number of relaxation steps to run (default: `100`).
    * `:radius` - Bounding boundary radius (default: `1.0`).
    * `:center` - Center of boundary circle (default: `{0.0, 0.0}`).

  ## Examples

      iex> graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {2, 3}, {3, 1}, {1, 4}, {2, 4}, {3, 4}])
      iex> pos = Yog.Layout.Tutte.layout(graph, [1, 2, 3])
      iex> Map.keys(pos) |> Enum.sort()
      [1, 2, 3, 4]

  """
  @spec layout(Graph.t(), [Graph.node_id()], keyword()) :: %{Graph.node_id() => {float(), float()}}
  def layout(graph, boundary_nodes, opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 100)
    radius = Keyword.get(opts, :radius, 1.0)
    {cx, cy} = Keyword.get(opts, :center, {0.0, 0.0})

    nodes = Yog.all_nodes(graph)
    boundary_set = MapSet.new(boundary_nodes)

    cond do
      length(boundary_nodes) < 3 ->
        raise ArgumentError, "Tutte layout requires at least 3 boundary nodes to form a convex polygon"

      Enum.any?(boundary_nodes, fn id -> id not in nodes end) ->
        raise ArgumentError, "All boundary nodes must exist within the graph"

      true ->
        # 1. Place boundary nodes on a circle
        boundary_pos = position_boundary_circle(boundary_nodes, radius, cx, cy)

        # 2. Place interior nodes at the center initially
        interior_nodes = Enum.reject(nodes, fn id -> MapSet.member?(boundary_set, id) end)
        initial_interior = Map.new(interior_nodes, fn id -> {id, {cx, cy}} end)

        positions = Map.merge(initial_interior, boundary_pos)

        # 3. Relax interior nodes
        relax_iterations(positions, graph, interior_nodes, iterations)
    end
  end

  defp position_boundary_circle(boundary_nodes, radius, cx, cy) do
    n = length(boundary_nodes)
    two_pi = 2 * :math.pi()

    boundary_nodes
    |> Enum.with_index()
    |> Map.new(fn {node_id, index} ->
      theta = (two_pi * index) / n
      x = cx + radius * :math.cos(theta)
      y = cy + radius * :math.sin(theta)
      {node_id, {x, y}}
    end)
  end

  defp relax_iterations(positions, _graph, _interiors, 0), do: positions
  defp relax_iterations(positions, graph, interiors, steps) do
    new_positions =
      Enum.reduce(interiors, positions, fn node, acc ->
        neighbors = get_all_neighbors(graph, node)

        if neighbors == [] do
          acc
        else
          {sum_x, sum_y} =
            Enum.reduce(neighbors, {0.0, 0.0}, fn nbr, {sx, sy} ->
              {nx, ny} = Map.get(acc, nbr, {0.0, 0.0})
              {sx + nx, sy + ny}
            end)

          count = length(neighbors)
          Map.put(acc, node, {sum_x / count, sum_y / count})
        end
      end)

    relax_iterations(new_positions, graph, interiors, steps - 1)
  end

  defp get_all_neighbors(graph, node) do
    succs = Model.successors(graph, node) |> Enum.map(&elem(&1, 0))
    preds = Model.predecessors(graph, node) |> Enum.map(&elem(&1, 0))
    Enum.uniq(succs ++ preds)
  end
end
