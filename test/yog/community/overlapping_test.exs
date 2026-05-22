defmodule Yog.Community.OverlappingTest do
  @moduledoc """
  Tests for Yog.Community.Overlapping module.

  Overlapping communities allow nodes to belong to multiple communities.
  """

  use ExUnit.Case

  alias Yog.Community.Overlapping

  doctest Overlapping

  # ============================================================
  # Construction Tests
  # ============================================================

  test "new with memberships" do
    memberships = %{
      1 => [0, 1],
      2 => [0],
      3 => [1]
    }

    result = Overlapping.new(memberships)

    assert result.memberships == memberships
    assert result.num_communities == 2
    assert result.metadata == %{}
  end

  test "new with memberships and metadata" do
    memberships = %{1 => [0], 2 => [0]}
    metadata = %{algorithm: :clique_percolation}

    result = Overlapping.new(memberships, metadata)

    assert result.metadata == metadata
  end

  test "new with empty memberships" do
    result = Overlapping.new(%{})

    assert result.memberships == %{}
    assert result.num_communities == 0
  end

  test "new with non-integer community IDs" do
    memberships = %{
      1 => [:alpha, :beta],
      2 => [:alpha],
      3 => [:beta]
    }

    result = Overlapping.new(memberships)

    assert result.num_communities == 2
    assert Overlapping.nodes_in_community(result, :alpha) == MapSet.new([1, 2])
    assert Overlapping.nodes_in_community(result, :beta) == MapSet.new([1, 3])
  end

  test "new with pre-computed num_communities opt" do
    memberships = %{1 => [0, 1], 2 => [0]}

    result = Overlapping.new(memberships, %{}, num_communities: 2)

    assert result.num_communities == 2
  end

  test "new with pre-computed community_index opt" do
    memberships = %{1 => [0, 1], 2 => [0]}
    index = %{0 => MapSet.new([1, 2]), 1 => MapSet.new([1])}

    result = Overlapping.new(memberships, %{}, community_index: index)

    assert result.community_index == index
  end

  # ============================================================
  # Query Tests
  # ============================================================

  test "communities_for_node returns communities for node" do
    memberships = %{
      1 => [0, 1],
      2 => [0]
    }

    result = Overlapping.new(memberships)

    assert Overlapping.communities_for_node(result, 1) == [0, 1]
    assert Overlapping.communities_for_node(result, 2) == [0]
  end

  test "communities_for_node returns empty list for unknown node" do
    result = Overlapping.new(%{1 => [0]})

    assert Overlapping.communities_for_node(result, :unknown) == []
  end

  test "nodes_in_community returns nodes belonging to community" do
    memberships = %{
      1 => [0, 1],
      2 => [0],
      3 => [1]
    }

    result = Overlapping.new(memberships)

    assert Overlapping.nodes_in_community(result, 0) == MapSet.new([1, 2])
    assert Overlapping.nodes_in_community(result, 1) == MapSet.new([1, 3])
  end

  test "nodes_in_community returns empty set for unknown community" do
    result = Overlapping.new(%{1 => [0]})

    assert Overlapping.nodes_in_community(result, 99) == MapSet.new()
  end

  test "nodes_in_community fallback for legacy structs without index" do
    memberships = %{
      1 => [0, 1],
      2 => [0],
      3 => [1]
    }

    # Simulate a legacy struct missing the community_index field
    legacy = %Overlapping{
      memberships: memberships,
      num_communities: 2,
      community_index: nil,
      metadata: %{}
    }

    assert Overlapping.nodes_in_community(legacy, 0) == MapSet.new([1, 2])
    assert Overlapping.nodes_in_community(legacy, 1) == MapSet.new([1, 3])
  end

  test "overlap returns overlap between communities" do
    memberships = %{
      1 => [0, 1],
      2 => [0],
      3 => [1]
    }

    result = Overlapping.new(memberships)

    # Node 1 is in both community 0 and 1, so overlap is 1
    assert Overlapping.overlap(result, 0, 1) == 1
    # Community 0 intersect itself = {1, 2}
    assert Overlapping.overlap(result, 0, 0) == 2
    # Community 1 intersect itself = {1, 3}
    assert Overlapping.overlap(result, 1, 1) == 2
  end

  test "overlap returns zero for disjoint communities" do
    memberships = %{
      1 => [0],
      2 => [1]
    }

    result = Overlapping.new(memberships)

    assert Overlapping.overlap(result, 0, 1) == 0
  end

  test "overlap returns zero for unknown communities" do
    result = Overlapping.new(%{1 => [0]})

    assert Overlapping.overlap(result, 0, 99) == 0
  end

  # ============================================================
  # Conversion Tests
  # ============================================================

  test "to_result converts to standard result" do
    memberships = %{
      1 => [0, 1],
      2 => [1]
    }

    overlapping = Overlapping.new(memberships)

    result = Overlapping.to_result(overlapping)

    # Both nodes assigned to different communities → 2 communities
    assert result.num_communities == 2
    assert is_map(result.assignments)
    assert result.assignments[1] == 0
    assert result.assignments[2] == 1
  end

  test "to_result excludes nodes with no memberships" do
    memberships = %{
      1 => [0],
      2 => [],
      3 => [1]
    }

    overlapping = Overlapping.new(memberships)
    result = Overlapping.to_result(overlapping)

    assert result.assignments[1] == 0
    assert result.assignments[3] == 1
    refute Map.has_key?(result.assignments, 2)
    assert result.num_communities == 2
  end

  test "to_result with all empty memberships returns zero communities" do
    memberships = %{1 => [], 2 => []}

    overlapping = Overlapping.new(memberships)
    result = Overlapping.to_result(overlapping)

    assert result.assignments == %{}
    assert result.num_communities == 0
  end

  test "to_result assigns multiple nodes to same community" do
    memberships = %{
      1 => [0, 1],
      2 => [0, 1],
      3 => [0]
    }

    overlapping = Overlapping.new(memberships)
    result = Overlapping.to_result(overlapping)

    assert result.assignments[1] == 0
    assert result.assignments[2] == 0
    assert result.assignments[3] == 0
    assert result.num_communities == 1
  end

  test "from_map and to_map roundtrip" do
    memberships = %{1 => [0], 2 => [0]}
    result = Overlapping.new(memberships)

    map = Overlapping.to_map(result)
    restored = Overlapping.from_map(map)

    assert restored.memberships == result.memberships
    assert restored.num_communities == result.num_communities
    assert restored.community_index == result.community_index
  end

  test "from_map reconstructs community index" do
    map = %{
      memberships: %{1 => [0, 1], 2 => [0]},
      num_communities: 2
    }

    restored = Overlapping.from_map(map)

    assert restored.community_index == %{
             0 => MapSet.new([1, 2]),
             1 => MapSet.new([1])
           }
  end
end
