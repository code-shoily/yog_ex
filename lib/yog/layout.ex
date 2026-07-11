defmodule Yog.Layout do
  @moduledoc """
  Algorithms for calculating 2D coordinates for graph nodes.

  Calculates coordinates mapping node IDs to `{x, y}` float coordinate tuples.
  These coordinates can be used for rendering graphs visually via custom SVG elements,
  exporting data for web dashboards (using Cytoscape.js or D3.js), or generating layouts.

  ## Overview

  | Algorithm | Function | Mathematical Model | Best For | Time Complexity |
  |-----------|----------|--------------------|----------|-----------------|
  | **Circular** | `circular/2` | Uniform spacing on unit circle | Symmetric/small graphs, cycles | $O(V)$ |
  | **Random** | `random/2` | Uniform distribution in bounding box | Initial states, baseline checks | $O(V)$ |
  | **Spring** | `spring/2` | Fruchterman-Reingold force model | Social networks, general graphs | $O(I \\cdot (V^2 + E))$ |
  | **Tutte** | `tutte/3` | Gauss-Seidel barycentric relaxation | Planar graphs, routing visual flow | $O(I \\cdot (V + E))$ |
  | **Shell** | `shell/3` | Concentric circles placement | Hierarchies, core-periphery structures | $O(V)$ |
  | **Multipartite** | `multipartite/3` | Parallel rows/columns alignment | Bipartite graphs, neural nets, flow nets | $O(V)$ |

  ## Graph Layout Visualization (Spring vs. Circular)

  The layout determines the structural aesthetic. Spring layout cluster connected nodes together, whereas Circular layout focuses purely on ordering.

  <div class="graphviz">
  graph LayoutComparison {
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];

    subgraph cluster_spring {
      label="Spring (Force-Directed)";
      color="#10b981";
      s1 -- s2; s2 -- s3; s3 -- s1;
      s1 -- s4; s4 -- s5; s5 -- s1;
    }

    subgraph cluster_circular {
      label="Circular";
      color="#3b82f6";
      c1 -- c2 -- c3 -- c4 -- c5 -- c1;
    }
  }
  </div>

  ## Usage Example

  Below is an example showing how layout coordinates can be mapped directly to generate
  a visual representation:

      iex> graph = Yog.from_unweighted_edges(:undirected, [{1, 2}, {2, 3}])
      iex> pos = Yog.Layout.circular(graph, radius: 10.0)
      iex> Map.keys(pos) |> Enum.sort()
      [1, 2, 3]

  """

  alias Yog.Graph
  alias Yog.Layout.Circular
  alias Yog.Layout.Geometry
  alias Yog.Layout.GraphViz
  alias Yog.Layout.Grid
  alias Yog.Layout.Multipartite
  alias Yog.Layout.Random
  alias Yog.Layout.Shell
  alias Yog.Layout.Spring
  alias Yog.Layout.Tutte

  @doc """
  Positions nodes uniformly spaced on a circle.

  Delegates to `Yog.Layout.Circular.layout/2`.
  """
  @spec circular(Graph.t(), keyword()) :: %{Graph.node_id() => {float(), float()}}
  def circular(graph, opts \\ []) do
    Circular.layout(graph, opts)
  end

  @doc """
  Positions nodes randomly within a specified bounding box.

  Delegates to `Yog.Layout.Random.layout/2`.
  """
  @spec random(Graph.t(), keyword()) :: %{Graph.node_id() => {float(), float()}}
  def random(graph, opts \\ []) do
    Random.layout(graph, opts)
  end

  @doc """
  Positions nodes using a spring/force-directed model (Fruchterman-Reingold).

  Delegates to `Yog.Layout.Spring.layout/2`.
  """
  @spec spring(Graph.t(), keyword()) :: %{Graph.node_id() => {float(), float()}}
  def spring(graph, opts \\ []) do
    Spring.layout(graph, opts)
  end

  @doc """
  Positions nodes using Tutte's barycentric embedding.

  Delegates to `Yog.Layout.Tutte.layout/3`.
  """
  @spec tutte(Graph.t(), [Graph.node_id()], keyword()) :: %{Graph.node_id() => {float(), float()}}
  def tutte(graph, boundary_nodes, opts \\ []) do
    Tutte.layout(graph, boundary_nodes, opts)
  end

  @doc """
  Positions nodes in concentric circles (shells).

  Delegates to `Yog.Layout.Shell.layout/3`.
  """
  @spec shell(Graph.t(), [[Graph.node_id()]], keyword()) :: %{
          Graph.node_id() => {float(), float()}
        }
  def shell(graph, shells, opts \\ []) do
    Shell.layout(graph, shells, opts)
  end

  @doc """
  Positions nodes in parallel layers (columns or rows).

  Delegates to `Yog.Layout.Multipartite.layout/3`.
  """
  @spec multipartite(Graph.t(), [[Graph.node_id()]], keyword()) :: %{
          Graph.node_id() => {float(), float()}
        }
  def multipartite(graph, layers, opts \\ []) do
    Multipartite.layout(graph, layers, opts)
  end

  @doc """
  Positions nodes deterministically on a 2D grid based on user-supplied rows or columns.

  Delegates to `Yog.Layout.Grid.layout/2`.
  """
  @spec grid(Graph.t(), keyword()) :: %{Graph.node_id() => {float(), float()}}
  def grid(graph, opts) do
    Grid.layout(graph, opts)
  end

  @doc """
  Positions nodes using an external GraphViz layout engine.

  Delegates to `Yog.Layout.GraphViz.layout/2`.
  """
  @spec graphviz(Graph.t() | Yog.Multi.Graph.t(), keyword()) :: %{
          any() => {float(), float()}
        }
  def graphviz(graph, opts \\ []) do
    GraphViz.layout(graph, opts)
  end

  @doc """
  Converts a center-based position map to bounding rectangle maps.

  Delegates to `Yog.Layout.Geometry.rects/2`.
  """
  @spec rects(%{any() => {float(), float()}}, keyword()) :: %{
          any() => {float(), float(), float(), float()}
        }
  def rects(positions, opts \\ []), do: Geometry.rects(positions, opts)

  @doc """
  Returns an anchor point on a bounding rectangle edge.

  Delegates to `Yog.Layout.Geometry.anchor/2`.
  """
  @spec anchor({float(), float(), float(), float()}, atom()) :: {float(), float()}
  def anchor(rect, direction), do: Geometry.anchor(rect, direction)

  @doc """
  Computes connector endpoints between nodes for a list of edges.

  Delegates to `Yog.Layout.Geometry.edge_endpoints/3`.
  """
  @spec edge_endpoints(%{any() => {float(), float()}}, [{any(), any()}], keyword()) :: [
          {{float(), float()}, {float(), float()}}
        ]
  def edge_endpoints(positions, edges, opts \\ []),
    do: Geometry.edge_endpoints(positions, edges, opts)

  @doc """
  Positions nodes manually based on a supplied map of coordinates, with options to validate and fill in missing nodes.

  ## Options

    * `:strict` - If `true`, raises `ArgumentError` if there are extra coordinates in `positions` for nodes not in the graph (default: `false`).
    * `:missing` - Strategy for placing nodes that are present in the graph but missing in the `positions` map:
      * `:error` - Raises `ArgumentError` if any nodes are missing coordinates.
      * `:center` - Places missing nodes at `:center`.
      * `:ignore` - Omit missing nodes from the returned coordinate map.
      * `:random` - Places missing nodes randomly.
      * `{:random, random_opts}` - Places missing nodes randomly with custom bounds (e.g. `[width: 10.0, height: 10.0]`).
      * `function` - A 1-arity function `(node_id -> {x, y})` that generates coordinates for each missing node.
      * Default: `{:random, []}`.
    * `:center` - The `{x, y}` coordinates of the center, used as default center for `:center` and `:random` missing placement (default: `{0.0, 0.0}`).
    * `:seed` - Seed for random positioning generator.

  ## Examples

      iex> graph = Yog.undirected() |> Yog.add_nodes_from([1, 2, 3])
      iex> pos = %{1 => {1.0, 2.0}, 2 => {3.0, 4.0}}
      iex> manual_pos = Yog.Layout.manual(graph, pos, missing: :center, center: {0.0, 0.0})
      iex> manual_pos
      %{1 => {1.0, 2.0}, 2 => {3.0, 4.0}, 3 => {0.0, 0.0}}

  """
  @spec manual(
          Graph.t(),
          %{Graph.node_id() => {float(), float()}},
          keyword()
        ) :: %{Graph.node_id() => {float(), float()}}
  def manual(graph, positions, opts \\ []) do
    strict = Keyword.get(opts, :strict, false)
    missing = Keyword.get(opts, :missing, {:random, []})
    center = Keyword.get(opts, :center, {0.0, 0.0})
    seed = Keyword.get(opts, :seed)

    graph_nodes = Yog.all_nodes(graph) |> MapSet.new()

    # 1. Validation for strict mode (extra positions)
    if strict do
      extra_nodes = MapSet.difference(Map.keys(positions) |> MapSet.new(), graph_nodes)

      if MapSet.size(extra_nodes) > 0 do
        raise ArgumentError,
              "Strict mode: positions map contains extra nodes not present in the graph: #{inspect(MapSet.to_list(extra_nodes))}"
      end
    end

    # 2. Filter out extra positions
    filtered_positions =
      Map.filter(positions, fn {id, _coords} -> MapSet.member?(graph_nodes, id) end)

    # 3. Identify missing nodes
    missing_nodes = MapSet.difference(graph_nodes, Map.keys(filtered_positions) |> MapSet.new())

    # 4. Fill in missing nodes if any
    if MapSet.size(missing_nodes) > 0 do
      filled =
        case missing do
          :error ->
            raise ArgumentError,
                  "Missing coordinates for nodes: #{inspect(MapSet.to_list(missing_nodes))}"

          :center ->
            Map.new(missing_nodes, fn id -> {id, center} end)

          :ignore ->
            %{}

          random
          when random in [:random, :random_opts] or
                 (is_tuple(random) and elem(random, 0) == :random) ->
            random_opts =
              case random do
                :random -> []
                {:random, ropts} -> ropts
              end

            width = Keyword.get(random_opts, :width, 1.0)
            height = Keyword.get(random_opts, :height, 1.0)

            {rcx, rcy} =
              case Keyword.get(random_opts, :center) do
                {cx, cy} -> {cx, cy}
                nil -> center
              end

            rseed = Keyword.get(random_opts, :seed, seed)

            if rseed do
              :rand.seed(:exsss, rseed)
            end

            min_x = rcx - width / 2.0
            min_y = rcy - height / 2.0

            Map.new(missing_nodes, fn id ->
              x = min_x + :rand.uniform() * width
              y = min_y + :rand.uniform() * height
              {id, {x, y}}
            end)

          fun when is_function(fun, 1) ->
            Map.new(missing_nodes, fn id ->
              case fun.(id) do
                {x, y} when is_number(x) and is_number(y) ->
                  {id, {x, y}}

                other ->
                  raise ArgumentError,
                        "Custom generator function must return a {float, float} coordinate tuple, got: #{inspect(other)}"
              end
            end)

          other ->
            raise ArgumentError, "Invalid option for :missing: #{inspect(other)}"
        end

      Map.merge(filtered_positions, filled)
    else
      filtered_positions
    end
  end

  @doc """
  Packs multiple position maps sequentially either horizontally or vertically with a gap.

  Useful for placing independent subgraphs side-by-side or stacked without overlapping.

  ## Options

    * `:direction` - Packing direction, either `:horizontal` or `:vertical` (default: `:horizontal`).
    * `:gap` - Gap size between consecutive bounding boxes (default: `0.0`).

  ## Examples

      iex> map_a = %{a: {0.0, 0.0}, b: {10.0, 10.0}}
      iex> map_b = %{c: {0.0, 0.0}, d: {5.0, 5.0}}
      iex> Yog.Layout.pack([map_a, map_b], direction: :horizontal, gap: 5.0)
      %{
        a: {0.0, 0.0},
        b: {10.0, 10.0},
        c: {15.0, 0.0},
        d: {20.0, 5.0}
      }

  """
  @spec pack([%{Graph.node_id() => {float(), float()}}], keyword()) :: %{
          Graph.node_id() => {float(), float()}
        }
  def pack(position_maps, opts \\ []) do
    direction = Keyword.get(opts, :direction, :horizontal)
    gap = Keyword.get(opts, :gap, 0.0) * 1.0

    if direction not in [:horizontal, :vertical] do
      raise ArgumentError, "Option :direction must be either :horizontal or :vertical"
    end

    # Fail fast on duplicate node IDs
    _merged = merge_position_maps(position_maps)

    pack_loop(position_maps, direction, gap, 0.0, [])
  end

  defp pack_loop([], _direction, _gap, _offset, acc) do
    Enum.reduce(Enum.reverse(acc), %{}, &Map.merge/2)
  end

  defp pack_loop([map | rest], direction, gap, offset, acc) do
    if map == %{} do
      pack_loop(rest, direction, gap, offset, [map | acc])
    else
      {min_x, max_x, min_y, max_y} = bounds(map)

      case direction do
        :horizontal ->
          width = max_x - min_x
          dx = offset - min_x
          translated = translate(map, dx, 0.0)
          pack_loop(rest, direction, gap, offset + width + gap, [translated | acc])

        :vertical ->
          height = max_y - min_y
          dy = offset - min_y
          translated = translate(map, 0.0, dy)
          pack_loop(rest, direction, gap, offset + height + gap, [translated | acc])
      end
    end
  end

  @doc """
  Merges a list of position maps into a single position map.

  Raises `ArgumentError` if there are duplicate node IDs across the maps.

  ## Examples

      iex> map_a = %{a: {1.0, 2.0}}
      iex> map_b = %{b: {3.0, 4.0}}
      iex> Yog.Layout.merge_position_maps([map_a, map_b])
      %{a: {1.0, 2.0}, b: {3.0, 4.0}}

  """
  @spec merge_position_maps([%{Graph.node_id() => {float(), float()}}]) :: %{
          Graph.node_id() => {float(), float()}
        }
  def merge_position_maps(position_maps) do
    keys = Enum.flat_map(position_maps, &Map.keys/1)

    if length(keys) != MapSet.size(MapSet.new(keys)) do
      duplicates =
        keys
        |> Enum.frequencies()
        |> Enum.filter(fn {_, count} -> count > 1 end)
        |> Enum.map(&elem(&1, 0))

      raise ArgumentError, "Duplicate node IDs found across position maps: #{inspect(duplicates)}"
    end

    Enum.reduce(position_maps, %{}, &Map.merge/2)
  end

  # ============= COORDINATE TRANSFORM HELPERS =============

  @doc """
  Calculates the bounding box `{min_x, max_x, min_y, max_y}` of the positions map.

  Returns `nil` if the positions map is empty.

  ## Examples

      iex> Yog.Layout.bounds(%{1 => {1.0, 2.0}, 2 => {5.0, -3.0}})
      {1.0, 5.0, -3.0, 2.0}

      iex> Yog.Layout.bounds(%{})
      nil

  """
  @spec bounds(%{Graph.node_id() => {float(), float()}}) ::
          {float(), float(), float(), float()} | nil
  def bounds(positions) when positions == %{}, do: nil

  def bounds(positions) do
    pos_values = Map.values(positions)
    [{x0, y0} | rest] = pos_values

    Enum.reduce(rest, {x0, x0, y0, y0}, fn {x, y}, {min_x, max_x, min_y, max_y} ->
      {min(min_x, x), max(max_x, x), min(min_y, y), max(max_y, y)}
    end)
  end

  @doc """
  Translates all coordinates by `dx` and `dy`.

  ## Examples

      iex> Yog.Layout.translate(%{1 => {1.0, 2.0}}, 2.0, -1.0)
      %{1 => {3.0, 1.0}}

  """
  @spec translate(%{Graph.node_id() => {float(), float()}}, float(), float()) :: %{
          Graph.node_id() => {float(), float()}
        }
  def translate(positions, dx, dy) do
    Map.new(positions, fn {id, {x, y}} -> {id, {x + dx, y + dy}} end)
  end

  @doc """
  Scales all coordinates by a single factor.

  ## Examples

      iex> Yog.Layout.scale(%{1 => {1.0, 2.0}}, 3.0)
      %{1 => {3.0, 6.0}}

  """
  @spec scale(%{Graph.node_id() => {float(), float()}}, float()) :: %{
          Graph.node_id() => {float(), float()}
        }
  def scale(positions, factor) do
    Map.new(positions, fn {id, {x, y}} -> {id, {x * factor, y * factor}} end)
  end

  @doc """
  Scales all coordinates by separate `sx` and `sy` factors.

  ## Examples

      iex> Yog.Layout.scale(%{1 => {1.0, 2.0}}, 3.0, -1.0)
      %{1 => {3.0, -2.0}}

  """
  @spec scale(%{Graph.node_id() => {float(), float()}}, float(), float()) :: %{
          Graph.node_id() => {float(), float()}
        }
  def scale(positions, sx, sy) do
    Map.new(positions, fn {id, {x, y}} -> {id, {x * sx, y * sy}} end)
  end

  @doc """
  Centers the layout at the specified coordinates.

  ## Options

    * `:at` - Bounding box center coordinates `{cx, cy}` (default: `{0.0, 0.0}`).

  ## Examples

      iex> Yog.Layout.center(%{1 => {0.0, 0.0}, 2 => {4.0, 2.0}}, at: {1.0, 1.0})
      %{1 => {-1.0, 0.0}, 2 => {3.0, 2.0}}

  """
  @spec center(%{Graph.node_id() => {float(), float()}}, keyword()) :: %{
          Graph.node_id() => {float(), float()}
        }
  def center(positions, opts \\ []) do
    {cx, cy} = Keyword.get(opts, :at, {0.0, 0.0})

    case bounds(positions) do
      nil ->
        %{}

      {min_x, max_x, min_y, max_y} ->
        curr_cx = (min_x + max_x) / 2.0
        curr_cy = (min_y + max_y) / 2.0
        translate(positions, cx - curr_cx, cy - curr_cy)
    end
  end

  @doc """
  Fits the layout coordinates inside a target bounding box, preserving aspect ratio by default.

  ## Options

    * `:width` - Target bounding box width (default: `1.0`).
    * `:height` - Target bounding box height (default: `1.0`).
    * `:padding` - Bounding box padding (default: `0.0`).
    * `:preserve_aspect` - Preserve aspect ratio of coordinate box (default: `true`).
    * `:center` - Center of layout space (default: `{width / 2.0, height / 2.0}`).

  ## Examples

      iex> pos = %{1 => {0.0, 0.0}, 2 => {10.0, 5.0}}
      iex> fitted = Yog.Layout.fit(pos, width: 100.0, height: 100.0, padding: 10.0, preserve_aspect: false)
      iex> Yog.Layout.bounds(fitted)
      {10.0, 90.0, 10.0, 90.0}

  """
  @spec fit(%{Graph.node_id() => {float(), float()}}, keyword()) :: %{
          Graph.node_id() => {float(), float()}
        }
  def fit(positions, opts \\ []) do
    width = Keyword.get(opts, :width, 1.0)
    height = Keyword.get(opts, :height, 1.0)
    padding = Keyword.get(opts, :padding, 0.0)
    preserve_aspect = Keyword.get(opts, :preserve_aspect, true)

    case bounds(positions) do
      nil ->
        %{}

      {min_x, max_x, min_y, max_y} ->
        {cx, cy} =
          case Keyword.get(opts, :center) do
            {cx, cy} -> {cx, cy}
            nil -> {width / 2.0, height / 2.0}
          end

        w_span = max_x - min_x
        h_span = max_y - min_y

        if w_span == 0.0 and h_span == 0.0 do
          Map.new(positions, fn {id, _} -> {id, {cx, cy}} end)
        else
          target_w = width - 2.0 * padding
          target_h = height - 2.0 * padding

          {scale_x, scale_y} =
            if preserve_aspect do
              s =
                cond do
                  w_span == 0.0 -> target_h / h_span
                  h_span == 0.0 -> target_w / w_span
                  true -> min(target_w / w_span, target_h / h_span)
                end

              {s, s}
            else
              sx = if w_span == 0.0, do: 1.0, else: target_w / w_span
              sy = if h_span == 0.0, do: 1.0, else: target_h / h_span
              {sx, sy}
            end

          curr_cx = (min_x + max_x) / 2.0
          curr_cy = (min_y + max_y) / 2.0

          Map.new(positions, fn {id, {x, y}} ->
            sx = cx + (x - curr_cx) * scale_x
            sy = cy + (y - curr_cy) * scale_y
            {id, {sx, sy}}
          end)
        end
    end
  end
end
