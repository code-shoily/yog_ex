defmodule Yog.IO.Graph6Test do
  use ExUnit.Case

  alias Yog.IO.Graph6

  doctest Yog.IO.Graph6

  describe "parse/1" do
    test "parses C5" do
      assert {:ok, graph} = Graph6.parse("DqK")
      assert Yog.Model.node_count(graph) == 5
      assert Yog.Model.edge_count(graph) == 5
      assert Yog.has_edge?(graph, 0, 1)
      assert Yog.has_edge?(graph, 0, 2)
      assert Yog.has_edge?(graph, 1, 3)
      assert Yog.has_edge?(graph, 2, 4)
      assert Yog.has_edge?(graph, 3, 4)
    end

    test "parses K4" do
      # K4 in graph6: "C~"
      assert {:ok, graph} = Graph6.parse("C~")
      assert Yog.Model.node_count(graph) == 4
      assert Yog.Model.edge_count(graph) == 6
      assert Yog.Model.type(graph) == :undirected
    end

    test "parses single vertex" do
      assert {:ok, graph} = Graph6.parse("@")
      assert Yog.Model.node_count(graph) == 1
      assert Yog.Model.edge_count(graph) == 0
    end

    test "parses empty edge graph" do
      assert {:ok, graph} = Graph6.parse("A?")
      assert Yog.Model.node_count(graph) == 2
      assert Yog.Model.edge_count(graph) == 0
    end

    test "rejects empty input" do
      assert Graph6.parse("") == {:error, :empty_input}
    end

    test "rejects invalid payload length" do
      assert Graph6.parse("Dq") == {:error, :invalid_payload_length}
    end
  end

  describe "serialize/1" do
    test "serializes C5" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(0, 2, 1)
        |> Yog.add_edge_ensure(1, 3, 1)
        |> Yog.add_edge_ensure(2, 4, 1)
        |> Yog.add_edge_ensure(3, 4, 1)

      assert {:ok, "DqK"} = Graph6.serialize(graph)
    end

    test "serializes K4" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(0, 2, 1)
        |> Yog.add_edge_ensure(0, 3, 1)
        |> Yog.add_edge_ensure(1, 2, 1)
        |> Yog.add_edge_ensure(1, 3, 1)
        |> Yog.add_edge_ensure(2, 3, 1)

      assert {:ok, "C~"} = Graph6.serialize(graph)
    end

    test "rejects directed graphs" do
      graph = Yog.directed() |> Yog.add_edge_ensure(0, 1, 1)
      assert Graph6.serialize(graph) == {:error, :directed_graph_not_supported}
    end

    test "rejects graphs with self-loops" do
      graph = Yog.undirected() |> Yog.add_edge_ensure(0, 0, 1)
      assert Graph6.serialize(graph) == {:error, :multigraph_not_supported}
    end

    test "rejects invalid node ids" do
      graph = Yog.undirected() |> Yog.add_edge_ensure(1, 2, 1)
      assert Graph6.serialize(graph) == {:error, :invalid_node_ids}
    end
  end

  describe "round-trip" do
    test "preserves structure" do
      original =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(0, 2, 1)
        |> Yog.add_edge_ensure(1, 3, 1)
        |> Yog.add_edge_ensure(2, 4, 1)
        |> Yog.add_edge_ensure(3, 4, 1)

      {:ok, g6} = Graph6.serialize(original)
      {:ok, restored} = Graph6.parse(g6)

      assert Yog.Model.node_count(restored) == Yog.Model.node_count(original)
      assert Yog.Model.edge_count(restored) == Yog.Model.edge_count(original)

      for {u, v, _} <- Yog.Model.all_edges(original) do
        assert Yog.has_edge?(restored, u, v)
      end
    end
  end

  describe "edge cases" do
    test "rejects string node ids" do
      graph = Yog.undirected() |> Yog.add_edge_ensure(:a, :b, 1)
      assert Graph6.serialize(graph) == {:error, :invalid_node_ids}
    end

    test "rejects atom node ids" do
      graph = Yog.undirected() |> Yog.add_edge_ensure("a", "b", 1)
      assert Graph6.serialize(graph) == {:error, :invalid_node_ids}
    end

    test "rejects node ids not starting from 0" do
      graph = Yog.undirected() |> Yog.add_edge_ensure(1, 2, 1)
      assert Graph6.serialize(graph) == {:error, :invalid_node_ids}
    end

    test "rejects node ids with gaps" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(0, 3, 1)

      assert Graph6.serialize(graph) == {:error, :invalid_node_ids}
    end

    test "serializes empty graph" do
      graph = Yog.undirected()
      assert {:ok, "?"} = Graph6.serialize(graph)
    end

    test "serializes graph with isolated nodes" do
      graph =
        Yog.undirected()
        |> Yog.add_node(0, nil)
        |> Yog.add_node(1, nil)
        |> Yog.add_node(2, nil)

      assert {:ok, g6} = Graph6.serialize(graph)
      assert {:ok, parsed} = Graph6.parse(g6)
      assert Yog.Model.node_count(parsed) == 3
      assert Yog.Model.edge_count(parsed) == 0
    end

    test "serializes graph with 63 nodes (extended header boundary)" do
      graph =
        Enum.reduce(0..62, Yog.undirected(), fn i, g ->
          if i > 0 do
            Yog.add_edge_ensure(g, 0, i, 1)
          else
            g
          end
        end)

      assert {:ok, g6} = Graph6.serialize(graph)
      assert {:ok, parsed} = Graph6.parse(g6)
      assert Yog.Model.node_count(parsed) == 63
    end

    test "roundtrip with node data as empty map" do
      graph =
        Yog.undirected()
        |> Yog.add_node(0, %{})
        |> Yog.add_node(1, %{})
        |> Yog.add_edge_ensure(0, 1, 1)

      assert {:ok, g6} = Graph6.serialize(graph)
      assert {:ok, parsed} = Graph6.parse(g6)
      assert Yog.Model.node_count(parsed) == 2
      assert Yog.Model.edge_count(parsed) == 1
    end
  end

  describe "file I/O" do
    @tmp_file "/tmp/test_yog_graph6.g6"
    @fixture "test/fixtures/io/sample.g6"

    test "reads sample fixture" do
      assert File.exists?(@fixture)
      {:ok, [graph]} = Graph6.read(@fixture)
      assert Yog.Model.node_count(graph) == 5
      assert Yog.Model.edge_count(graph) == 5
    end

    test "roundtrip write and read" do
      original =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(0, 2, 1)
        |> Yog.add_edge_ensure(1, 3, 1)
        |> Yog.add_edge_ensure(2, 4, 1)
        |> Yog.add_edge_ensure(3, 4, 1)

      assert :ok = Graph6.write(@tmp_file, original)
      assert File.exists?(@tmp_file)

      {:ok, [reloaded]} = Graph6.read(@tmp_file)
      assert Yog.Model.node_count(reloaded) == 5
      assert Yog.Model.edge_count(reloaded) == 5

      File.rm(@tmp_file)
    end

    test "write multiple graphs" do
      g1 = Yog.undirected() |> Yog.add_edge_ensure(0, 1, 1)
      g2 = Yog.undirected() |> Yog.add_edge_ensure(0, 1, 1) |> Yog.add_edge_ensure(1, 2, 1)

      assert :ok = Graph6.write(@tmp_file, [g1, g2])
      {:ok, graphs} = Graph6.read(@tmp_file)
      assert length(graphs) == 2

      File.rm(@tmp_file)
    end

    test "write rejects non-integer node ids" do
      graph = Yog.undirected() |> Yog.add_edge_ensure("a", "b", 1)
      assert {:error, :invalid_node_ids} = Graph6.write(@tmp_file, graph)
    end

    test "read ignores comment lines" do
      content = "# This is a comment\nDqK\n# Another comment\n"
      File.write!(@tmp_file, content)

      {:ok, [graph]} = Graph6.read(@tmp_file)
      assert Yog.Model.node_count(graph) == 5
      File.rm(@tmp_file)
    end
  end
end
