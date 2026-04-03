defmodule Yog.PBT.DisjointSetTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.DisjointSet

  @moduledoc """
  Property-based tests for Yog.DisjointSet.
  Verifies equivalence relation properties, set counting, and partitioning logic.
  """

  describe "DisjointSet Properties" do
    property "Reflexivity: Every element is connected to itself" do
      check all(elements <- StreamData.uniq_list_of(StreamData.integer(), min_length: 1)) do
        dsu = Enum.reduce(elements, DisjointSet.new(), &DisjointSet.add(&2, &1))

        for x <- elements do
          {_dsu2, connected} = DisjointSet.connected?(dsu, x, x)
          assert connected
        end
      end
    end

    property "Symmetry: connectedness is bidirectional" do
      check all(
              elements <-
                StreamData.uniq_list_of(StreamData.integer(), min_length: 2, max_length: 20),
              pairs <-
                StreamData.list_of(
                  {
                    StreamData.member_of(elements),
                    StreamData.member_of(elements)
                  },
                  max_length: 15
                )
            ) do
        dsu = DisjointSet.from_pairs(pairs)

        for x <- elements, y <- elements do
          {dsu, x_y} = DisjointSet.connected?(dsu, x, y)
          {_dsu, y_x} = DisjointSet.connected?(dsu, y, x)
          assert x_y == y_x
        end
      end
    end

    property "Transitivity: If x-y and y-z, then x-z" do
      check all(
              # Small enough to brute-force all triplets
              elements <-
                StreamData.uniq_list_of(StreamData.integer(), min_length: 3, max_length: 15),
              pairs <-
                StreamData.list_of(
                  {
                    StreamData.member_of(elements),
                    StreamData.member_of(elements)
                  },
                  max_length: 10
                )
            ) do
        dsu = DisjointSet.from_pairs(pairs)

        for x <- elements, y <- elements, z <- elements do
          {dsu, x_y} = DisjointSet.connected?(dsu, x, y)
          {dsu, y_z} = DisjointSet.connected?(dsu, y, z)
          {_dsu, x_z} = DisjointSet.connected?(dsu, x, z)

          if x_y and y_z do
            assert x_z, "Expected #{x} to be connected to #{z} via #{y}"
          end
        end
      end
    end

    property "Union reduces set count by exactly 1 for distinct sets" do
      check all(
              elements <-
                StreamData.uniq_list_of(StreamData.integer(), min_length: 2, max_length: 50),
              ops <-
                StreamData.list_of(
                  {
                    StreamData.member_of(elements),
                    StreamData.member_of(elements)
                  },
                  max_length: 30
                )
            ) do
        # Pre-add all elements so count doesn't increase unexpectedly during find/union
        initial_dsu = Enum.reduce(elements, DisjointSet.new(), &DisjointSet.add(&2, &1))

        Enum.reduce(ops, initial_dsu, fn {x, y}, dsu ->
          before_count = DisjointSet.count_sets(dsu)
          {dsu_temp, already_connected} = DisjointSet.connected?(dsu, x, y)

          dsu_after = DisjointSet.union(dsu_temp, x, y)
          after_count = DisjointSet.count_sets(dsu_after)

          if already_connected do
            assert before_count == after_count
          else
            assert after_count == before_count - 1
          end

          dsu_after
        end)
      end
    end

    property "Partitioning: to_lists produces disjoint sets covering all elements" do
      check all(
              elements <-
                StreamData.uniq_list_of(StreamData.integer(), min_length: 1, max_length: 50),
              pairs <-
                StreamData.list_of(
                  {
                    StreamData.member_of(elements),
                    StreamData.member_of(elements)
                  },
                  max_length: 25
                )
            ) do
        # Build DSU and ensure all elements are at least 'add'ed
        dsu = Enum.reduce(elements, DisjointSet.new(), &DisjointSet.add(&2, &1))
        dsu = Enum.reduce(pairs, dsu, fn {x, y}, acc -> DisjointSet.union(acc, x, y) end)

        sets = DisjointSet.to_lists(dsu)
        flattened = List.flatten(sets)

        # 1. Total elements count should match size
        assert length(flattened) == DisjointSet.size(dsu)
        assert length(flattened) == length(elements)

        # 2. All elements should be unique across all sets
        assert length(flattened) == length(Enum.uniq(flattened))

        # 3. Each inner list should have elements that are all connected to each other
        for s <- sets, length(s) > 1 do
          [first | rest] = s

          for other <- rest do
            {_, connected} = DisjointSet.connected?(dsu, first, other)
            assert connected, "Expected #{first} and #{other} in the same set to be connected"
          end
        end

        # 4. Elements from different sets should NOT be connected
        if length(sets) > 1 do
          [set_a, set_b | _] = sets

          for x <- set_a, y <- set_b do
            {_, connected} = DisjointSet.connected?(dsu, x, y)
            refute connected, "Expected elements from different sets to be disconnected"
          end
        end
      end
    end
  end
end
