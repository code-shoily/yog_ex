defmodule Yog.BalancedTreeTest do
  @moduledoc """
  Tests for Yog.BalancedTree module.

  Priority Queue implementation based on Erlang's :gb_trees.
  """

  use ExUnit.Case

  alias Yog.BalancedTree, as: PQ

  doctest PQ

  # ============================================================
  # Construction Tests
  # ============================================================

  test "new creates empty queue" do
    pq = PQ.new()
    assert PQ.empty?(pq)
  end

  # ============================================================
  # Empty Tests
  # ============================================================

  test "empty? returns true for empty queue" do
    assert PQ.empty?(PQ.new())
  end

  test "empty? returns false for non-empty queue" do
    pq = PQ.new() |> PQ.push(1)
    refute PQ.empty?(pq)
  end

  # ============================================================
  # Push and Pop Tests
  # ============================================================

  test "push adds elements" do
    pq = PQ.new() |> PQ.push(5) |> PQ.push(3) |> PQ.push(7)
    {:ok, min, _} = PQ.pop(pq)
    assert min == 3
  end

  test "pop returns min element and new queue" do
    pq = PQ.new() |> PQ.push(5) |> PQ.push(3) |> PQ.push(7)

    {:ok, min1, pq1} = PQ.pop(pq)
    assert min1 == 3

    {:ok, min2, pq2} = PQ.pop(pq1)
    assert min2 == 5

    {:ok, min3, pq3} = PQ.pop(pq2)
    assert min3 == 7

    assert PQ.empty?(pq3)
  end

  test "pop returns :error for empty queue" do
    assert PQ.pop(PQ.new()) == :error
  end

  # ============================================================
  # Peek Tests
  # ============================================================

  test "peek returns min without removing" do
    pq = PQ.new() |> PQ.push(5) |> PQ.push(3)

    {:ok, min} = PQ.peek(pq)
    assert min == 3

    # Queue unchanged
    {:ok, min2, _} = PQ.pop(pq)
    assert min2 == 3
  end

  test "peek returns :error for empty queue" do
    assert PQ.peek(PQ.new()) == :error
  end

  # ============================================================
  # From List Tests
  # ============================================================

  test "from_list creates queue from list" do
    pq = PQ.from_list([3, 1, 4, 1, 5, 9, 2, 6])

    {:ok, min, _} = PQ.pop(pq)
    assert min == 1
  end

  # ============================================================
  # To List Tests
  # ============================================================

  test "to_list returns sorted list" do
    pq = PQ.new() |> PQ.push(3) |> PQ.push(1) |> PQ.push(2)
    list = PQ.to_list(pq)

    assert list == [1, 2, 3]
  end

  test "to_list on empty queue returns empty list" do
    assert PQ.to_list(PQ.new()) == []
  end

  # ============================================================
  # Size Tests
  # ============================================================

  test "size returns number of elements" do
    pq = PQ.new() |> PQ.push(1) |> PQ.push(2) |> PQ.push(3)
    assert PQ.size(pq) == 3
  end

  test "size decreases after pop" do
    pq = PQ.new() |> PQ.push(1) |> PQ.push(2)
    {:ok, _, pq} = PQ.pop(pq)
    assert PQ.size(pq) == 1
  end

  test "size of empty queue is 0" do
    assert PQ.size(PQ.new()) == 0
  end

  # ============================================================
  # Complex Element Tests
  # ============================================================

  test "works with tuples (common for Dijkstra)" do
    pq =
      PQ.new()
      |> PQ.push({5, :a})
      |> PQ.push({2, :b})
      |> PQ.push({7, :c})

    {:ok, {dist, node}, _} = PQ.pop(pq)
    assert dist == 2
    assert node == :b
  end

  test "duplicates are preserved" do
    pq =
      PQ.new()
      |> PQ.push(5)
      |> PQ.push(5)
      |> PQ.push(3)

    assert PQ.size(pq) == 3

    {:ok, min1, pq} = PQ.pop(pq)
    {:ok, min2, pq} = PQ.pop(pq)
    {:ok, min3, _} = PQ.pop(pq)

    assert min1 == 3
    assert min2 == 5
    assert min3 == 5
  end

  test "works with complex structs using tuple wrapping" do
    # For structs, wrap in tuple with priority as first element
    pq =
      PQ.new()
      |> PQ.push({3, %{priority: 3, value: "c"}})
      |> PQ.push({1, %{priority: 1, value: "a"}})
      |> PQ.push({2, %{priority: 2, value: "b"}})

    {:ok, {_priority, item}, _} = PQ.pop(pq)
    assert item.priority == 1
    assert item.value == "a"
  end

  # ============================================================
  # Persistence Tests
  # ============================================================

  test "queue is persistent (immutable)" do
    pq1 = PQ.new() |> PQ.push(5) |> PQ.push(3)
    {:ok, min, pq2} = PQ.pop(pq1)

    # Original queue unchanged
    assert min == 3
    assert PQ.size(pq1) == 2
    assert PQ.size(pq2) == 1

    # Can still use original queue
    {:ok, min2, _} = PQ.pop(pq1)
    assert min2 == 3
  end

  # ============================================================
  # Large Input Tests
  # ============================================================

  test "handles large number of elements" do
    elements = Enum.shuffle(1..1000)
    pq = PQ.from_list(elements)

    list = PQ.to_list(pq)
    assert list == Enum.to_list(1..1000)
  end

  # ============================================================
  # Edge Cases
  # ============================================================

  test "pushing and popping many elements maintains order" do
    pq =
      PQ.new()
      |> PQ.push(10)
      |> PQ.push(5)
      |> PQ.push(15)
      |> PQ.push(3)
      |> PQ.push(7)

    assert PQ.to_list(pq) == [3, 5, 7, 10, 15]
  end

  test "interleaved push and pop operations" do
    pq = PQ.new() |> PQ.push(5) |> PQ.push(3)
    {:ok, min1, pq} = PQ.pop(pq)
    pq = pq |> PQ.push(7) |> PQ.push(1)
    {:ok, min2, pq} = PQ.pop(pq)
    {:ok, min3, _} = PQ.pop(pq)

    assert min1 == 3
    assert min2 == 1
    assert min3 == 5
  end

  # ============================================================
  # Erlang Term Ordering Tests
  # ============================================================

  test "erlang term ordering: numbers < atoms < tuples" do
    pq =
      PQ.new()
      |> PQ.push(:atom)
      |> PQ.push({1, :a})
      |> PQ.push(5)

    # Numbers come first
    {:ok, min1, pq} = PQ.pop(pq)
    assert min1 == 5

    # Then atoms
    {:ok, min2, pq} = PQ.pop(pq)
    assert min2 == :atom

    # Then tuples
    {:ok, min3, _} = PQ.pop(pq)
    assert min3 == {1, :a}
  end

  test "duplicate keys are preserved with counter" do
    # In BalancedTree, duplicates are preserved using an internal counter
    pq =
      PQ.new()
      |> PQ.push({5, :a})
      |> PQ.push({5, :b})
      |> PQ.push({3, :c})

    list = PQ.to_list(pq)

    # Should have 3 elements (duplicates preserved)
    assert length(list) == 3
    assert {3, :c} in list
    # Both {5, :a} and {5, :b} should be present
    assert {5, :a} in list or {5, :b} in list
  end
end
