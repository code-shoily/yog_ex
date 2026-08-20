defmodule Yog.Traversal.SortTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Yog.Traversal.Sort

  alias Yog.Traversal.Sort

  describe "topological_sort/1" do
    test "sorts a linear DAG" do
      g = Yog.from_edges(:directed, [{1, 2, 1}, {2, 3, 1}])
      assert {:ok, [1, 2, 3]} = Sort.topological_sort(g)
    end

    test "detects cycles" do
      g = Yog.from_edges(:directed, [{1, 2, 1}, {2, 3, 1}, {3, 1, 1}])
      assert {:error, :contains_cycle} = Sort.topological_sort(g)
    end

    test "raises ArgumentError on undirected graph or invalid struct" do
      assert_raise ArgumentError, ~r/topological_sort expects a directed graph/, fn ->
        Sort.topological_sort(Yog.undirected())
      end

      assert_raise ArgumentError, ~r/expected a Yog.Graph struct/, fn ->
        Sort.topological_sort(:not_a_graph)
      end
    end
  end

  describe "lexicographical_topological_sort/2" do
    test "sorts deterministically using comparator" do
      g =
        Yog.from_nodes(:directed, [{1, "c"}, {2, "a"}, {3, "b"}])
        |> Yog.add_edges!([{1, 3, 1}, {2, 3, 1}])

      cmp = fn a, b ->
        cond do
          a < b -> :lt
          a > b -> :gt
          true -> :eq
        end
      end

      assert {:ok, [2, 1, 3]} = Sort.lexicographical_topological_sort(g, cmp)
    end

    test "raises ArgumentError on invalid arguments" do
      assert_raise ArgumentError, ~r/expects a directed graph/, fn ->
        Sort.lexicographical_topological_sort(Yog.undirected(), &<=/2)
      end

      assert_raise ArgumentError, ~r/expected compare_nodes to be a 2-arity function/, fn ->
        Sort.lexicographical_topological_sort(Yog.directed(), :not_a_func)
      end
    end
  end

  describe "property tests for Sort" do
    property "topological_sort ordering respects directed edge directions" do
      check all(
              n <- StreamData.integer(2..12),
              raw_edges <-
                StreamData.list_of(
                  StreamData.tuple({StreamData.integer(1..n), StreamData.integer(1..n)})
                )
            ) do
        g =
          Enum.reduce(raw_edges, Yog.directed(), fn {u, v}, acc ->
            Yog.add_edge_ensure(acc, u, v, 1)
          end)

        case Sort.topological_sort(g) do
          {:ok, sorted} ->
            pos = sorted |> Enum.with_index() |> Map.new()

            for {from, to, _w} <- Yog.all_edges(g), from != to do
              assert Map.fetch!(pos, from) < Map.fetch!(pos, to)
            end

          {:error, :contains_cycle} ->
            assert Yog.cyclic?(g)
        end
      end
    end
  end
end
