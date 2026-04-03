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

    property "transpose(transpose(G)) == G" do
      check all(graph <- graph_gen()) do
        assert graph == graph |> Yog.transpose() |> Yog.transpose()
      end
    end

    property "filter_edges consistency" do
      check all(graph <- graph_gen()) do
        predicate = fn _u, _v, _w -> :rand.uniform() > 0.5 end
        filtered = Yog.filter_edges(graph, predicate)

        # Ensure node counts remain the same
        assert Yog.node_count(filtered) == Yog.node_count(graph)

        # Removed edges wouldn't exist anymore
        # No extra edges should have been added
        assert Yog.edge_count(filtered) <= Yog.edge_count(graph)
      end
    end

    property "complement invariants" do
      check all(graph <- graph_gen()) do
        comp = Yog.complement(graph, :default)

        # Complement has exactly same nodes
        assert Yog.all_nodes(comp) |> MapSet.new() == Yog.all_nodes(graph) |> MapSet.new()

        # If we take complement again with weights strictly :default and map graph to :default
        comp_of_comp = Yog.complement(comp, :default)

        normalized_graph =
          graph
          |> Yog.map_edges(fn _ -> :default end)
          # self-loops are lost in complement, so strip them from normalized_graph
          |> Yog.filter_edges(fn u, v, _ -> u != v end)

        assert Yog.all_edges(comp_of_comp) |> MapSet.new() ==
                 Yog.all_edges(normalized_graph) |> MapSet.new()
      end
    end

    property "to_directed / to_undirected invariants" do
      check all(graph <- graph_gen()) do
        directed = Yog.to_directed(graph)
        assert Yog.Model.type(directed) == :directed

        # If it was undirected, directing it should not change its nodes
        assert Yog.node_count(directed) == Yog.node_count(graph)

        undirected = Yog.to_undirected(graph, fn a, _b -> a end)
        assert Yog.Model.type(undirected) == :undirected
      end
    end

    property "contract reduces node count by 1 (if B exists and B != A)" do
      check all(graph <- graph_gen()) do
        nodes = Yog.all_nodes(graph)

        if length(nodes) >= 2 do
          [a, b | _] = Enum.shuffle(nodes)

          contracted = Yog.contract(graph, a, b, fn w1, w2 -> {w1, w2} end)

          assert Yog.node_count(contracted) == Yog.node_count(graph) - 1
          # Node B is gone
          assert not Yog.has_node?(contracted, b)
          # Node A remains
          assert Yog.has_node?(contracted, a)
        end
      end
    end

    property "transitive closure/reduction round-trip for DAGs: reduction(closure(G)) == G when G is transitively reduced" do
      check all(graph <- arborescence_gen()) do
        {:ok, reduced} = Yog.Transform.transitive_reduction(graph)
        closure = Yog.Transform.transitive_closure(reduced)
        {:ok, round_trip} = Yog.Transform.transitive_reduction(closure)

        assert Yog.all_nodes(round_trip) |> MapSet.new() == Yog.all_nodes(graph) |> MapSet.new()
        assert Yog.all_edges(round_trip) |> MapSet.new() == Yog.all_edges(graph) |> MapSet.new()
      end
    end

    property "transitive closure idempotence for DAGs: closure(reduction(G)) == closure(G)" do
      check all(graph <- arborescence_gen()) do
        closure_of_original = Yog.Transform.transitive_closure(graph)
        {:ok, reduced} = Yog.Transform.transitive_reduction(graph)
        closure_of_reduced = Yog.Transform.transitive_closure(reduced)

        assert Yog.all_nodes(closure_of_reduced) |> MapSet.new() ==
                 Yog.all_nodes(closure_of_original) |> MapSet.new()

        assert Yog.all_edges(closure_of_reduced) |> MapSet.new() ==
                 Yog.all_edges(closure_of_original) |> MapSet.new()
      end
    end

    property "transitive reduction idempotence for DAGs: reduction(closure(G)) == reduction(G)" do
      check all(graph <- arborescence_gen()) do
        {:ok, reduction_of_original} = Yog.Transform.transitive_reduction(graph)
        closure = Yog.Transform.transitive_closure(graph)
        {:ok, reduction_of_closure} = Yog.Transform.transitive_reduction(closure)

        assert Yog.all_nodes(reduction_of_closure) |> MapSet.new() ==
                 Yog.all_nodes(reduction_of_original) |> MapSet.new()

        assert Yog.all_edges(reduction_of_closure) |> MapSet.new() ==
                 Yog.all_edges(reduction_of_original) |> MapSet.new()
      end
    end
  end
end
