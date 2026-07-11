defmodule Yog.Layout.Geometry do
  @moduledoc """
  Geometry helpers for converting center-based node positions to bounding rectangles,
  computing anchor points on rectangle edges, and deriving connector endpoints for edges.

  These utilities are designed to support rendering pipelines that need to convert
  abstract layout coordinates into concrete geometric primitives for drawing.
  """

  @doc """
  Converts a center-based position map to a map of bounding rectangles.

  Each entry `node_id => {cx, cy}` becomes `node_id => {left_x, top_y, width, height}`,
  where `left_x = cx - w/2` and `top_y = cy - h/2`.

  ## Options

    * `:size` - Either a `{w, h}` tuple applied uniformly to all nodes, or an arity-2
      function `fn node_id, {cx, cy} -> {w, h} end` for per-node sizes.
      Defaults to `{1.0, 1.0}`.

  ## Examples

      iex> Yog.Layout.Geometry.rects(%{a: {10.0, 20.0}}, size: {4.0, 2.0})
      %{a: {8.0, 19.0, 4.0, 2.0}}

  """
  @spec rects(%{any() => {float(), float()}}, keyword()) ::
          %{any() => {float(), float(), float(), float()}}
  def rects(positions, opts \\ []) do
    size_opt = Keyword.get(opts, :size, {1.0, 1.0})

    Map.new(positions, fn {node_id, {cx, cy}} ->
      {w, h} =
        case size_opt do
          {w, h} -> {w * 1.0, h * 1.0}
          fun when is_function(fun, 2) -> fun.(node_id, {cx, cy})
        end

      {node_id, {cx - w / 2.0, cy - h / 2.0, w, h}}
    end)
  end

  @doc """
  Returns a point on the edge of a bounding rectangle.

  The rectangle is given as `{x, y, w, h}` where `x` and `y` are the top-left corner.

  ## Directions

    * `:top` — top-center `{x + w/2, y}`
    * `:bottom` — bottom-center `{x + w/2, y + h}`
    * `:left` — left-center `{x, y + h/2}`
    * `:right` — right-center `{x + w, y + h/2}`
    * `:top_left` — `{x, y}`
    * `:top_right` — `{x + w, y}`
    * `:bottom_left` — `{x, y + h}`
    * `:bottom_right` — `{x + w, y + h}`
    * `:center` — `{x + w/2, y + h/2}`

  ## Examples

      iex> Yog.Layout.Geometry.anchor({10.0, 20.0, 4.0, 2.0}, :right)
      {14.0, 21.0}

      iex> Yog.Layout.Geometry.anchor({10.0, 20.0, 4.0, 2.0}, :center)
      {12.0, 21.0}

      iex> Yog.Layout.Geometry.anchor({10.0, 20.0, 4.0, 2.0}, :top)
      {12.0, 20.0}

      iex> Yog.Layout.Geometry.anchor({10.0, 20.0, 4.0, 2.0}, :bottom)
      {12.0, 22.0}

      iex> Yog.Layout.Geometry.anchor({10.0, 20.0, 4.0, 2.0}, :left)
      {10.0, 21.0}

  """
  @spec anchor({float(), float(), float(), float()}, atom()) :: {float(), float()}
  def anchor({x, y, w, h}, direction) do
    case direction do
      :top -> {x + w / 2.0, y}
      :bottom -> {x + w / 2.0, y + h}
      :left -> {x, y + h / 2.0}
      :right -> {x + w, y + h / 2.0}
      :top_left -> {x, y}
      :top_right -> {x + w, y}
      :bottom_left -> {x, y + h}
      :bottom_right -> {x + w, y + h}
      :center -> {x + w / 2.0, y + h / 2.0}
    end
  end

  @doc """
  Returns connector endpoints for a list of `{from_id, to_id}` edge pairs.

  Without `:node_size`, endpoints are the node centers. With `:node_size`, endpoints
  are clipped to the closest cardinal side midpoint of each node's bounding rectangle.

  ## Cardinal side selection

  Given `dx = to_cx - from_cx` and `dy = to_cy - from_cy`:

    * If `dx == 0` and `dy == 0`: returns centers (overlapping nodes degrade gracefully).
    * If `abs(dx) >= abs(dy)`: horizontal dominance.
      From-node uses `:right` if `dx > 0`, else `:left`.
      To-node uses `:left` if `dx > 0`, else `:right`.
    * Else: vertical dominance.
      From-node uses `:bottom` if `dy > 0`, else `:top`.
      To-node uses `:top` if `dy > 0`, else `:bottom`.

  ## Options

    * `:node_size` — Either a `{w, h}` tuple or an arity-2 function
      `fn node_id, {cx, cy} -> {w, h} end`. When provided, endpoints are clipped
      to rect edges; otherwise raw centers are returned.

  ## Examples

      iex> Yog.Layout.Geometry.edge_endpoints(
      ...>   %{a: {0.0, 0.0}, b: {10.0, 0.0}},
      ...>   [{:a, :b}],
      ...>   node_size: {2.0, 2.0}
      ...> )
      [{{1.0, 0.0}, {9.0, 0.0}}]

  """
  @spec edge_endpoints(
          %{any() => {float(), float()}},
          [{any(), any()}],
          keyword()
        ) :: [{{float(), float()}, {float(), float()}}]
  def edge_endpoints(positions, edges, opts \\ []) do
    node_size = Keyword.get(opts, :node_size)

    rects_map =
      if node_size do
        rects(positions, size: node_size)
      else
        nil
      end

    Enum.map(edges, fn {from_id, to_id} ->
      {from_cx, from_cy} = Map.fetch!(positions, from_id)
      {to_cx, to_cy} = Map.fetch!(positions, to_id)

      dx = to_cx - from_cx
      dy = to_cy - from_cy

      if rects_map do
        from_rect = Map.fetch!(rects_map, from_id)
        to_rect = Map.fetch!(rects_map, to_id)

        {from_dir, to_dir} = cardinal_directions(dx, dy)

        from_point = anchor(from_rect, from_dir)
        to_point = anchor(to_rect, to_dir)

        {from_point, to_point}
      else
        {{from_cx, from_cy}, {to_cx, to_cy}}
      end
    end)
  end

  defp cardinal_directions(dx, dy) when dx == 0 and dy == 0, do: {:center, :center}

  defp cardinal_directions(dx, dy) when abs(dx) >= abs(dy) do
    if dx > 0 do
      {:right, :left}
    else
      {:left, :right}
    end
  end

  defp cardinal_directions(_dx, dy) do
    if dy > 0 do
      {:bottom, :top}
    else
      {:top, :bottom}
    end
  end
end
