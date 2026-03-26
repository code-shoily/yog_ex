defmodule Yog.PBT.IOTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.IO.{TGF, LEDA, Pajek, JSON, GraphML, GDF, MatrixMarket, List, Matrix}
  import Yog.IO.Generators

  # Helper to create a graph with 1..N node IDs.
  # Useful for formats that use these indices internally.
  defp reindex_graph(graph) do
    nodes = Yog.all_nodes(graph) |> Enum.sort()
    mapping = nodes |> Enum.with_index(1) |> Enum.into(%{})

    new_graph =
      case graph.kind do
        :directed -> Yog.directed()
        :undirected -> Yog.undirected()
      end

    new_graph =
      Enum.reduce(nodes, new_graph, fn node, acc ->
        Yog.add_node(acc, mapping[node], graph.nodes[node])
      end)

    Enum.reduce(Yog.all_edges(graph), new_graph, fn {u, v, w}, acc ->
      Yog.add_edge!(acc, mapping[u], mapping[v], w)
    end)
  end

  describe "TGF Properties" do
    property "roundtrip: serialize -> parse preserves node count" do
      check all(graph <- string_graph_gen()) do
        options =
          TGF.options_with(fn data -> to_string(data) end, fn w -> {:some, to_string(w)} end)

        tgf_string = TGF.serialize_with(options, graph)

        node_parser = fn _id, label -> label end
        edge_parser = fn label -> label end

        assert {:ok, {:tgf_result, parsed_graph, _warnings}} =
                 TGF.parse_with(tgf_string, graph.kind, node_parser, edge_parser)

        assert Yog.node_count(parsed_graph) == Yog.node_count(graph)
        assert Yog.edge_count(parsed_graph) == Yog.edge_count(graph)
      end
    end
  end

  describe "JSON Properties" do
    property "roundtrip: serialize -> parse preserves structure" do
      check all(graph <- string_graph_gen()) do
        json_string = JSON.to_json(graph)
        assert {:ok, parsed_graph} = JSON.from_json(json_string)

        assert graphs_structurally_equal?(parsed_graph, graph)
      end
    end
  end

  describe "Pajek Properties" do
    property "roundtrip: serialize -> parse preserves counts" do
      check all(graph <- string_graph_gen()) do
        options =
          Pajek.options_with(
            &to_string/1,
            fn _ -> :none end,
            fn _ -> Pajek.default_node_attributes() end,
            false,
            false
          )

        pajek_string = Pajek.serialize_with(options, graph)

        assert {:ok, {:pajek_result, parsed_graph, _warnings}} = Pajek.parse(pajek_string)

        assert Yog.node_count(parsed_graph) == Yog.node_count(graph)
        assert Yog.edge_count(parsed_graph) == Yog.edge_count(graph)
      end
    end
  end

  describe "GraphML Properties" do
    property "roundtrip: serialize -> parse preserves structure" do
      check all(graph <- string_graph_gen()) do
        xml = GraphML.serialize(graph)
        assert {:ok, parsed_graph} = GraphML.deserialize(xml)

        assert Yog.node_count(parsed_graph) == Yog.node_count(graph)
        assert Yog.edge_count(parsed_graph) == Yog.edge_count(graph)
        assert parsed_graph.kind == graph.kind
      end
    end
  end

  describe "GDF Properties" do
    property "roundtrip: serialize -> parse preserves counts" do
      check all(graph <- string_graph_gen()) do
        gdf_string = GDF.serialize(graph)
        assert {:ok, parsed_graph} = GDF.deserialize(gdf_string)

        assert Yog.node_count(parsed_graph) == Yog.node_count(graph)
        assert Yog.edge_count(parsed_graph) == Yog.edge_count(graph)
      end
    end
  end

  describe "Matrix Market Properties" do
    property "roundtrip: serialize -> parse preserves edge count" do
      check all(graph <- Yog.Generators.graph_gen()) do
        # Matrix Market expects 1..N node IDs
        graph = graph |> reindex_graph() |> Yog.Transform.map_edges(fn _ -> 1.0 end)

        mm_string = MatrixMarket.serialize(graph)

        assert {:ok, {:matrix_market_result, parsed_graph, _warnings}} =
                 MatrixMarket.parse(mm_string)

        assert Yog.edge_count(parsed_graph) == Yog.edge_count(graph)
      end
    end
  end

  describe "LEDA Properties" do
    property "roundtrip: serialize -> parse preserves node count" do
      check all(graph <- string_graph_gen()) do
        # LEDA uses 1..N internally and re-maps on output.
        # When parsed back, node IDs will be 1..N.
        graph = reindex_graph(graph)
        leda_string = LEDA.serialize(graph)
        assert {:ok, {:leda_result, parsed_graph, _warnings}} = LEDA.parse(leda_string)

        assert Yog.node_count(parsed_graph) == Yog.node_count(graph)
        assert Yog.edge_count(parsed_graph) == Yog.edge_count(graph)
      end
    end
  end

  describe "Adjacency List/Matrix Properties" do
    property "roundtrip: List.to_list -> List.from_list preserves structure" do
      check all(graph <- Yog.Generators.graph_gen()) do
        list = List.to_list(graph)
        parsed = List.from_list(graph.kind, list)

        # Adjacency list from_list maps node data to nil
        expected = Yog.Transform.map_nodes(graph, fn _ -> nil end)
        assert graphs_structurally_equal?(parsed, expected)
      end
    end

    property "roundtrip: Matrix.to_matrix -> Matrix.from_matrix preserves counts" do
      nodes = Enum.to_list(0..9)
      base = Yog.undirected()
      graph_with_nodes = Enum.reduce(nodes, base, fn id, g -> Yog.add_node(g, id, nil) end)

      check all(
              edges <-
                StreamData.list_of(
                  {StreamData.integer(0..9), StreamData.integer(0..9),
                   StreamData.integer(1..100)},
                  max_length: 20
                )
            ) do
        graph =
          Enum.reduce(edges, graph_with_nodes, fn {u, v, w}, acc ->
            if u != v do
              case Yog.add_edge(acc, u, v, w) do
                {:ok, new_acc} -> new_acc
                {:error, _} -> acc
              end
            else
              acc
            end
          end)

        {_nodes, matrix} = Matrix.to_matrix(graph)
        parsed = Matrix.from_matrix(graph.kind, matrix)

        assert Yog.node_count(parsed) == Yog.node_count(graph)
        assert Yog.edge_count(parsed) == Yog.edge_count(graph)
      end
    end
  end
end
