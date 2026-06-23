defmodule Yog.Layout.Spring do
  @moduledoc """
  Spring layout algorithm (Fruchterman-Reingold force-directed) for positioning graph nodes in Elixir.
  """

  alias Yog.Graph

  @doc """
  Positions nodes using a force-directed model.

  ## Options

    * `:width` - The width of the layout space (default: `1.0`).
    * `:height` - The height of the layout space (default: `1.0`).
    * `:center` - The `{x, y}` coordinates of the center (default: `{0.0, 0.0}`).
    * `:iterations` - Number of iterations to run the simulation (default: `50`).
    * `:k` - Optimal distance between nodes. If not provided, computed as `sqrt(width * height / V)`.
    * `:initial_temp` - Initial temperature/step limit (default: `0.1`).
    * `:weight` - Boolean indicating whether to respect edge weights (default: `true`).
    * `:fixed` - List of node IDs that should not move during simulation (default: `[]`).
    * `:initial_pos` - Map of `node_id => {x, y}` coordinates to use as initial layout. If not provided, random positions are used.
    * `:seed` - Seed for random positioning generator.

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_nodes_from([1, 2, 3]) |> Yog.add_edges([{1, 2, 10}, {2, 3, 5}])
      iex> pos = Yog.Layout.Spring.layout(graph, iterations: 10)
      iex> Map.keys(pos) |> Enum.sort()
      [1, 2, 3]

  """
  @spec layout(Graph.t(), keyword()) :: %{Graph.node_id() => {float(), float()}}
  def layout(graph, opts \\ []) do
    width = Keyword.get(opts, :width, 1.0)
    height = Keyword.get(opts, :height, 1.0)
    center = Keyword.get(opts, :center, {0.0, 0.0})
    iterations = Keyword.get(opts, :iterations, 50)
    initial_temp = Keyword.get(opts, :initial_temp, 0.1)
    use_weight = Keyword.get(opts, :weight, true)
    fixed_nodes = Keyword.get(opts, :fixed, []) |> MapSet.new()
    initial_pos = Keyword.get(opts, :initial_pos)
    seed = Keyword.get(opts, :seed)

    nodes = Yog.all_nodes(graph)
    n = length(nodes)

    cond do
      n == 0 ->
        %{}

      n == 1 ->
        [single] = nodes
        Map.new([{single, center}])

      true ->
        # 1. Optimal distance k
        k = Keyword.get(opts, :k) || :math.sqrt(width * height / n)
        k_squared = k * k

        # 2. Initial positions
        positions =
          cond do
            initial_pos ->
              initial_pos

            seed ->
              :rand.seed(:exsss, seed)
              generate_random_positions(nodes, width, height, center)

            true ->
              generate_random_positions(nodes, width, height, center)
          end

        # 3. Edges to simulate attraction
        edges = Yog.all_edges(graph)

        # 4. Run force simulation
        final_positions =
          run_iterations(
            positions,
            edges,
            k,
            k_squared,
            fixed_nodes,
            use_weight,
            0,
            iterations,
            initial_temp
          )

        # 5. Rescale to fit neatly inside bounding box (unless there are fixed nodes)
        if MapSet.size(fixed_nodes) > 0 do
          final_positions
        else
          rescale(final_positions, width, height, center)
        end
    end
  end

  defp generate_random_positions(nodes, width, height, {cx, cy}) do
    min_x = cx - width / 2.0
    min_y = cy - height / 2.0

    Map.new(nodes, fn id ->
      x = min_x + :rand.uniform() * width
      y = min_y + :rand.uniform() * height
      {id, {x, y}}
    end)
  end

  defp run_iterations(positions, _edges, _k, _k_squared, _fixed, _use_weight, current, max_iterations, _initial_temp)
       when current >= max_iterations do
    positions
  end

  defp run_iterations(positions, edges, k, k_squared, fixed, use_weight, current, max_iterations, initial_temp) do
    # Linear cooling
    temp = initial_temp * (1.0 - current / max_iterations)

    # Step 1: Repulsive forces
    displacements = compute_repulsion(positions, k_squared)

    # Step 2: Attractive forces
    displacements = compute_attraction(displacements, positions, edges, k, use_weight)

    # Step 3: Apply displacements to non-fixed nodes
    new_positions =
      Map.new(positions, fn {id, {x, y}} ->
        if MapSet.member?(fixed, id) do
          {id, {x, y}}
        else
          {dx, dy} = Map.fetch!(displacements, id)
          dist = :math.sqrt(dx * dx + dy * dy)

          if dist > 0.0 do
            limited_dist = min(dist, temp)
            new_x = x + (dx / dist) * limited_dist
            new_y = y + (dy / dist) * limited_dist
            {id, {new_x, new_y}}
          else
            {id, {x, y}}
          end
        end
      end)

    run_iterations(new_positions, edges, k, k_squared, fixed, use_weight, current + 1, max_iterations, initial_temp)
  end

  defp compute_repulsion(positions, k_squared) do
    pos_list = Map.to_list(positions)
    initial_displacements = Map.new(pos_list, fn {id, _} -> {id, {0.0, 0.0}} end)
    accumulate_repulsion(pos_list, k_squared, initial_displacements)
  end

  defp accumulate_repulsion([], _k2, displacements), do: displacements
  defp accumulate_repulsion([_], _k2, displacements), do: displacements
  defp accumulate_repulsion([{u_id, {ux, uy}} | rest], k2, displacements) do
    displacements =
      Enum.reduce(rest, displacements, fn {v_id, {vx, vy}}, acc ->
        dx = ux - vx
        dy = uy - vy

        dist_sq = dx * dx + dy * dy

        {dx, dy, dist} =
          if dist_sq == 0.0 do
            # Break symmetry if overlapping
            px = (:rand.uniform() - 0.5) * 0.01
            py = (:rand.uniform() - 0.5) * 0.01
            {px, py, :math.sqrt(px * px + py * py)}
          else
            {dx, dy, :math.sqrt(dist_sq)}
          end

        # Repulsion force: fr = k^2 / dist
        fr = k2 / dist
        fx = (dx / dist) * fr
        fy = (dy / dist) * fr

        acc
        |> Map.update!(u_id, fn {ux_disp, uy_disp} -> {ux_disp + fx, uy_disp + fy} end)
        |> Map.update!(v_id, fn {vx_disp, vy_disp} -> {vx_disp - fx, vy_disp - fy} end)
      end)

    accumulate_repulsion(rest, k2, displacements)
  end

  defp compute_attraction(displacements, positions, edges, k, use_weight) do
    Enum.reduce(edges, displacements, fn {u_id, v_id, weight}, acc ->
      w = if use_weight and is_number(weight), do: weight, else: 1.0

      case {Map.get(positions, u_id), Map.get(positions, v_id)} do
        {nil, _} -> acc
        {_, nil} -> acc
        {{ux, uy}, {vx, vy}} ->
          dx = ux - vx
          dy = uy - vy

          dist_sq = dx * dx + dy * dy

          if dist_sq == 0.0 do
            acc
          else
            dist = :math.sqrt(dist_sq)
            # Attraction force: fa = dist^2 / k
            fa = (dist * dist) / k * w
            fx = (dx / dist) * fa
            fy = (dy / dist) * fa

            acc
            |> Map.update!(u_id, fn {ux_disp, uy_disp} -> {ux_disp - fx, uy_disp - fy} end)
            |> Map.update!(v_id, fn {vx_disp, vy_disp} -> {vx_disp + fx, vy_disp + fy} end)
          end
      end
    end)
  end

  defp rescale(positions, width, height, {cx, cy}) do
    pos_values = Map.values(positions)

    case pos_values do
      [] ->
        %{}

      [{x0, y0} | rest] ->
        {min_x, max_x, min_y, max_y} =
          Enum.reduce(rest, {x0, x0, y0, y0}, fn {x, y}, {min_x, max_x, min_y, max_y} ->
            {min(min_x, x), max(max_x, x), min(min_y, y), max(max_y, y)}
          end)

        if min_x == max_x and min_y == max_y do
          Map.new(positions, fn {id, _} -> {id, {cx, cy}} end)
        else
          margin = 0.90
          w_span = max_x - min_x
          h_span = max_y - min_y

          target_w = width * margin
          target_h = height * margin

          scale_x = if w_span > 0, do: target_w / w_span, else: 1.0
          scale_y = if h_span > 0, do: target_h / h_span, else: 1.0

          curr_cx = (min_x + max_x) / 2.0
          curr_cy = (min_y + max_y) / 2.0

          Map.new(positions, fn {id, {x, y}} ->
            scaled_x = cx + (x - curr_cx) * scale_x
            scaled_y = cy + (y - curr_cy) * scale_y
            {id, {scaled_x, scaled_y}}
          end)
        end
    end
  end
end
