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
        assert valid_heap?(pq)
        sorted_from_pq = PairingHeap.to_list(pq)

        assert sorted_from_pq == Enum.sort(list)
      end
    end

    property "Works with custom comparison functions (Max-Heap)" do
      max_cmp = fn a, b -> a >= b end

      check all(list <- StreamData.list_of(StreamData.integer())) do
        pq = PairingHeap.from_list(list, max_cmp)
        assert valid_heap?(pq)
        sorted_from_pq = PairingHeap.to_list(pq)

        assert sorted_from_pq == Enum.sort(list, :desc)
      end
    end

    property "Peek always returns the same value as the first popped element" do
      check all(list <- StreamData.list_of(StreamData.integer(), min_length: 1)) do
        pq = PairingHeap.from_list(list)
        assert valid_heap?(pq)

        {:ok, peek_val} = PairingHeap.peek(pq)
        {:ok, pop_val, new_pq} = PairingHeap.pop(pq)
        assert valid_heap?(new_pq)

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
              assert valid_heap?(new_pq)
              assert PairingHeap.size(new_pq) == expected_size + 1
              {new_pq, expected_size + 1}

            {:pop} ->
              case PairingHeap.pop(pq) do
                {:ok, _val, new_pq} ->
                  assert valid_heap?(new_pq)
                  assert PairingHeap.size(new_pq) == expected_size - 1
                  {new_pq, expected_size - 1}

                :error ->
                  assert valid_heap?(pq)
                  assert expected_size == 0
                  {pq, 0}
              end
          end
        end)
      end
    end

    property "Merging priority queues via merge/2 preserves overall order, size, and invariants" do
      check all(
              l1 <- StreamData.list_of(StreamData.integer()),
              l2 <- StreamData.list_of(StreamData.integer())
            ) do
        pq1 = PairingHeap.from_list(l1)
        pq2 = PairingHeap.from_list(l2)
        assert valid_heap?(pq1)
        assert valid_heap?(pq2)

        combined_pq = PairingHeap.merge(pq1, pq2)
        assert valid_heap?(combined_pq)

        assert PairingHeap.size(combined_pq) == length(l1) + length(l2)
        assert PairingHeap.to_list(combined_pq) == Enum.sort(l1 ++ l2)
      end
    end
  end

  # Helper to recursively check pairing heap structural invariants.
  defp valid_heap?(%PairingHeap.Empty{size: 0}), do: true
  defp valid_heap?(%PairingHeap.Empty{size: _size}), do: false

  defp valid_heap?(%PairingHeap.Node{value: val, children: children, compare_fn: cmp, size: size}) do
    # 1. Total size must match 1 + sum of sizes of children
    children_sizes = Enum.map(children, &heap_size/1)
    size_ok = size == 1 + Enum.sum(children_sizes)

    # 2. Every child must be a valid heap
    children_valid = Enum.all?(children, &valid_heap?/1)

    # 3. Every child's root value must satisfy the comparison with parent value
    heap_property_ok =
      Enum.all?(children, fn
        %PairingHeap.Empty{} -> true
        %PairingHeap.Node{value: child_val} -> cmp.(val, child_val)
      end)

    size_ok and children_valid and heap_property_ok
  end

  defp heap_size(%PairingHeap.Empty{}), do: 0
  defp heap_size(%PairingHeap.Node{size: s}), do: s
end
