defmodule Yog.Community.ResultTest do
  @moduledoc """
  Tests for Yog.Community.Result module.

  Result struct for community detection output.
  """

  use ExUnit.Case

  alias Yog.Community.Result

  doctest Result

  # ============================================================
  # Construction Tests
  # ============================================================

  test "new with assignments" do
    assignments = %{1 => 0, 2 => 0, 3 => 1, 4 => 1}
    result = Result.new(assignments)

    assert result.assignments == assignments
    assert result.num_communities == 2
    assert result.metadata == %{}
  end

  test "new with assignments and metadata" do
    assignments = %{1 => 0, 2 => 0}
    metadata = %{algorithm: :louvain, modularity: 0.5}
    result = Result.new(assignments, metadata)

    assert result.assignments == assignments
    assert result.metadata == metadata
  end

  test "new with empty assignments" do
    result = Result.new(%{})

    assert result.assignments == %{}
    assert result.num_communities == 0
  end

  test "new with single community" do
    result = Result.new(%{1 => 0, 2 => 0, 3 => 0})

    assert result.num_communities == 1
  end

  # ============================================================
  # Conversion Tests
  # ============================================================

  test "from_map converts legacy map format" do
    map = %{assignments: %{1 => 0, 2 => 1}, num_communities: 2}
    result = Result.from_map(map)

    assert result.assignments == %{1 => 0, 2 => 1}
    assert result.num_communities == 2
  end

  test "from_map with metadata" do
    map = %{assignments: %{1 => 0}, num_communities: 1, metadata: %{seed: 42}}
    result = Result.from_map(map)

    assert result.metadata == %{seed: 42}
  end

  test "to_map converts to legacy format" do
    result = Result.new(%{1 => 0, 2 => 1})
    map = Result.to_map(result)

    assert map.assignments == %{1 => 0, 2 => 1}
    assert map.num_communities == 2
  end

  # ============================================================
  # Roundtrip Test
  # ============================================================

  test "from_map and to_map roundtrip" do
    original = Result.new(%{1 => 0, 2 => 0, 3 => 1}, %{test: true})
    map = Result.to_map(original)
    restored = Result.from_map(map)

    assert restored.assignments == original.assignments
    assert restored.num_communities == original.num_communities
  end

  # ============================================================
  # Access Pattern Tests
  # ============================================================

  test "struct access patterns" do
    result = Result.new(%{1 => 0, 2 => 0, 3 => 1})

    # Direct field access
    assert result.assignments[1] == 0
    assert result.assignments[3] == 1
    assert result.num_communities == 2

    # Pattern matching
    %Result{assignments: asgn, num_communities: num} = result
    assert asgn == result.assignments
    assert num == 2
  end
end
