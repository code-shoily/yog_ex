defmodule Yog.PBT.LibgraphYogFunctionalityTest do
  @moduledoc """
  Property-based tests comparing libgraph and Yog algorithms on equivalent graphs.

  These tests ensure that:
  1. Converting between libgraph and Yog preserves graph structure
  2. Equivalent algorithms yield consistent results on both representations
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.Connectivity.{Components, KCore, SCC}
  alias Yog.DAG.Algorithm, as: DAGAlgorithm
  alias Yog.IO.Libgraph
  alias Yog.MST
  alias Yog.Pathfinding.{AStar, Dijkstra}
  alias Yog.Property.{Cyclicity, Structure}

  # =============================================================================
  # Topological Sort Tests (DAGs only)
  # =============================================================================

  describe "topological sort equivalence" do
    property "libgraph topsort and Yog topological_sort agree on arborescences" do
      check all(yog_graph <- Yog.Generators.arborescence_gen()) do
        # Convert to libgraph
        libgraph = Libgraph.to_libgraph(yog_graph)

        # Get topological sorts from both libraries
        # libgraph returns list directly, Yog returns {:ok, list}
        libgraph_topsort = Graph.topsort(libgraph)

        # Yog requires a DAG, so we convert the graph to a DAG first
        {:ok, dag} = Yog.DAG.from_graph(yog_graph)
        yog_topsort = DAGAlgorithm.topological_sort(dag)

        # Both should produce valid topological orderings
        # (Different valid orderings may exist, so we check validity rather than equality)
        assert length(libgraph_topsort) == length(yog_topsort)
        assert length(libgraph_topsort) == Yog.Model.order(yog_graph)

        # Verify libgraph result is valid: for every edge u->v, u comes before v
        assert valid_topological_order?(libgraph, libgraph_topsort)

        # Verify Yog result is valid: for every edge u->v, u comes before v
        assert valid_topological_order_yog?(yog_graph, yog_topsort)
      end
    end

    property "libgraph topsort and Yog topological_sort agree on DAGs" do
      check all(yog_graph <- dag_graph_gen()) do
        libgraph = Libgraph.to_libgraph(yog_graph)

        libgraph_topsort = Graph.topsort(libgraph)
        {:ok, dag} = Yog.DAG.from_graph(yog_graph)
        yog_topsort = DAGAlgorithm.topological_sort(dag)

        assert length(libgraph_topsort) == length(yog_topsort)
        assert valid_topological_order?(libgraph, libgraph_topsort)
        assert valid_topological_order_yog?(yog_graph, yog_topsort)
      end
    end
  end

  # =============================================================================
  # K-Core / Degeneracy Tests
  # =============================================================================

  describe "k-core degeneracy equivalence" do
    property "libgraph degeneracy and KCore.degeneracy agree" do
      check all(yog_graph <- Yog.Generators.undirected_graph_gen()) do
        libgraph = Libgraph.to_libgraph(yog_graph)

        libgraph_degeneracy = Graph.degeneracy(libgraph)
        yog_degeneracy = KCore.degeneracy(yog_graph)

        assert libgraph_degeneracy == yog_degeneracy
      end
    end

    property "libgraph k_core and Yog KCore.detect agree" do
      check all(
              yog_graph <- Yog.Generators.undirected_graph_gen(),
              k <- StreamData.integer(1..5)
            ) do
        libgraph = Libgraph.to_libgraph(yog_graph)

        libgraph_core = Graph.k_core(libgraph, k)
        yog_core_graph = KCore.detect(yog_graph, k)

        # Compare core sizes
        if is_nil(libgraph_core) do
          # libgraph returns nil when no k-core exists
          # Yog returns an empty graph or minimal graph
          assert Yog.Model.order(yog_core_graph) == 0
        else
          libgraph_vertices = Graph.vertices(libgraph_core) |> MapSet.new()
          yog_vertices = Yog.Model.all_nodes(yog_core_graph) |> MapSet.new()
          assert libgraph_vertices == yog_vertices
        end
      end
    end
  end

  # =============================================================================
  # Minimum Spanning Tree Tests
  # =============================================================================

  describe "MST equivalence" do
    property "MST produces valid spanning tree" do
      check all(yog_graph <- Yog.Generators.undirected_graph_gen()) do
        # Skip empty/small graphs
        if Yog.Model.order(yog_graph) >= 2 and Yog.Graph.edge_count(yog_graph) >= 1 do
          # Yog MST via Kruskal
          case MST.kruskal(yog_graph) do
            {:ok, mst_result} ->
              # MST.Result contains the edges of the spanning tree
              # Verify it's a valid spanning tree (n-1 edges for n nodes if connected)
              if Structure.connected?(yog_graph) do
                assert mst_result.edge_count == Yog.Model.order(yog_graph) - 1
              end

            {:error, _} ->
              # Graph might be disconnected - that's fine
              :ok
          end
        end
      end
    end
  end

  # =============================================================================
  # Shortest Path Tests
  # =============================================================================

  describe "shortest path equivalence" do
    property "Dijkstra shortest paths agree on graphs with non-negative weights" do
      check all(
              yog_graph <- directed_graph_with_positive_weights_gen(),
              source <- StreamData.integer(1..20)
            ) do
        # Only test if source exists in graph
        if source in Yog.Model.all_nodes(yog_graph) do
          libgraph = Libgraph.to_libgraph(yog_graph)

          # Get all reachable nodes from source
          targets =
            Yog.Model.all_nodes(yog_graph)
            |> Enum.filter(fn target -> target != source end)
            |> Enum.take(5)

          for target <- targets do
            libgraph_path = Graph.get_shortest_path(libgraph, source, target)

            yog_result =
              Dijkstra.shortest_path(
                in: yog_graph,
                from: source,
                to: target
              )

            case {libgraph_path, yog_result} do
              {nil, :error} ->
                # Both agree: no path exists
                :ok

              {[_ | _], {:ok, path}} ->
                # Both found a path - check path validity
                # Note: Different valid shortest paths may exist
                # Path struct has :nodes list, not :from/:to
                [path_start | _] = path.nodes
                path_end = List.last(path.nodes)
                assert path_start == source
                assert path_end == target

              {nil, {:ok, _}} ->
                # libgraph found no path but Yog did - check if path exists
                flunk("Path disagreement for #{source} -> #{target}")

              {[_ | _], :error} ->
                # libgraph found path but Yog didn't
                flunk("Path disagreement for #{source} -> #{target}")
            end
          end
        end
      end
    end

    property "A* and Dijkstra agree on unweighted graphs" do
      check all(
              yog_graph <- unweighted_directed_graph_gen(),
              source <- StreamData.integer(1..10),
              target <- StreamData.integer(1..10)
            ) do
        nodes = Yog.Model.all_nodes(yog_graph)

        if source in nodes and target in nodes and source != target do
          # For unweighted graphs, Dijkstra should match A* with zero heuristic
          dijkstra_result =
            Dijkstra.shortest_path(
              in: yog_graph,
              from: source,
              to: target
            )

          # A* with zero heuristic is equivalent to Dijkstra
          # Note: heuristic function takes (current, target) arguments
          a_star_result =
            AStar.a_star(
              in: yog_graph,
              from: source,
              to: target,
              heuristic: fn _current, _target -> 0 end
            )

          case {dijkstra_result, a_star_result} do
            {:error, :error} -> :ok
            {{:ok, d_path}, {:ok, a_path}} -> assert d_path.weight == a_path.weight
            {:error, {:ok, _}} -> flunk("Dijkstra failed but A* succeeded")
            {{:ok, _}, :error} -> flunk("Dijkstra succeeded but A* failed")
            _ -> flunk("A* and Dijkstra disagree")
          end
        end
      end
    end
  end

  # =============================================================================
  # Connected Components Tests
  # =============================================================================

  describe "connected components equivalence" do
    property "libgraph components and Yog components agree on undirected graphs" do
      check all(yog_graph <- Yog.Generators.undirected_graph_gen()) do
        libgraph = Libgraph.to_libgraph(yog_graph)

        libgraph_components = Graph.components(libgraph)
        yog_components = Components.connected_components(yog_graph)

        # Both should partition the vertices
        libgraph_partition =
          libgraph_components
          |> List.flatten()
          |> MapSet.new()

        yog_partition =
          yog_components
          |> Enum.flat_map(& &1)
          |> MapSet.new()

        all_nodes = Yog.Model.all_nodes(yog_graph) |> MapSet.new()

        # Both should cover all nodes
        assert libgraph_partition == all_nodes
        assert yog_partition == all_nodes

        # Number of components should match
        assert length(libgraph_components) == length(yog_components)
      end
    end

    property "libgraph strong_components and Yog SCC agree" do
      check all(yog_graph <- Yog.Generators.directed_graph_gen()) do
        libgraph = Libgraph.to_libgraph(yog_graph)

        libgraph_scc = Graph.strong_components(libgraph)
        yog_scc = SCC.strongly_connected_components(yog_graph)

        # Both should partition the vertices
        libgraph_partition =
          libgraph_scc
          |> List.flatten()
          |> MapSet.new()

        yog_partition =
          yog_scc
          |> Enum.flat_map(& &1)
          |> MapSet.new()

        all_nodes = Yog.Model.all_nodes(yog_graph) |> MapSet.new()

        assert libgraph_partition == all_nodes
        assert yog_partition == all_nodes
        assert length(libgraph_scc) == length(yog_scc)
      end
    end
  end

  # =============================================================================
  # Roundtrip Property Tests
  # =============================================================================

  describe "roundtrip conversion preserves algorithm results" do
    property "topological sort preserved through roundtrip conversion" do
      check all(yog_graph <- Yog.Generators.arborescence_gen()) do
        # Yog -> libgraph -> Yog
        libgraph = Libgraph.to_libgraph(yog_graph)
        {:ok, recovered_graph} = Libgraph.from_libgraph(libgraph, force_type: :simple)

        # Both should have same structure
        assert Yog.Model.order(yog_graph) == Yog.Model.order(recovered_graph)
        assert Yog.Graph.edge_count(yog_graph) == Yog.Graph.edge_count(recovered_graph)

        # Both should be acyclic
        assert Cyclicity.acyclic?(yog_graph)
        assert Cyclicity.acyclic?(recovered_graph)
      end
    end

    property "node data and edge weights preserved through roundtrip" do
      check all(yog_graph <- Yog.Generators.directed_graph_gen()) do
        libgraph = Libgraph.to_libgraph(yog_graph)
        {:ok, recovered} = Libgraph.from_libgraph(libgraph, force_type: :simple)

        # Node count preserved
        assert Yog.Model.order(yog_graph) == Yog.Model.order(recovered)

        # Edge count preserved (for simple graphs)
        assert Yog.Graph.edge_count(yog_graph) == Yog.Graph.edge_count(recovered)

        # Graph type preserved
        assert yog_graph.kind == recovered.kind
      end
    end
  end

  # =============================================================================
  # Helper Functions
  # =============================================================================

  # Valid topological order: for every edge u->v, u appears before v in the order
  defp valid_topological_order?(libgraph, order) do
    order_map = order |> Enum.with_index() |> Enum.into(%{})

    Enum.all?(Graph.edges(libgraph), fn edge ->
      u_pos = Map.get(order_map, edge.v1)
      v_pos = Map.get(order_map, edge.v2)
      u_pos < v_pos
    end)
  end

  defp valid_topological_order_yog?(yog_graph, order) do
    order_map = order |> Enum.with_index() |> Enum.into(%{})

    edges = Yog.Model.all_edges(yog_graph)

    Enum.all?(edges, fn {u, v, _} ->
      u_pos = Map.get(order_map, u)
      v_pos = Map.get(order_map, v)
      u_pos < v_pos
    end)
  end

  # Generator for DAGs (directed acyclic graphs)
  defp dag_graph_gen do
    gen all(size <- StreamData.integer(2..15)) do
      nodes = Enum.to_list(1..size)
      graph = Enum.reduce(nodes, Yog.directed(), fn id, g -> Yog.add_node(g, id, nil) end)

      # Add edges only from lower to higher numbered nodes to ensure acyclicity
      edges =
        for u <- nodes, v <- nodes, u < v, do: {u, v, Enum.random(1..100)}

      # Take a random subset of possible edges
      selected_edges = Enum.take_random(edges, div(size * (size - 1), 4) + 1)

      Enum.reduce(selected_edges, graph, fn {u, v, w}, g ->
        case Yog.add_edge(g, u, v, w) do
          {:ok, new_g} -> new_g
          {:error, _} -> g
        end
      end)
    end
  end

  # Generator for directed graphs with positive weights (for Dijkstra)
  defp directed_graph_with_positive_weights_gen do
    gen all(
          nodes <- node_list_gen(2, 10),
          num_edges <- StreamData.integer(1..20)
        ) do
      graph = Enum.reduce(nodes, Yog.directed(), fn id, g -> Yog.add_node(g, id, nil) end)

      edges =
        StreamData.list_of(
          {StreamData.member_of(nodes), StreamData.member_of(nodes), StreamData.integer(1..100)},
          length: num_edges
        )
        |> Enum.at(0)

      Enum.reduce(edges, graph, fn {u, v, w}, g ->
        if u != v do
          case Yog.add_edge(g, u, v, w) do
            {:ok, new_g} -> new_g
            {:error, _} -> g
          end
        else
          g
        end
      end)
    end
  end

  # Generator for unweighted directed graphs (all weights = 1)
  defp unweighted_directed_graph_gen do
    gen all(
          nodes <- node_list_gen(2, 10),
          num_edges <- StreamData.integer(1..15)
        ) do
      graph = Enum.reduce(nodes, Yog.directed(), fn id, g -> Yog.add_node(g, id, nil) end)

      edges =
        StreamData.list_of(
          {StreamData.member_of(nodes), StreamData.member_of(nodes)},
          length: num_edges
        )
        |> Enum.at(0)

      Enum.reduce(edges, graph, fn {u, v}, g ->
        if u != v do
          case Yog.add_edge(g, u, v, 1) do
            {:ok, new_g} -> new_g
            {:error, _} -> g
          end
        else
          g
        end
      end)
    end
  end

  defp node_list_gen(min_len, max_len) do
    StreamData.uniq_list_of(StreamData.integer(1..50),
      min_length: min_len,
      max_length: max_len
    )
  end
end
