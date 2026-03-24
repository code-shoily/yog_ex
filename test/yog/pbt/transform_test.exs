defmodule Yog.PBT.TransformTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Transform Properties" do
    property "map_nodes Identity Law: map_nodes(G, id) == G" do
      check all(graph <- graph_gen()) do
        assert graph == Yog.map_nodes(graph, fn data -> data end)
      end
    end

    property "map_nodes Composition Law: map(map(f), g) == map(g . f)" do
      check all(graph <- graph_gen()) do
        f = fn x -> {:mapped, x} end
        g = fn x -> {:again, x} end

        res1 = graph |> Yog.map_nodes(f) |> Yog.map_nodes(g)
        res2 = graph |> Yog.map_nodes(fn x -> g.(f.(x)) end)

        assert res1 == res2
      end
    end

    property "map_edges Identity Law: map_edges(G, id) == G" do
      check all(graph <- graph_gen()) do
        assert graph == Yog.map_edges(graph, fn weight -> weight end)
      end
    end

    property "map_nodes preserves graph topology (V and E counts)" do
      check all(graph <- graph_gen()) do
        mapped = Yog.map_nodes(graph, fn _ -> :constant end)
        assert Yog.node_count(mapped) == Yog.node_count(graph)
        assert Yog.edge_count(mapped) == Yog.edge_count(graph)
      end
    end

    property "filter_nodes consistency" do
      check all(graph <- graph_gen()) do
        filtered = Yog.Transform.filter_nodes(graph, fn _data -> true end)
        assert filtered == graph

        predicate = fn data -> is_integer(data) and data < 50 end
        g = Yog.map_nodes(graph, fn _ -> :rand.uniform(100) end)
        filtered = Yog.filter_nodes(g, predicate)

        for {_id, data} <- Yog.Model.nodes(filtered) do
          assert predicate.(data)
        end

        node_ids = Yog.all_nodes(filtered) |> MapSet.new()

        for {u, v, _} <- Yog.all_edges(filtered) do
          assert MapSet.member?(node_ids, u)
          assert MapSet.member?(node_ids, v)
        end
      end
    end

    property "merge idempotence: merge(G, G) == G" do
      check all(graph <- graph_gen()) do
        assert graph == Yog.merge(graph, graph)
      end
    end

    property "subgraph invariants" do
      check all(graph <- graph_gen()) do
        ids = Yog.all_nodes(graph)
        subset = Enum.take(ids, Enum.random(1..length(ids)))

        sub = Yog.subgraph(graph, subset)

        sub_nodes = Yog.all_nodes(sub) |> MapSet.new()
        subset_set = MapSet.new(subset)
        assert MapSet.subset?(sub_nodes, subset_set)

        for {u, v, _} <- Yog.all_edges(sub) do
          assert MapSet.member?(subset_set, u)
          assert MapSet.member?(subset_set, v)
        end
      end
    end
  end
end
