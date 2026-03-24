defmodule Yog.Community.DendrogramTest do
  @moduledoc """
  Tests for Yog.Community.Dendrogram module.

  Dendrogram represents hierarchical community structure.
  """

  use ExUnit.Case

  alias Yog.Community.Dendrogram
  alias Yog.Community.Result

  doctest Dendrogram

  # ============================================================
  # Construction Tests
  # ============================================================

  test "new with levels" do
    levels = [
      Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1}),
      Result.new(%{1 => 0, 2 => 0, 3 => 0, 4 => 0})
    ]

    dendrogram = Dendrogram.new(levels)

    assert length(dendrogram.levels) == 2
    assert dendrogram.merge_order == []
  end

  test "new with levels and merge order" do
    levels = [
      Result.new(%{1 => 0, 2 => 0}),
      Result.new(%{1 => 0})
    ]

    merge_order = [{0, 1}]

    dendrogram = Dendrogram.new(levels, merge_order)

    assert length(dendrogram.levels) == 2
    assert dendrogram.merge_order == [{0, 1}]
  end

  # ============================================================
  # Access Tests
  # ============================================================

  test "get_level returns level at index" do
    level0 = Result.new(%{1 => 0, 2 => 0})
    level1 = Result.new(%{1 => 0})
    dendrogram = Dendrogram.new([level0, level1])

    assert Dendrogram.get_level(dendrogram, 0) == level0
    assert Dendrogram.get_level(dendrogram, 1) == level1
  end

  test "at_level returns first level with <= n communities" do
    # 1 community
    level0 = Result.new(%{1 => 0, 2 => 0})
    # 2 communities
    level1 = Result.new(%{1 => 0, 2 => 1})
    dendrogram = Dendrogram.new([level1, level0])

    # at_level finds first level with <= n communities
    assert Dendrogram.at_level(dendrogram, 1) == level0
  end

  test "num_levels returns number of levels" do
    levels = [
      Result.new(%{1 => 0, 2 => 0}),
      Result.new(%{1 => 0})
    ]

    dendrogram = Dendrogram.new(levels)

    assert Dendrogram.num_levels(dendrogram) == 2
  end

  test "finest returns first level" do
    level0 = Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1})
    level1 = Result.new(%{1 => 0, 2 => 0, 3 => 0, 4 => 0})
    dendrogram = Dendrogram.new([level0, level1])

    assert Dendrogram.finest(dendrogram) == level0
  end

  test "coarsest returns last level" do
    level0 = Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1})
    level1 = Result.new(%{1 => 0, 2 => 0, 3 => 0, 4 => 0})
    dendrogram = Dendrogram.new([level0, level1])

    assert Dendrogram.coarsest(dendrogram) == level1
  end

  test "finest returns empty result for empty dendrogram" do
    dendrogram = Dendrogram.new([])

    result = Dendrogram.finest(dendrogram)
    assert result.num_communities == 0
  end

  # ============================================================
  # Conversion Tests
  # ============================================================

  test "from_map and to_map roundtrip" do
    levels = [
      Result.new(%{1 => 0, 2 => 0}),
      Result.new(%{1 => 0})
    ]

    dendrogram = Dendrogram.new(levels, [{0, 1}])

    map = Dendrogram.to_map(dendrogram)
    restored = Dendrogram.from_map(map)

    assert Dendrogram.num_levels(restored) == 2
  end
end
