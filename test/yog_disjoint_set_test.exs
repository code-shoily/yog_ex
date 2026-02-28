defmodule YogDisjointSetTest do
  use ExUnit.Case

  alias Yog.DisjointSet

  # ============= Creation Tests =============

  test "new_disjoint_set_test" do
    d = DisjointSet.new()

    # New should be empty
    assert DisjointSet.size(d) == 0
  end

  # ============= Add Tests =============

  test "add_single_element_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)

    # Element should be its own parent
    {_, root} = DisjointSet.find(d, 1)
    assert root == 1
  end

  test "add_multiple_elements_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)

    # Each should be in its own set
    {d1, root1} = DisjointSet.find(d, 1)
    {d2, root2} = DisjointSet.find(d1, 2)
    {_d3, root3} = DisjointSet.find(d2, 3)

    assert root1 == 1
    assert root2 == 2
    assert root3 == 3
  end

  test "add_duplicate_element_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(1)
      |> DisjointSet.add(1)

    # Should still just be one element
    {_, root} = DisjointSet.find(d, 1)
    assert root == 1
  end

  # ============= Find Tests =============

  test "find_self_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)

    {_, root} = DisjointSet.find(d, 1)
    assert root == 1
  end

  test "find_nonexistent_auto_adds_test" do
    d = DisjointSet.new()

    # Finding non-existent element should auto-add it
    {d1, root} = DisjointSet.find(d, 42)
    assert root == 42

    # Should now exist in the disjoint set
    {_, root2} = DisjointSet.find(d1, 42)
    assert root2 == 42
  end

  test "find_after_union_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.union(1, 2)

    {d1, root1} = DisjointSet.find(d, 1)
    {_d2, root2} = DisjointSet.find(d1, 2)

    # Both should have same root
    assert root1 == root2
  end

  # ============= Union Tests =============

  test "union_two_elements_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.union(1, 2)

    {d1, root1} = DisjointSet.find(d, 1)
    {_d2, root2} = DisjointSet.find(d1, 2)

    assert root1 == root2
  end

  test "union_multiple_pairs_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)
      |> DisjointSet.add(4)
      |> DisjointSet.union(1, 2)
      |> DisjointSet.union(3, 4)

    # 1 and 2 should be in same set
    {d1, root1} = DisjointSet.find(d, 1)
    {d2, root2} = DisjointSet.find(d1, 2)

    assert root1 == root2

    # 3 and 4 should be in same set
    {d3, root3} = DisjointSet.find(d2, 3)
    {_d4, root4} = DisjointSet.find(d3, 4)

    assert root3 == root4

    # But 1 and 3 should be in different sets
    assert root1 != root3
  end

  test "union_chains_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)
      |> DisjointSet.union(1, 2)
      |> DisjointSet.union(2, 3)

    # All three should be in same set
    {d1, root1} = DisjointSet.find(d, 1)
    {d2, root2} = DisjointSet.find(d1, 2)
    {_d3, root3} = DisjointSet.find(d2, 3)

    assert root1 == root2
    assert root2 == root3
  end

  test "union_already_connected_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.union(1, 2)
      |> DisjointSet.union(1, 2)
      |> DisjointSet.union(2, 1)

    # Should still be connected
    {d1, root1} = DisjointSet.find(d, 1)
    {_d2, root2} = DisjointSet.find(d1, 2)

    assert root1 == root2
  end

  test "union_without_add_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.union(1, 2)

    # Should auto-add both elements
    {d1, root1} = DisjointSet.find(d, 1)
    {_d2, root2} = DisjointSet.find(d1, 2)

    assert root1 == root2
  end

  # ============= Path Compression Tests =============

  test "path_compression_flattens_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)
      |> DisjointSet.add(4)
      # Create a chain: 1->2->3->4
      |> DisjointSet.union(1, 2)
      |> DisjointSet.union(2, 3)
      |> DisjointSet.union(3, 4)

    # Find 1 should trigger path compression
    {d1, root1} = DisjointSet.find(d, 1)

    # All elements should now point directly to root
    {d2, root2} = DisjointSet.find(d1, 2)
    {d3, root3} = DisjointSet.find(d2, 3)
    {_d4, root4} = DisjointSet.find(d3, 4)

    assert root1 == root2
    assert root2 == root3
    assert root3 == root4
  end

  # ============= Union by Rank Tests =============

  test "union_by_rank_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)
      |> DisjointSet.add(4)
      |> DisjointSet.add(5)
      # Create two trees of different sizes
      |> DisjointSet.union(1, 2)
      |> DisjointSet.union(1, 3)
      # Tree 1 has rank 1, contains {1,2,3}
      |> DisjointSet.union(4, 5)
      # Tree 2 has rank 1, contains {4,5}
      |> DisjointSet.union(1, 4)

    # All should be in same set
    {d1, root1} = DisjointSet.find(d, 1)
    {d2, root2} = DisjointSet.find(d1, 2)
    {d3, root3} = DisjointSet.find(d2, 3)
    {d4, root4} = DisjointSet.find(d3, 4)
    {_d5, root5} = DisjointSet.find(d4, 5)

    assert root1 == root2
    assert root2 == root3
    assert root3 == root4
    assert root4 == root5
  end

  # ============= Connected Components Tests =============

  test "three_components_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)
      |> DisjointSet.add(4)
      |> DisjointSet.add(5)
      |> DisjointSet.add(6)
      # Component 1: {1, 2}
      |> DisjointSet.union(1, 2)
      # Component 2: {3, 4}
      |> DisjointSet.union(3, 4)
      # Component 3: {5, 6}
      |> DisjointSet.union(5, 6)

    {d1, root1} = DisjointSet.find(d, 1)
    {d2, root2} = DisjointSet.find(d1, 2)
    {d3, root3} = DisjointSet.find(d2, 3)
    {d4, root4} = DisjointSet.find(d3, 4)
    {d5, root5} = DisjointSet.find(d4, 5)
    {_d6, root6} = DisjointSet.find(d5, 6)

    # Component 1
    assert root1 == root2

    # Component 2
    assert root3 == root4

    # Component 3
    assert root5 == root6

    # Different components
    assert root1 != root3
    assert root1 != root5
    assert root3 != root5
  end

  test "merge_components_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)
      |> DisjointSet.add(4)
      # Create two components
      |> DisjointSet.union(1, 2)
      |> DisjointSet.union(3, 4)

    # Verify they're separate
    {d1, root1} = DisjointSet.find(d, 1)
    {d2, root3} = DisjointSet.find(d1, 3)

    assert root1 != root3

    # Now merge the components
    d3 = DisjointSet.union(d2, 2, 3)

    # Now all should be in same component
    {d4, new_root1} = DisjointSet.find(d3, 1)
    {_d5, new_root3} = DisjointSet.find(d4, 3)

    assert new_root1 == new_root3
  end

  # ============= Stress Tests =============

  test "large_disjoint_set_test" do
    # Create a disjoint_set with 100 elements
    numbers = Enum.to_list(1..100)

    d =
      Enum.reduce(numbers, DisjointSet.new(), fn n, acc ->
        DisjointSet.add(acc, n)
      end)

    # Union them into 10 components of 10 elements each
    d2 =
      Enum.reduce(0..9, d, fn group, acc ->
        Enum.reduce(1..9, acc, fn i, acc2 ->
          DisjointSet.union(acc2, group * 10 + 1, group * 10 + i + 1)
        end)
      end)

    # Verify first component
    {d3, root1} = DisjointSet.find(d2, 1)
    {_d4, root10} = DisjointSet.find(d3, 10)

    assert root1 == root10

    # Verify different components are separate
    {d5, root_comp1} = DisjointSet.find(d2, 5)
    {_d6, root_comp2} = DisjointSet.find(d5, 15)

    assert root_comp1 != root_comp2
  end

  test "union_all_test" do
    # Create disjoint_set and union all elements into one set
    numbers = Enum.to_list(1..50)

    d =
      Enum.reduce(numbers, DisjointSet.new(), fn n, acc ->
        DisjointSet.add(acc, n)
      end)

    # Union all to element 1
    d2 =
      Enum.reduce(2..50, d, fn n, acc ->
        DisjointSet.union(acc, 1, n)
      end)

    # All should have same root
    {d3, root1} = DisjointSet.find(d2, 1)
    {d4, root25} = DisjointSet.find(d3, 25)
    {_d5, root50} = DisjointSet.find(d4, 50)

    assert root1 == root25
    assert root25 == root50
  end

  # ============= String/Generic Type Tests =============

  test "disjoint_set_with_strings_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add("alice")
      |> DisjointSet.add("bob")
      |> DisjointSet.add("charlie")
      |> DisjointSet.union("alice", "bob")

    {d1, root_alice} = DisjointSet.find(d, "alice")
    {d2, root_bob} = DisjointSet.find(d1, "bob")
    {_d3, root_charlie} = DisjointSet.find(d2, "charlie")

    assert root_alice == root_bob
    assert root_alice != root_charlie
  end

  # ============= Convenience Function Tests =============

  test "from_pairs_empty_test" do
    d = DisjointSet.from_pairs([])
    assert DisjointSet.size(d) == 0
  end

  test "from_pairs_single_pair_test" do
    d = DisjointSet.from_pairs([{1, 2}])

    {d1, root1} = DisjointSet.find(d, 1)
    {_d2, root2} = DisjointSet.find(d1, 2)

    assert root1 == root2
  end

  test "from_pairs_multiple_pairs_test" do
    d = DisjointSet.from_pairs([{1, 2}, {3, 4}, {2, 3}])

    # All should be in one set
    {d1, root1} = DisjointSet.find(d, 1)
    {d2, root2} = DisjointSet.find(d1, 2)
    {d3, root3} = DisjointSet.find(d2, 3)
    {_d4, root4} = DisjointSet.find(d3, 4)

    assert root1 == root2
    assert root2 == root3
    assert root3 == root4
  end

  test "from_pairs_separate_components_test" do
    d = DisjointSet.from_pairs([{1, 2}, {3, 4}, {5, 6}])

    {d1, root1} = DisjointSet.find(d, 1)
    {d2, root2} = DisjointSet.find(d1, 2)
    {d3, root3} = DisjointSet.find(d2, 3)
    {_d4, root5} = DisjointSet.find(d3, 5)

    # 1 and 2 connected
    assert root1 == root2

    # 1 and 3 not connected
    assert root1 != root3

    # 1 and 5 not connected
    assert root1 != root5
  end

  test "connected_same_set_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.union(1, 2)

    {_d1, result} = DisjointSet.connected?(d, 1, 2)
    assert result == true
  end

  test "connected_different_sets_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)
      |> DisjointSet.union(1, 2)

    {_d1, result} = DisjointSet.connected?(d, 1, 3)
    assert result == false
  end

  test "connected_auto_adds_test" do
    d = DisjointSet.new()

    # Should auto-add both elements
    {d1, result} = DisjointSet.connected?(d, 1, 2)
    assert result == false

    # Both should now exist
    assert DisjointSet.size(d1) == 2
  end

  test "size_empty_test" do
    d = DisjointSet.new()
    assert DisjointSet.size(d) == 0
  end

  test "size_after_adds_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)

    assert DisjointSet.size(d) == 3
  end

  test "size_after_union_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.union(1, 2)

    # Union doesn't change size, just connectivity
    assert DisjointSet.size(d) == 2
  end

  test "count_sets_empty_test" do
    d = DisjointSet.new()
    assert DisjointSet.count_sets(d) == 0
  end

  test "count_sets_all_separate_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)

    assert DisjointSet.count_sets(d) == 3
  end

  test "count_sets_after_unions_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)
      |> DisjointSet.add(4)
      |> DisjointSet.union(1, 2)
      |> DisjointSet.union(3, 4)

    # Should have 2 sets: {1,2} and {3,4}
    assert DisjointSet.count_sets(d) == 2
  end

  test "count_sets_all_connected_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)
      |> DisjointSet.union(1, 2)
      |> DisjointSet.union(2, 3)

    assert DisjointSet.count_sets(d) == 1
  end

  test "to_lists_empty_test" do
    d = DisjointSet.new()
    assert DisjointSet.to_lists(d) == []
  end

  test "to_lists_single_elements_test" do
    d =
      DisjointSet.new()
      |> DisjointSet.add(1)
      |> DisjointSet.add(2)
      |> DisjointSet.add(3)

    result = DisjointSet.to_lists(d)

    # Should have 3 singleton sets
    assert length(result) == 3

    # Each set should have 1 element
    assert Enum.all?(result, fn set -> length(set) == 1 end)
  end

  test "to_lists_multiple_sets_test" do
    d = DisjointSet.from_pairs([{1, 2}, {3, 4}, {5, 6}])

    result = DisjointSet.to_lists(d)

    # Should have 3 sets
    assert length(result) == 3

    # Each set should have 2 elements
    assert Enum.all?(result, fn set -> length(set) == 2 end)
  end

  test "to_lists_one_large_set_test" do
    d = DisjointSet.from_pairs([{1, 2}, {2, 3}, {3, 4}])

    result = DisjointSet.to_lists(d)

    # Should have 1 set
    assert length(result) == 1

    # That set should have 4 elements
    assert length(hd(result)) == 4
  end

  test "to_lists_preserves_elements_test" do
    d = DisjointSet.from_pairs([{1, 2}, {3, 4}])

    result = DisjointSet.to_lists(d)

    # Flatten to get all elements
    all_elements =
      result
      |> List.flatten()
      |> Enum.sort()

    assert all_elements == [1, 2, 3, 4]
  end
end
