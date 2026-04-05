defmodule Yog.PBT.PairingHeapTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.PairingHeap

  @moduledoc """
  Property-based tests for Yog.PairingHeap.
  Verifies heap invariants, sorting order, and size consistency.
  """

  describe "PairingHeap Properties" do
    property "Popping all elements returns a sorted list" do
      check all(list <- StreamData.list_of(StreamData.integer())) do
        pq = PairingHeap.from_list(list)
        sorted_from_pq = PairingHeap.to_list(pq)

        assert sorted_from_pq == Enum.sort(list)
      end
    end

    property "Works with custom comparison functions (Max-Heap)" do
      max_cmp = fn a, b -> a >= b end

      check all(list <- StreamData.list_of(StreamData.integer())) do
        pq = PairingHeap.from_list(list, max_cmp)
        sorted_from_pq = PairingHeap.to_list(pq)

        assert sorted_from_pq == Enum.sort(list, :desc)
      end
    end

    property "Peek always returns the same value as the first popped element" do
      check all(list <- StreamData.list_of(StreamData.integer(), min_length: 1)) do
        pq = PairingHeap.from_list(list)

        {:ok, peek_val} = PairingHeap.peek(pq)
        {:ok, pop_val, _new_pq} = PairingHeap.pop(pq)

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
        Enum.reduce(ops, {PairingHeap.new(), 0}, fn op, {pq, expected_size} ->
          case op do
            {:push, val} ->
              new_pq = PairingHeap.push(pq, val)
              assert PairingHeap.size(new_pq) == expected_size + 1
              {new_pq, expected_size + 1}

            {:pop} ->
              case PairingHeap.pop(pq) do
                {:ok, _val, new_pq} ->
                  assert PairingHeap.size(new_pq) == expected_size - 1
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
        pq1 = PairingHeap.from_list(l1)

        # We verify merge by pushing all elements of l2 into pq1
        combined_pq = Enum.reduce(l2, pq1, &PairingHeap.push(&2, &1))

        assert PairingHeap.size(combined_pq) == length(l1) + length(l2)
        assert PairingHeap.to_list(combined_pq) == Enum.sort(l1 ++ l2)
      end
    end
  end
end
