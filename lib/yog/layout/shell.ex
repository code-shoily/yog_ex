defmodule Yog.Layout.Shell do
  @moduledoc """
  Shell layout algorithm for positioning graph nodes in concentric circles.

  Groups nodes into user-specified "shells" (concentric circles) and positions the
  nodes in each shell uniformly along its circumference. This is extremely useful
  for hierarchical visualizations, bipartite/tripartite visual grouping, or displaying
  networks with distinct core/periphery structures.

  ## Mathematical Model

  Given a list of shells $S = [S_0, S_1, \\dots, S_m]$, where each $S_j$ is a list of node IDs:

  1. Each shell $S_j$ is assigned a radius $R_j$. If not specified, radii are linearly spaced:
     $$R_j = \\frac{j + 1}{m + 1}$$
  2. The nodes within shell $S_j$ are positioned using the circular layout equations:
     $$\\theta_i = \\frac{2 \\pi \\cdot i}{|S_j|}$$
     $$x_i = c_x + R_j \\cdot \\cos(\\theta_i)$$
     $$y_i = c_y + R_j \\cdot \\sin(\\theta_i)$$

  For a single-node shell ($|S_j| = 1$), the node is placed at the center if it is the only shell, or on the circle circumference if there are other shells.

  ## Complexities

  * **Time Complexity:** $O(V)$ where $V$ is the number of nodes.
  * **Space Complexity:** $O(V)$ auxiliary space.
  """

  alias Yog.Graph

  @doc """
  Positions nodes in concentric circles (shells).

  Requires a list of shells, where each shell is a list of node IDs.

  ## Options

    * `:center` - The `{x, y}` coordinates of the center of the shells (default: `{0.0, 0.0}`).
    * `:radii` - Optional list of float radii, one for each shell.

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_nodes_from([1, 2, 3, 4])
      iex> pos = Yog.Layout.Shell.layout(graph, [[1, 2], [3, 4]])
      iex> Map.keys(pos) |> Enum.sort()
      [1, 2, 3, 4]

  """
  @spec layout(Graph.t(), [[Graph.node_id()]], keyword()) :: %{Graph.node_id() => {float(), float()}}
  def layout(graph, shells, opts \\ []) do
    {cx, cy} = Keyword.get(opts, :center, {0.0, 0.0})
    custom_radii = Keyword.get(opts, :radii)

    nodes = Yog.all_nodes(graph)
    m = length(shells)

    cond do
      m == 0 ->
        %{}

      Enum.any?(shells, &Enum.empty?/1) ->
        raise ArgumentError, "Shells must not contain empty lists"

      # Verify that all elements in shells are nodes in the graph
      Enum.any?(shells, fn shell -> Enum.any?(shell, fn id -> id not in nodes end) end) ->
        raise ArgumentError, "All shell nodes must exist in the graph"

      true ->
        # Calculate radii for each shell
        radii =
          cond do
            custom_radii && length(custom_radii) == m ->
              custom_radii

            custom_radii ->
              raise ArgumentError, "Length of radii list must match the number of shells"

            true ->
              # Linear spacing: R_j = (j + 1) / m
              Enum.map(0..(m - 1), fn j -> (j + 1.0) / m end)
          end

        # Lay out each shell and merge results
        shells
        |> Enum.zip(radii)
        |> Enum.reduce(%{}, fn {shell_nodes, r}, acc ->
          shell_pos = position_shell(shell_nodes, r, cx, cy, m)
          Map.merge(acc, shell_pos)
        end)
    end
  end

  defp position_shell(shell_nodes, radius, cx, cy, total_shells) do
    n = length(shell_nodes)

    cond do
      n == 1 && total_shells == 1 ->
        [single] = shell_nodes
        Map.new([{single, {cx, cy}}])

      true ->
        two_pi = 2 * :math.pi()

        shell_nodes
        |> Enum.with_index()
        |> Map.new(fn {node_id, index} ->
          theta = (two_pi * index) / n
          x = cx + radius * :math.cos(theta)
          y = cy + radius * :math.sin(theta)
          {node_id, {x, y}}
        end)
    end
  end
end
