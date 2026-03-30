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

  test "overlap returns overlap between communities" do
    memberships = %{
      1 => [0, 1],
      2 => [0],
      3 => [1]
    }

    result = Overlapping.new(memberships)

    # Node 1 is in both community 0 and 1, so overlap is 1
    assert Overlapping.overlap(result, 0, 1) == 1
    # Nodes 1 and 2
    assert Overlapping.overlap(result, 0, 0) == 2
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

  test "from_map and to_map roundtrip" do
    memberships = %{1 => [0], 2 => [0]}
    result = Overlapping.new(memberships)

    map = Overlapping.to_map(result)
    restored = Overlapping.from_map(map)

    assert restored.memberships == result.memberships
    assert restored.num_communities == result.num_communities
  end
end
