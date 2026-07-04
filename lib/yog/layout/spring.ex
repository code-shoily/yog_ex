defmodule Yog.Layout.Spring do
  @moduledoc """
  Spring layout algorithm (Fruchterman-Reingold force-directed) for positioning graph nodes in Elixir.

  This algorithm models a graph as a physical system of particles (nodes) and springs (edges) to
  reach an aesthetically pleasing layout by minimizing the total system energy. Nodes repel
  each other like electrically charged particles, while edges pull connected nodes closer like springs.

  ## Mathematical Model

  Given a graph $G = (V, E)$ in a 2D space of size $W \\times H$, the algorithm simulates two competing forces:

  1. **Repulsive Force ($f_r$):** Pushes every pair of nodes $(u, v)$ apart to prevent overlap and ensure spacing.
     $$f_r(d) = \\frac{k^2}{d}$$
     where $d$ is the Euclidean distance between $u$ and $v$.
  2. **Attractive Force ($f_a$):** Pulls connected nodes $(u, v) \\in E$ together to reflect topological proximity.
     $$f_a(d) = \\frac{d^2}{k} \\cdot w$$
     where $w$ is the optional edge weight multiplier.

  ### Parameters

  * **Optimal Node Distance ($k$):** Represents the target spacing between nodes. It is calculated based on the bounding box size:
    $$k = \\sqrt{\\frac{W \\cdot H}{|V|}}$$
  * **Cooling Schedule:** A maximum displacement limit ("temperature" $T$) decays linearly with each iteration to stabilize the simulation:
    $$T_i = T_{\\text{initial}} \\cdot \\left(1 - \\frac{i}{I}\\right)$$
    where $i$ is the current iteration and $I$ is the maximum number of iterations.

  ## Complexities

  * **Time Complexity:** $O(I \\cdot (V^2 + E))$ per simulation run, where $I$ is the number of iterations (default `50`), $V$ is the number of nodes, and $E$ is the number of edges.
  * **Space Complexity:** $O(V + E)$ auxiliary space to store displacements and positions.

  ## References

  * [Fruchterman & Reingold 1991 - Graph Drawing by Force-directed Placement](https://doi.org/10.1002/spe.4380211102)
  * [Wikipedia: Force-directed graph drawing](https://en.wikipedia.org/wiki/Force-directed_graph_drawing)
  """

  alias Yog.Graph
  alias Yog.Layout.Spring.BarnesHut

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
    * `:barnes_hut` - Boolean indicating whether to use the Barnes-Hut approximation to reduce repulsive force computation complexity from $O(V^2)$ to $O(V \log V)$ (default: `false`).
    * `:theta` - The Barnes-Hut threshold parameter $\theta$. A value of `0.0` yields exact computation, while higher values (e.g., `0.5` or `1.0`) trade layout quality for performance (default: `0.5`).

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_nodes_from([1, 2, 3]) |> Yog.add_edges!([{1, 2, 10}, {2, 3, 5}])
      iex> pos = Yog.Layout.Spring.layout(graph, iterations: 10)
      iex> Map.keys(pos) |> Enum.sort()
      [1, 2, 3]

      iex> graph = Yog.undirected() |> Yog.add_nodes_from([1, 2, 3]) |> Yog.add_edges!([{1, 2, 10}, {2, 3, 5}])
      iex> pos_bh = Yog.Layout.Spring.layout(graph, iterations: 10, barnes_hut: true, theta: 0.5)
      iex> Map.keys(pos_bh) |> Enum.sort()
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
    barnes_hut = Keyword.get(opts, :barnes_hut, false)
    theta = Keyword.get(opts, :theta, 0.5)

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
        if seed do
          :rand.seed(:exsss, seed)
        end

        positions = initialize_positions(nodes, width, height, center, initial_pos)

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
            initial_temp,
            barnes_hut,
            theta
          )

        # 5. Rescale to fit neatly inside bounding box (unless there are fixed nodes)
        if MapSet.size(fixed_nodes) > 0 do
          final_positions
        else
          rescale(final_positions, width, height, center)
        end
    end
  end

  defp initialize_positions(nodes, width, height, center, nil) do
    generate_random_positions(nodes, width, height, center)
  end

  defp initialize_positions(nodes, width, height, {cx, cy}, initial_pos) do
    min_x = cx - width / 2.0
    min_y = cy - height / 2.0

    Map.new(nodes, fn id ->
      position =
        case Map.fetch(initial_pos, id) do
          {:ok, {x, y}} when is_number(x) and is_number(y) ->
            {x, y}

          _ ->
            {min_x + :rand.uniform() * width, min_y + :rand.uniform() * height}
        end

      {id, position}
    end)
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

  defp run_iterations(
         positions,
         _edges,
         _k,
         _k_squared,
         _fixed,
         _use_weight,
         current,
         max_iterations,
         _initial_temp,
         _barnes_hut,
         _theta
       )
       when current >= max_iterations do
    positions
  end

  defp run_iterations(
         positions,
         edges,
         k,
         k_squared,
         fixed,
         use_weight,
         current,
         max_iterations,
         initial_temp,
         barnes_hut,
         theta
       ) do
    # Linear cooling
    temp = initial_temp * (1.0 - current / max_iterations)

    # Step 1 + 2: Repulsive and attractive forces
    displacements =
      positions
      |> compute_repulsion(k_squared, barnes_hut, theta)
      |> compute_attraction(positions, edges, k, use_weight)

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
            new_x = x + dx / dist * limited_dist
            new_y = y + dy / dist * limited_dist
            {id, {new_x, new_y}}
          else
            {id, {x, y}}
          end
        end
      end)

    run_iterations(
      new_positions,
      edges,
      k,
      k_squared,
      fixed,
      use_weight,
      current + 1,
      max_iterations,
      initial_temp,
      barnes_hut,
      theta
    )
  end

  defp compute_repulsion(positions, k_squared, barnes_hut, theta) do
    if barnes_hut do
      case BarnesHut.build_tree(positions) do
        nil ->
          Map.new(positions, fn {id, _} -> {id, {0.0, 0.0}} end)

        {tree, size} ->
          Map.new(positions, fn {id, {x, y}} ->
            {id, BarnesHut.compute_force(tree, id, x, y, k_squared, theta, size)}
          end)
      end
    else
      pos_list = Map.to_list(positions)
      initial_displacements = Map.new(pos_list, fn {id, _} -> {id, {0.0, 0.0}} end)
      accumulate_repulsion(pos_list, k_squared, initial_displacements)
    end
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
        fx = dx / dist * fr
        fy = dy / dist * fr

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
        {nil, _} ->
          acc

        {_, nil} ->
          acc

        {{ux, uy}, {vx, vy}} ->
          dx = ux - vx
          dy = uy - vy

          dist_sq = dx * dx + dy * dy

          if dist_sq == 0.0 do
            acc
          else
            dist = :math.sqrt(dist_sq)
            # Attraction force: fa = dist^2 / k
            fa = dist * dist / k * w
            fx = dx / dist * fa
            fy = dy / dist * fa

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

defmodule Yog.Layout.Spring.BarnesHut do
  @moduledoc false

  # Quadtree node types
  # - nil (empty)
  # - {:leaf, node_id, x, y}
  # - {:internal, mass, cx, cy, ids, nw, ne, sw, se}

  def build_tree(positions) do
    if map_size(positions) == 0 do
      nil
    else
      pos_values = Map.values(positions)
      [{x0, y0} | rest] = pos_values

      {min_x, max_x, min_y, max_y} =
        Enum.reduce(rest, {x0, x0, y0, y0}, fn {x, y}, {min_x, max_x, min_y, max_y} ->
          {min(min_x, x), max(max_x, x), min(min_y, y), max(max_y, y)}
        end)

      width = max_x - min_x
      height = max_y - min_y
      size = max(width, height)
      size = if size == 0.0, do: 1.0, else: size

      cx = (min_x + max_x) / 2.0
      cy = (min_y + max_y) / 2.0
      half_size = size / 2.0

      bounds = {cx - half_size, cy - half_size, cx + half_size, cy + half_size}

      root =
        Enum.reduce(positions, nil, fn {node_id, {x, y}}, acc ->
          insert(acc, bounds, node_id, x, y)
        end)

      {root, size}
    end
  end

  def compute_force(tree, u_id, ux, uy, k2, theta, size) do
    compute_repulsion_force(tree, u_id, ux, uy, k2, theta, size)
  end

  defp insert(nil, _bounds, node_id, x, y) do
    {:leaf, node_id, x, y}
  end

  defp insert({:leaf, leaf_id, lx, ly} = leaf, bounds, node_id, x, y) do
    if lx == x and ly == y do
      # Perturb slightly to avoid infinite subdivision
      px = x + (:rand.uniform() - 0.5) * 1.0e-5
      py = y + (:rand.uniform() - 0.5) * 1.0e-5
      insert(leaf, bounds, node_id, px, py)
    else
      internal = {:internal, 0.0, 0.0, 0.0, MapSet.new(), nil, nil, nil, nil}
      internal = insert_into_internal(internal, bounds, leaf_id, lx, ly)
      insert_into_internal(internal, bounds, node_id, x, y)
    end
  end

  defp insert({:internal, _, _, _, _, _, _, _, _} = internal, bounds, node_id, x, y) do
    insert_into_internal(internal, bounds, node_id, x, y)
  end

  defp insert_into_internal(
         {:internal, mass, cx, cy, ids, nw, ne, sw, se},
         {x_min, y_min, x_max, y_max},
         node_id,
         x,
         y
       ) do
    new_mass = mass + 1.0
    new_cx = (cx * mass + x) / new_mass
    new_cy = (cy * mass + y) / new_mass
    new_ids = MapSet.put(ids, node_id)

    mid_x = (x_min + x_max) / 2.0
    mid_y = (y_min + y_max) / 2.0

    cond do
      x < mid_x and y < mid_y ->
        new_nw = insert(nw, {x_min, y_min, mid_x, mid_y}, node_id, x, y)
        {:internal, new_mass, new_cx, new_cy, new_ids, new_nw, ne, sw, se}

      x >= mid_x and y < mid_y ->
        new_ne = insert(ne, {mid_x, y_min, x_max, mid_y}, node_id, x, y)
        {:internal, new_mass, new_cx, new_cy, new_ids, nw, new_ne, sw, se}

      x < mid_x and y >= mid_y ->
        new_sw = insert(sw, {x_min, mid_y, mid_x, y_max}, node_id, x, y)
        {:internal, new_mass, new_cx, new_cy, new_ids, nw, ne, new_sw, se}

      true ->
        new_se = insert(se, {mid_x, mid_y, x_max, y_max}, node_id, x, y)
        {:internal, new_mass, new_cx, new_cy, new_ids, nw, ne, sw, new_se}
    end
  end

  defp compute_repulsion_force(nil, _u_id, _ux, _uy, _k2, _theta, _s), do: {0.0, 0.0}

  defp compute_repulsion_force({:leaf, leaf_id, lx, ly}, u_id, ux, uy, k2, _theta, _s) do
    if leaf_id == u_id do
      {0.0, 0.0}
    else
      dx = ux - lx
      dy = uy - ly
      dist_sq = dx * dx + dy * dy

      {dx, dy, dist} =
        if dist_sq == 0.0 do
          px = (:rand.uniform() - 0.5) * 0.01
          py = (:rand.uniform() - 0.5) * 0.01
          {px, py, :math.sqrt(px * px + py * py)}
        else
          {dx, dy, :math.sqrt(dist_sq)}
        end

      fr = k2 / dist
      {dx / dist * fr, dy / dist * fr}
    end
  end

  defp compute_repulsion_force(
         {:internal, mass, cx, cy, ids, nw, ne, sw, se},
         u_id,
         ux,
         uy,
         k2,
         theta,
         s
       ) do
    dx = ux - cx
    dy = uy - cy
    dist_sq = dx * dx + dy * dy
    dist = :math.sqrt(dist_sq)

    if not MapSet.member?(ids, u_id) and dist > 0.0 and s / dist < theta do
      fr = k2 * mass / dist
      {dx / dist * fr, dy / dist * fr}
    else
      half_s = s / 2.0
      {fx1, fy1} = compute_repulsion_force(nw, u_id, ux, uy, k2, theta, half_s)
      {fx2, fy2} = compute_repulsion_force(ne, u_id, ux, uy, k2, theta, half_s)
      {fx3, fy3} = compute_repulsion_force(sw, u_id, ux, uy, k2, theta, half_s)
      {fx4, fy4} = compute_repulsion_force(se, u_id, ux, uy, k2, theta, half_s)
      {fx1 + fx2 + fx3 + fx4, fy1 + fy2 + fy3 + fy4}
    end
  end
end
