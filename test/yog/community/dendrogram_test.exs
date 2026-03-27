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
  # Rigorous Hierarchical Benchmarks
  # ============================================================

  test "hierarchical merge: 4 nodes merging step by step" do
    # Level 0 (Singlets): {1}, {2}, {3}, {4} -> 4 communities
    l0 = Result.new(%{1 => 0, 2 => 1, 3 => 2, 4 => 3})

    # Level 1 (Merge 1-2): {1,2}, {3}, {4} -> 3 communities
    l1 = Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 2})

    # Level 2 (Merge 3-4): {1,2}, {3,4} -> 2 communities
    l2 = Result.new(%{1 => 0, 2 => 0, 3 => 1, 4 => 1})

    # Level 3 (Final Merge): {1,2,3,4} -> 1 community
    l3 = Result.new(%{1 => 0, 2 => 0, 3 => 0, 4 => 0})

    dend = Dendrogram.new([l0, l1, l2, l3])

    # Check num communities at each level
    assert Dendrogram.get_level(dend, 0).num_communities == 4
    assert Dendrogram.get_level(dend, 1).num_communities == 3
    assert Dendrogram.get_level(dend, 2).num_communities == 2
    assert Dendrogram.get_level(dend, 3).num_communities == 1

    # at_level(n) should return the FIRST level with num_communities <= n
    assert Dendrogram.at_level(dend, 4) == l0
    assert Dendrogram.at_level(dend, 2) == l2
    assert Dendrogram.at_level(dend, 1) == l3
  end

  test "merge jump: level skip from 6 to 2 communities" do
    # Level 0: 6 nodes in 6 communities
    l0 = Result.new(for id <- 1..6, do: {id, id - 1}, into: %{})
    # Level 1: Everyone merged into 2 communities
    l1 = Result.new(%{1 => 0, 2 => 0, 3 => 0, 4 => 1, 5 => 1, 6 => 1})

    dend = Dendrogram.new([l0, l1])

    # If we want <= 4 communities, it should skip l0 (6) and give l1 (2)
    result = Dendrogram.at_level(dend, 4)
    assert result == l1
    assert result.num_communities == 2
  end

  test "at_level with unreachable target" do
    # Only 1 community of 10 nodes exists in coarsest level
    l1 = Result.new(for id <- 1..10, do: {id, 0}, into: %{})
    dend = Dendrogram.new([l1])

    # If target is 0 communities, it's unreachable
    assert Dendrogram.at_level(dend, 0) == nil
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
    assert restored.merge_order == [{0, 1}]
  end
end
