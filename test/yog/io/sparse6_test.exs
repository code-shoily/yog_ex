defmodule Yog.IO.Sparse6Test do
  use ExUnit.Case

  alias Yog.IO.Sparse6

  doctest Yog.IO.Sparse6

  describe "parse/1" do
    test "parses C5" do
      # Round-trip test will verify this more thoroughly
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(1, 2, 1)
        |> Yog.add_edge_ensure(2, 3, 1)
        |> Yog.add_edge_ensure(3, 4, 1)
        |> Yog.add_edge_ensure(0, 4, 1)

      {:ok, s6} = Sparse6.serialize(graph)
      assert {:ok, parsed} = Sparse6.parse(s6)
      assert Yog.Model.node_count(parsed) == 5
      assert Yog.Model.edge_count(parsed) == 5
    end

    test "parses empty graph" do
      graph = Yog.undirected() |> Yog.add_node(0, nil) |> Yog.add_node(1, nil)
      {:ok, s6} = Sparse6.serialize(graph)
      assert {:ok, parsed} = Sparse6.parse(s6)
      assert Yog.Model.node_count(parsed) == 2
      assert Yog.Model.edge_count(parsed) == 0
    end

    test "requires sparse6 prefix" do
      assert Sparse6.parse("DqK") == {:error, :missing_sparse6_prefix}
    end

    test "rejects empty input" do
      assert Sparse6.parse("") == {:error, :empty_input}
    end
  end

  describe "serialize/1" do
    test "serializes a path graph" do
      graph =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(1, 2, 1)
        |> Yog.add_edge_ensure(2, 3, 1)

      assert {:ok, s6} = Sparse6.serialize(graph)
      assert String.starts_with?(s6, ":")
    end

    test "rejects directed graphs" do
      graph = Yog.directed() |> Yog.add_edge_ensure(0, 1, 1)
      assert Sparse6.serialize(graph) == {:error, :directed_graph_not_supported}
    end

    test "rejects graphs with self-loops" do
      graph = Yog.undirected() |> Yog.add_edge_ensure(0, 0, 1)
      assert Sparse6.serialize(graph) == {:error, :multigraph_not_supported}
    end

    test "rejects invalid node ids" do
      graph = Yog.undirected() |> Yog.add_edge_ensure(1, 2, 1)
      assert Sparse6.serialize(graph) == {:error, :invalid_node_ids}
    end
  end

  describe "round-trip" do
    test "preserves structure for various graphs" do
      graphs = [
        # Path P4
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(1, 2, 1)
        |> Yog.add_edge_ensure(2, 3, 1),
        # Star S4
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(0, 2, 1)
        |> Yog.add_edge_ensure(0, 3, 1),
        # Cycle C5
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(1, 2, 1)
        |> Yog.add_edge_ensure(2, 3, 1)
        |> Yog.add_edge_ensure(3, 4, 1)
        |> Yog.add_edge_ensure(0, 4, 1),
        # Complete K4
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(0, 2, 1)
        |> Yog.add_edge_ensure(0, 3, 1)
        |> Yog.add_edge_ensure(1, 2, 1)
        |> Yog.add_edge_ensure(1, 3, 1)
        |> Yog.add_edge_ensure(2, 3, 1)
      ]

      for original <- graphs do
        {:ok, s6} = Sparse6.serialize(original)
        {:ok, restored} = Sparse6.parse(s6)

        assert Yog.Model.node_count(restored) == Yog.Model.node_count(original)
        assert Yog.Model.edge_count(restored) == Yog.Model.edge_count(original)

        for {u, v, _} <- Yog.Model.all_edges(original) do
          assert Yog.has_edge?(restored, u, v)
        end
      end
    end
  end

  describe "file I/O" do
    @tmp_file "/tmp/test_yog_sparse6.s6"
    @fixture "test/fixtures/io/sample.s6"

    test "reads sample fixture" do
      assert File.exists?(@fixture)
      {:ok, [graph]} = Sparse6.read(@fixture)
      assert Yog.Model.node_count(graph) == 5
      assert Yog.Model.edge_count(graph) == 4
    end

    test "roundtrip write and read" do
      original =
        Yog.undirected()
        |> Yog.add_edge_ensure(0, 1, 1)
        |> Yog.add_edge_ensure(1, 2, 1)
        |> Yog.add_edge_ensure(2, 3, 1)
        |> Yog.add_edge_ensure(3, 4, 1)

      assert :ok = Sparse6.write(@tmp_file, original)
      assert File.exists?(@tmp_file)

      {:ok, [reloaded]} = Sparse6.read(@tmp_file)
      assert Yog.Model.node_count(reloaded) == 5
      assert Yog.Model.edge_count(reloaded) == 4

      File.rm(@tmp_file)
    end

    test "write multiple graphs" do
      g1 = Yog.undirected() |> Yog.add_edge_ensure(0, 1, 1)
      g2 = Yog.undirected() |> Yog.add_edge_ensure(0, 1, 1) |> Yog.add_edge_ensure(1, 2, 1)

      assert :ok = Sparse6.write(@tmp_file, [g1, g2])
      {:ok, graphs} = Sparse6.read(@tmp_file)
      assert length(graphs) == 2

      File.rm(@tmp_file)
    end
  end
end
