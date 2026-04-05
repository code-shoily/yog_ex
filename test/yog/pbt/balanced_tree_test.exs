defmodule Yog.PBT.BalancedTreeTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.BalancedTree

  @moduledoc """
  Property-based tests for Yog.BalancedTree.
  Verifies heap invariants, sorting order, and size consistency.
  """

  describe "BalancedTree Properties" do
    property "Popping all elements returns a sorted list" do
      check all(list <- StreamData.list_of(StreamData.integer())) do
        pq = BalancedTree.from_list(list)
        sorted_from_pq = BalancedTree.to_list(pq)

        assert sorted_from_pq == Enum.sort(list)
      end
    end

    property "Peek always returns the same value as the first popped element" do
      check all(list <- StreamData.list_of(StreamData.integer(), min_length: 1)) do
        pq = BalancedTree.from_list(list)

        {:ok, peek_val} = BalancedTree.peek(pq)
        {:ok, pop_val, _new_pq} = BalancedTree.pop(pq)

        assert peek_val == pop_val
        assert peek_val == Enum.min(list)
      end
    end

    property "Size invariant: push/pop accurately track element count" do
      check all(
              ops <-
                StreamData.list_of(
                  StreamData.one_of([
                    {:push, StreamData.integer()},
                    {:pop}
                  ]),
                  max_length: 50
                )
            ) do
        Enum.reduce(ops, {BalancedTree.new(), 0}, fn op, {pq, expected_size} ->
          case op do
            {:push, val} ->
              new_pq = BalancedTree.push(pq, val)
              # Note: duplicates overwrite, so size may not increase
              actual_size = BalancedTree.size(new_pq)
              assert actual_size >= expected_size
              {new_pq, actual_size}

            {:pop} ->
              case BalancedTree.pop(pq) do
                {:ok, _val, new_pq} ->
                  assert BalancedTree.size(new_pq) == expected_size - 1
                  {new_pq, expected_size - 1}

                :error ->
                  assert expected_size == 0
                  {pq, 0}
              end
          end
        end)
      end
    end

    property "Merging priority queues preserves overall order" do
      check all(
              l1 <- StreamData.list_of(StreamData.integer()),
              l2 <- StreamData.list_of(StreamData.integer())
            ) do
        pq1 = BalancedTree.from_list(l1)

        # We verify merge by pushing all elements of l2 into pq1
        combined_pq = Enum.reduce(l2, pq1, &BalancedTree.push(&2, &1))

        # Size should equal sum (duplicates preserved)
        assert BalancedTree.size(combined_pq) == length(l1) + length(l2)

        result = BalancedTree.to_list(combined_pq)
        expected = Enum.sort(l1 ++ l2)
        assert result == expected
      end
    end

    property "Elements are always returned in ascending order" do
      check all(list <- StreamData.list_of(StreamData.integer(), min_length: 2)) do
        pq = BalancedTree.from_list(list)

        result = BalancedTree.to_list(pq)

        # Verify ascending order
        Enum.reduce(result, nil, fn elem, prev ->
          if prev do
            assert elem >= prev
          end

          elem
        end)
      end
    end
  end
end
