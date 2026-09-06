defmodule Yog.PBT.LayoutTest do
  @moduledoc """
  Property-based tests for Yog.Layout and layout helpers.

  Invariants tested (issue #292):
    - Every graph node gets exactly one coordinate
    - No unexpected extra coordinates in strict/manual modes
    - translate preserves pairwise deltas
    - scale scales coordinates predictably
    - fit keeps bounds within requested dimensions
    - center moves the bounding box center correctly
    - circular layout places nodes on the requested radius
    - grid layout validates duplicate and missing node IDs
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  @epsilon 1.0e-9

  # ──────────────────────────────────────────────────────
  # Helpers
  # ──────────────────────────────────────────────────────

  defp assert_coords_close(pos1, pos2) do
    for {id, {x1, y1}} <- pos1 do
      {x2, y2} = Map.fetch!(pos2, id)
      assert_in_delta x1, x2, @epsilon
      assert_in_delta y1, y2, @epsilon
    end
  end

  # Graph generator that guarantees at least `min` nodes
  defp nonempty_graph_gen(min \\ 2) do
    gen all(
          kind <- StreamData.member_of([:directed, :undirected]),
          nodes <- node_list_gen(min, 15, 500),
          weights <- weight_list_gen(length(nodes))
        ) do
      build_graph(kind, nodes, weights)
    end
  end

  # Position map generator from a real layout (avoids degenerate hand-crafted maps)
  defp position_map_gen do
    gen all(graph <- nonempty_graph_gen()) do
      Yog.Layout.circular(graph)
    end
  end

  # Generate a non-empty position map guaranteed to have at least 2 entries
  defp position_map_gen(min_nodes) do
    gen all(graph <- nonempty_graph_gen(min_nodes)) do
      Yog.Layout.circular(graph)
    end
  end

  defp positive_float_gen do
    StreamData.float(min: 0.1, max: 100.0)
  end

  defp float_gen do
    StreamData.float(min: -100.0, max: 100.0)
  end

  # ──────────────────────────────────────────────────────
  # 1. Node-Coordinate Bijection (Domain Preservation)
  # ──────────────────────────────────────────────────────

  describe "Node-Coordinate Bijection" do
    property "circular: every graph node gets exactly one coordinate" do
      check all(graph <- graph_gen()) do
        pos = Yog.Layout.circular(graph)
        graph_nodes = Yog.all_nodes(graph) |> MapSet.new()
        pos_nodes = Map.keys(pos) |> MapSet.new()

        assert MapSet.equal?(graph_nodes, pos_nodes)

        for {_id, {x, y}} <- pos do
          assert is_float(x)
          assert is_float(y)
        end
      end
    end

    property "random: every graph node gets exactly one coordinate" do
      check all(graph <- graph_gen()) do
        pos = Yog.Layout.random(graph, seed: 42)
        graph_nodes = Yog.all_nodes(graph) |> MapSet.new()
        pos_nodes = Map.keys(pos) |> MapSet.new()
        assert MapSet.equal?(graph_nodes, pos_nodes)
      end
    end

    property "spring: every graph node gets exactly one coordinate" do
      check all(graph <- graph_gen()) do
        pos = Yog.Layout.spring(graph, iterations: 5, seed: 42)
        graph_nodes = Yog.all_nodes(graph) |> MapSet.new()
        pos_nodes = Map.keys(pos) |> MapSet.new()
        assert MapSet.equal?(graph_nodes, pos_nodes)
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # 2. Strict / Manual Mode — No Unexpected Coordinates
  # ──────────────────────────────────────────────────────

  describe "Manual / Strict Mode Invariants" do
    property "manual with full positions preserves exact coordinates" do
      check all(graph <- nonempty_graph_gen()) do
        seed_pos = Yog.Layout.circular(graph)
        result = Yog.Layout.manual(graph, seed_pos)

        assert_coords_close(seed_pos, result)
      end
    end

    property "manual strict: extra coordinates raise ArgumentError" do
      check all(graph <- nonempty_graph_gen()) do
        seed_pos = Yog.Layout.circular(graph)
        extra_pos = Map.put(seed_pos, :__bogus_node__, {0.0, 0.0})

        assert_raise ArgumentError, fn ->
          Yog.Layout.manual(graph, extra_pos, strict: true)
        end
      end
    end

    property "manual non-strict: extra coordinates silently ignored" do
      check all(graph <- nonempty_graph_gen()) do
        seed_pos = Yog.Layout.circular(graph)
        extra_pos = Map.put(seed_pos, :__bogus_node__, {0.0, 0.0})

        result = Yog.Layout.manual(graph, extra_pos, strict: false)
        graph_nodes = Yog.all_nodes(graph) |> MapSet.new()
        result_nodes = Map.keys(result) |> MapSet.new()

        assert MapSet.equal?(graph_nodes, result_nodes)
        refute Map.has_key?(result, :__bogus_node__)
      end
    end

    property "manual missing: :error raises for incomplete positions" do
      check all(graph <- nonempty_graph_gen(3)) do
        nodes = Yog.all_nodes(graph)
        partial = Yog.Layout.circular(graph) |> Map.delete(hd(nodes))

        assert_raise ArgumentError, fn ->
          Yog.Layout.manual(graph, partial, missing: :error)
        end
      end
    end

    property "manual missing: :center places missing nodes at center" do
      check all(
              graph <- nonempty_graph_gen(3),
              cx <- float_gen(),
              cy <- float_gen()
            ) do
        nodes = Yog.all_nodes(graph)
        dropped = hd(nodes)
        partial = Yog.Layout.circular(graph) |> Map.delete(dropped)

        result = Yog.Layout.manual(graph, partial, missing: :center, center: {cx, cy})
        {rx, ry} = Map.fetch!(result, dropped)
        assert_in_delta rx, cx, @epsilon
        assert_in_delta ry, cy, @epsilon
      end
    end

    property "manual missing: :ignore omits missing nodes" do
      check all(graph <- nonempty_graph_gen(3)) do
        nodes = Yog.all_nodes(graph)
        dropped = hd(nodes)
        partial = Yog.Layout.circular(graph) |> Map.delete(dropped)

        result = Yog.Layout.manual(graph, partial, missing: :ignore)
        refute Map.has_key?(result, dropped)
        assert map_size(result) == length(nodes) - 1
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # 3. Translate Preserves Pairwise Deltas
  # ──────────────────────────────────────────────────────

  describe "Translate Invariants" do
    property "translate preserves pairwise deltas" do
      check all(
              pos <- position_map_gen(2),
              dx <- float_gen(),
              dy <- float_gen()
            ) do
        translated = Yog.Layout.translate(pos, dx, dy)
        pairs = Map.keys(pos) |> pairs_of()

        for {a, b} <- pairs do
          {ax, ay} = pos[a]
          {bx, by} = pos[b]
          {tax, tay} = translated[a]
          {tbx, tby} = translated[b]

          assert_in_delta(bx - ax, tbx - tax, @epsilon)
          assert_in_delta(by - ay, tby - tay, @epsilon)
        end
      end
    end

    property "translate identity: translate(pos, 0, 0) == pos" do
      check all(pos <- position_map_gen()) do
        assert_coords_close(pos, Yog.Layout.translate(pos, 0.0, 0.0))
      end
    end

    property "translate invertibility: translate(translate(pos, dx, dy), -dx, -dy) ≈ pos" do
      check all(
              pos <- position_map_gen(),
              dx <- float_gen(),
              dy <- float_gen()
            ) do
        roundtrip = pos |> Yog.Layout.translate(dx, dy) |> Yog.Layout.translate(-dx, -dy)
        assert_coords_close(pos, roundtrip)
      end
    end

    property "translate additivity: two consecutive translates equal one combined" do
      check all(
              pos <- position_map_gen(),
              dx1 <- float_gen(),
              dy1 <- float_gen(),
              dx2 <- float_gen(),
              dy2 <- float_gen()
            ) do
        sequential = pos |> Yog.Layout.translate(dx1, dy1) |> Yog.Layout.translate(dx2, dy2)
        combined = Yog.Layout.translate(pos, dx1 + dx2, dy1 + dy2)
        assert_coords_close(sequential, combined)
      end
    end

    property "translate transforms bounds predictably" do
      check all(
              pos <- position_map_gen(),
              dx <- float_gen(),
              dy <- float_gen()
            ) do
        {min_x, max_x, min_y, max_y} = Yog.Layout.bounds(pos)
        {tmin_x, tmax_x, tmin_y, tmax_y} = Yog.Layout.bounds(Yog.Layout.translate(pos, dx, dy))

        assert_in_delta tmin_x, min_x + dx, @epsilon
        assert_in_delta tmax_x, max_x + dx, @epsilon
        assert_in_delta tmin_y, min_y + dy, @epsilon
        assert_in_delta tmax_y, max_y + dy, @epsilon
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # 4. Scale Scales Coordinates Predictably
  # ──────────────────────────────────────────────────────

  describe "Scale Invariants" do
    property "scale identity: scale(pos, 1.0) == pos" do
      check all(pos <- position_map_gen()) do
        assert_coords_close(pos, Yog.Layout.scale(pos, 1.0))
      end
    end

    property "scale composition: scale(scale(pos, s1), s2) ≈ scale(pos, s1 * s2)" do
      check all(
              pos <- position_map_gen(),
              s1 <- StreamData.float(min: 0.1, max: 10.0),
              s2 <- StreamData.float(min: 0.1, max: 10.0)
            ) do
        sequential = pos |> Yog.Layout.scale(s1) |> Yog.Layout.scale(s2)
        combined = Yog.Layout.scale(pos, s1 * s2)

        for {id, {x1, y1}} <- sequential do
          {x2, y2} = Map.fetch!(combined, id)
          # Slightly larger epsilon for composition of floats
          assert_in_delta x1, x2, 1.0e-6
          assert_in_delta y1, y2, 1.0e-6
        end
      end
    end

    property "uniform scale multiplies every coordinate by factor" do
      check all(
              pos <- position_map_gen(),
              factor <- StreamData.float(min: -10.0, max: 10.0)
            ) do
        scaled = Yog.Layout.scale(pos, factor)

        for {id, {x, y}} <- pos do
          {sx, sy} = Map.fetch!(scaled, id)
          assert_in_delta sx, x * factor, @epsilon
          assert_in_delta sy, y * factor, @epsilon
        end
      end
    end

    property "non-uniform scale multiplies x by sx and y by sy" do
      check all(
              pos <- position_map_gen(),
              sx <- StreamData.float(min: -10.0, max: 10.0),
              sy <- StreamData.float(min: -10.0, max: 10.0)
            ) do
        scaled = Yog.Layout.scale(pos, sx, sy)

        for {id, {x, y}} <- pos do
          {rx, ry} = Map.fetch!(scaled, id)
          assert_in_delta rx, x * sx, @epsilon
          assert_in_delta ry, y * sy, @epsilon
        end
      end
    end

    property "scale preserves node set" do
      check all(
              pos <- position_map_gen(),
              factor <- StreamData.float(min: -10.0, max: 10.0)
            ) do
        scaled = Yog.Layout.scale(pos, factor)
        assert Map.keys(scaled) |> MapSet.new() == Map.keys(pos) |> MapSet.new()
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # 5. Fit Keeps Bounds Within Requested Dimensions
  # ──────────────────────────────────────────────────────

  describe "Fit Invariants" do
    property "fit: all coordinates within target bounding box" do
      check all(
              pos <- position_map_gen(),
              width <- StreamData.float(min: 10.0, max: 100.0),
              height <- StreamData.float(min: 10.0, max: 100.0),
              padding <- StreamData.float(min: 0.0, max: 2.0)
            ) do
        fitted = Yog.Layout.fit(pos, width: width, height: height, padding: padding)

        if map_size(fitted) > 0 do
          {min_x, max_x, min_y, max_y} = Yog.Layout.bounds(fitted)

          # The fitted bounds should lie within [padding, width - padding] x [padding, height - padding]
          # (default center is {width/2, height/2}, so actual box is [0, width] x [0, height] minus padding)
          assert min_x >= padding - @epsilon
          assert max_x <= width - padding + @epsilon
          assert min_y >= padding - @epsilon
          assert max_y <= height - padding + @epsilon
        end
      end
    end

    property "fit preserves node set" do
      check all(pos <- position_map_gen()) do
        fitted = Yog.Layout.fit(pos, width: 10.0, height: 10.0)
        assert Map.keys(fitted) |> MapSet.new() == Map.keys(pos) |> MapSet.new()
      end
    end

    property "fit: single-node layout places node at center" do
      check all(
              graph <- nonempty_graph_gen(1),
              width <- positive_float_gen(),
              height <- positive_float_gen()
            ) do
        # Make a single-node graph
        node = hd(Yog.all_nodes(graph))
        pos = %{node => {42.0, 99.0}}

        fitted = Yog.Layout.fit(pos, width: width, height: height)
        {fx, fy} = Map.fetch!(fitted, node)

        assert_in_delta fx, width / 2.0, @epsilon
        assert_in_delta fy, height / 2.0, @epsilon
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # 6. Center Moves Bounding Box Center Correctly
  # ──────────────────────────────────────────────────────

  describe "Center Invariants" do
    property "center: bounding box center equals the target point" do
      check all(
              pos <- position_map_gen(),
              cx <- float_gen(),
              cy <- float_gen()
            ) do
        centered = Yog.Layout.center(pos, at: {cx, cy})
        {min_x, max_x, min_y, max_y} = Yog.Layout.bounds(centered)

        actual_cx = (min_x + max_x) / 2.0
        actual_cy = (min_y + max_y) / 2.0

        assert_in_delta actual_cx, cx, @epsilon
        assert_in_delta actual_cy, cy, @epsilon
      end
    end

    property "center is idempotent: centering twice at same point yields same result" do
      check all(
              pos <- position_map_gen(),
              cx <- float_gen(),
              cy <- float_gen()
            ) do
        once = Yog.Layout.center(pos, at: {cx, cy})
        twice = Yog.Layout.center(once, at: {cx, cy})
        assert_coords_close(once, twice)
      end
    end

    property "center preserves pairwise distances" do
      check all(
              pos <- position_map_gen(2),
              cx <- float_gen(),
              cy <- float_gen()
            ) do
        centered = Yog.Layout.center(pos, at: {cx, cy})
        pairs = Map.keys(pos) |> pairs_of()

        for {a, b} <- pairs do
          {ax, ay} = pos[a]
          {bx, by} = pos[b]
          orig_dist = :math.sqrt((bx - ax) ** 2 + (by - ay) ** 2)

          {cax, cay} = centered[a]
          {cbx, cby} = centered[b]
          new_dist = :math.sqrt((cbx - cax) ** 2 + (cby - cay) ** 2)

          assert_in_delta orig_dist, new_dist, @epsilon
        end
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # 7. Circular Layout: Nodes on Requested Radius
  # ──────────────────────────────────────────────────────

  describe "Circular Layout Invariants" do
    property "circular: all nodes lie on the requested radius" do
      check all(
              n <- StreamData.integer(2..30),
              radius <- positive_float_gen(),
              cx <- float_gen(),
              cy <- float_gen()
            ) do
        graph = Yog.Generator.Classic.cycle(n)
        pos = Yog.Layout.circular(graph, radius: radius, center: {cx, cy})

        for {_id, {x, y}} <- pos do
          dist = :math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
          assert_in_delta dist, radius, @epsilon
        end
      end
    end

    property "circular: single node placed at center" do
      check all(
              cx <- float_gen(),
              cy <- float_gen()
            ) do
        graph = Yog.new(:undirected) |> Yog.add_node(:solo)
        pos = Yog.Layout.circular(graph, center: {cx, cy})

        {x, y} = Map.fetch!(pos, :solo)
        assert_in_delta x, cx, @epsilon
        assert_in_delta y, cy, @epsilon
      end
    end

    property "circular: empty graph returns empty map" do
      check all(kind <- StreamData.member_of([:directed, :undirected])) do
        graph = Yog.new(kind)
        assert Yog.Layout.circular(graph) == %{}
      end
    end

    property "circular: node count matches graph size" do
      check all(graph <- graph_gen()) do
        pos = Yog.Layout.circular(graph)
        assert map_size(pos) == Yog.node_count(graph)
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # 8. Grid Layout: Validates Duplicates and Missing IDs
  # ──────────────────────────────────────────────────────

  describe "Grid Layout Invariants" do
    property "grid: duplicate node IDs raise ArgumentError" do
      check all(n <- StreamData.integer(3..8)) do
        nodes = Enum.to_list(1..n)
        graph = Yog.from_nodes(:undirected, nodes)

        # Create rows with a duplicate
        dup = hd(nodes)
        rows = [nodes, [dup]]

        assert_raise ArgumentError, fn ->
          Yog.Layout.grid(graph, rows: rows)
        end
      end
    end

    property "grid: missing graph nodes raise ArgumentError" do
      check all(n <- StreamData.integer(3..8)) do
        nodes = Enum.to_list(1..n)
        graph = Yog.from_nodes(:undirected, nodes)

        # Only include a subset of nodes
        partial = Enum.take(nodes, max(1, n - 1))
        rows = [partial]

        if length(partial) < n do
          assert_raise ArgumentError, fn ->
            Yog.Layout.grid(graph, rows: rows)
          end
        end
      end
    end

    property "grid: extra node IDs (not in graph) raise ArgumentError" do
      check all(n <- StreamData.integer(2..8)) do
        nodes = Enum.to_list(1..n)
        graph = Yog.from_nodes(:undirected, nodes)

        extra = n + 1
        rows = [nodes ++ [extra]]

        assert_raise ArgumentError, fn ->
          Yog.Layout.grid(graph, rows: rows)
        end
      end
    end

    property "grid: valid layout produces one coordinate per node" do
      check all(n <- StreamData.integer(2..8)) do
        nodes = Enum.to_list(1..n)
        graph = Yog.from_nodes(:undirected, nodes)

        cols = max(1, ceil(n / 2))
        rows = Enum.chunk_every(nodes, cols) |> pad_last_row(cols)

        pos = Yog.Layout.grid(graph, rows: rows)
        graph_nodes = MapSet.new(nodes)
        pos_nodes = Map.keys(pos) |> MapSet.new()

        assert MapSet.equal?(graph_nodes, pos_nodes)
      end
    end

    property "grid: placeholders don't produce coordinates" do
      check all(n <- StreamData.integer(2..6)) do
        nodes = Enum.to_list(1..n)
        graph = Yog.from_nodes(:undirected, nodes)

        # Add nils as padding
        rows = [nodes ++ [nil, :_]]
        pos = Yog.Layout.grid(graph, rows: rows)

        refute Map.has_key?(pos, nil)
        refute Map.has_key?(pos, :_)
        assert map_size(pos) == n
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # 9. Bounds Invariants
  # ──────────────────────────────────────────────────────

  describe "Bounds Invariants" do
    property "bounds: empty map returns nil" do
      assert Yog.Layout.bounds(%{}) == nil
    end

    property "bounds: min ≤ max always holds" do
      check all(pos <- position_map_gen()) do
        {min_x, max_x, min_y, max_y} = Yog.Layout.bounds(pos)
        assert min_x <= max_x
        assert min_y <= max_y
      end
    end

    property "bounds: all coordinates lie within bounds" do
      check all(pos <- position_map_gen()) do
        {min_x, max_x, min_y, max_y} = Yog.Layout.bounds(pos)

        for {_id, {x, y}} <- pos do
          assert x >= min_x - @epsilon
          assert x <= max_x + @epsilon
          assert y >= min_y - @epsilon
          assert y <= max_y + @epsilon
        end
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # 10. Pack Invariants
  # ──────────────────────────────────────────────────────

  describe "Pack Invariants" do
    property "pack horizontal: sub-layouts don't overlap" do
      check all(
              g1 <- nonempty_graph_gen(),
              g2 <- nonempty_graph_gen(),
              gap <- StreamData.float(min: 0.0, max: 10.0)
            ) do
        pos1 = Yog.Layout.circular(g1)
        pos2 = Yog.Layout.circular(g2)

        # Ensure no overlapping node IDs for pack
        keys1 = Map.keys(pos1) |> MapSet.new()
        keys2 = Map.keys(pos2) |> MapSet.new()

        if MapSet.disjoint?(keys1, keys2) do
          packed = Yog.Layout.pack([pos1, pos2], direction: :horizontal, gap: gap)
          packed_keys1 = Map.take(packed, MapSet.to_list(keys1))
          packed_keys2 = Map.take(packed, MapSet.to_list(keys2))

          {_, max_x1, _, _} = Yog.Layout.bounds(packed_keys1)
          {min_x2, _, _, _} = Yog.Layout.bounds(packed_keys2)

          assert min_x2 >= max_x1 + gap - @epsilon
        end
      end
    end

    property "pack vertical: sub-layouts don't overlap" do
      check all(
              g1 <- nonempty_graph_gen(),
              g2 <- nonempty_graph_gen(),
              gap <- StreamData.float(min: 0.0, max: 10.0)
            ) do
        pos1 = Yog.Layout.circular(g1)
        pos2 = Yog.Layout.circular(g2)

        keys1 = Map.keys(pos1) |> MapSet.new()
        keys2 = Map.keys(pos2) |> MapSet.new()

        if MapSet.disjoint?(keys1, keys2) do
          packed = Yog.Layout.pack([pos1, pos2], direction: :vertical, gap: gap)
          packed_keys1 = Map.take(packed, MapSet.to_list(keys1))
          packed_keys2 = Map.take(packed, MapSet.to_list(keys2))

          {_, _, _, max_y1} = Yog.Layout.bounds(packed_keys1)
          {_, _, min_y2, _} = Yog.Layout.bounds(packed_keys2)

          assert min_y2 >= max_y1 + gap - @epsilon
        end
      end
    end

    property "pack preserves internal pairwise distances (isometry)" do
      check all(
              g1 <- nonempty_graph_gen(2),
              g2 <- nonempty_graph_gen(2),
              gap <- StreamData.float(min: 0.0, max: 10.0)
            ) do
        pos1 = Yog.Layout.circular(g1)
        pos2 = Yog.Layout.circular(g2)

        keys1 = Map.keys(pos1) |> MapSet.new()
        keys2 = Map.keys(pos2) |> MapSet.new()

        if MapSet.disjoint?(keys1, keys2) do
          packed = Yog.Layout.pack([pos1, pos2], direction: :horizontal, gap: gap)

          # Check pairwise distances within each sub-layout are preserved
          for sub_pos <- [pos1, pos2] do
            pairs = Map.keys(sub_pos) |> pairs_of()

            for {a, b} <- pairs do
              {ax, ay} = sub_pos[a]
              {bx, by} = sub_pos[b]
              orig_dist = :math.sqrt((bx - ax) ** 2 + (by - ay) ** 2)

              {pax, pay} = packed[a]
              {pbx, pby} = packed[b]
              packed_dist = :math.sqrt((pbx - pax) ** 2 + (pby - pay) ** 2)

              assert_in_delta orig_dist, packed_dist, @epsilon
            end
          end
        end
      end
    end

    property "pack: duplicate node IDs across maps raise ArgumentError" do
      check all(graph <- nonempty_graph_gen()) do
        pos = Yog.Layout.circular(graph)

        assert_raise ArgumentError, fn ->
          Yog.Layout.pack([pos, pos])
        end
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # 11. merge_position_maps Invariants
  # ──────────────────────────────────────────────────────

  describe "merge_position_maps Invariants" do
    property "merge_position_maps: duplicate IDs raise ArgumentError" do
      check all(graph <- nonempty_graph_gen()) do
        pos = Yog.Layout.circular(graph)

        assert_raise ArgumentError, fn ->
          Yog.Layout.merge_position_maps([pos, pos])
        end
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # 12. Random Layout: Bounds Containment & Seed Determinism
  # ──────────────────────────────────────────────────────

  describe "Random Layout Invariants" do
    property "random: all coordinates within bounding box" do
      check all(
              graph <- nonempty_graph_gen(),
              width <- positive_float_gen(),
              height <- positive_float_gen(),
              cx <- float_gen(),
              cy <- float_gen()
            ) do
        pos =
          Yog.Layout.random(graph,
            width: width,
            height: height,
            center: {cx, cy},
            seed: 42
          )

        half_w = width / 2.0
        half_h = height / 2.0

        for {_id, {x, y}} <- pos do
          assert x >= cx - half_w - @epsilon
          assert x <= cx + half_w + @epsilon
          assert y >= cy - half_h - @epsilon
          assert y <= cy + half_h + @epsilon
        end
      end
    end

    property "random: same seed produces identical layouts" do
      check all(graph <- nonempty_graph_gen()) do
        pos1 = Yog.Layout.random(graph, seed: 12345)
        pos2 = Yog.Layout.random(graph, seed: 12345)
        assert_coords_close(pos1, pos2)
      end
    end
  end

  # ──────────────────────────────────────────────────────
  # Utility: all unordered pairs from a list
  # ──────────────────────────────────────────────────────

  defp pairs_of(list) do
    for {a, i} <- Enum.with_index(list),
        {b, j} <- Enum.with_index(list),
        i < j,
        do: {a, b}
  end

  defp pad_last_row(rows, cols) do
    case List.last(rows) do
      nil ->
        rows

      last ->
        padding = cols - length(last)

        if padding > 0 do
          List.replace_at(rows, -1, last ++ List.duplicate(nil, padding))
        else
          rows
        end
    end
  end
end
