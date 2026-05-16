defmodule Yog.IO.GEXF.MultiTest do
  use ExUnit.Case

  alias Yog.IO.GEXF.Multi

  doctest Yog.IO.GEXF.Multi

  # =============================================================================
  # SERIALIZATION TESTS
  # =============================================================================

  test "serialize empty multigraph" do
    graph = Yog.Multi.directed()
    xml = Multi.serialize(graph)

    assert String.contains?(xml, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    assert String.contains?(xml, "defaultedgetype=\"directed\"")
    assert String.contains?(xml, "<nodes></nodes>")
    assert String.contains?(xml, "<edges></edges>")
  end

  test "serialize undirected multigraph" do
    graph = Yog.Multi.undirected()
    xml = Multi.serialize(graph)

    assert String.contains?(xml, "defaultedgetype=\"undirected\"")
  end

  test "serialize multigraph with parallel edges" do
    multi =
      Yog.Multi.directed()
      |> Yog.Multi.add_node(1, "A")
      |> Yog.Multi.add_node(2, "B")

    {multi, eid1} = Yog.Multi.add_edge(multi, 1, 2, 5)
    {multi, eid2} = Yog.Multi.add_edge(multi, 1, 2, 10)

    xml = Multi.serialize(multi)

    assert String.contains?(xml, "<node id=\"1\" label=\"A\">")
    assert String.contains?(xml, "<node id=\"2\" label=\"B\">")
    # Both parallel edges should be present
    assert String.contains?(xml, "<edge id=\"#{eid1}\"")
    assert String.contains?(xml, "<edge id=\"#{eid2}\"")
    assert String.contains?(xml, "source=\"1\"")
    assert String.contains?(xml, "target=\"2\"")
  end

  test "serialize_with custom attribute mappers" do
    multi =
      Yog.Multi.directed()
      |> Yog.Multi.add_node(1, %{name: "Alice"})
      |> Yog.Multi.add_node(2, %{name: "Bob"})

    {multi, _} = Yog.Multi.add_edge(multi, 1, 2, %{kind: "friend"})

    node_attr = fn data -> %{"name" => data.name} end
    edge_attr = fn data -> %{"kind" => data.kind} end

    xml = Multi.serialize_with(node_attr, edge_attr, multi)

    assert String.contains?(xml, "<attribute id=\"0\" title=\"name\" type=\"string\"")
    assert String.contains?(xml, "<attribute id=\"0\" title=\"kind\" type=\"string\"")
  end

  test "serialize_with_options uses custom formatters" do
    multi =
      Yog.Multi.directed()
      |> Yog.Multi.add_node(1, "A")
      |> Yog.Multi.add_node(2, "B")

    {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1)

    opts = Multi.options_with(&("n_" <> Integer.to_string(&1)), &("e_" <> Integer.to_string(&1)))
    xml = Multi.serialize_with_options(fn _ -> %{} end, fn _ -> %{} end, opts, multi)

    assert String.contains?(xml, "<node id=\"n_1\"")
    assert String.contains?(xml, "<edge id=\"e_")
  end

  test "default_options returns formatters" do
    {:gexf_options, node_fmt, edge_fmt} = Multi.default_options()
    assert is_function(node_fmt, 1)
    assert is_function(edge_fmt, 1)
  end

  # =============================================================================
  # FILE I/O TESTS
  # =============================================================================

  test "write and read multigraph file" do
    path = "/tmp/test_yog_gexf_multi.gexf"

    multi =
      Yog.Multi.directed()
      |> Yog.Multi.add_node(1, "A")
      |> Yog.Multi.add_node(2, "B")

    {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 5)
    {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 10)

    try do
      assert {:ok, nil} = Multi.write(path, multi)
      assert File.exists?(path)

      {:ok, graph} = Multi.read(path)
      assert Yog.Multi.Model.order(graph) == 2
      assert Map.has_key?(graph.nodes, 1)
      assert Map.has_key?(graph.nodes, 2)
      # Parallel edges preserved in multigraph deserialization
      assert length(Yog.Multi.Model.successors(graph, 1)) == 2
    after
      File.rm(path)
    end
  end

  test "write_with and read_with custom mappers" do
    path = "/tmp/test_yog_gexf_multi_with.gexf"

    multi =
      Yog.Multi.directed()
      |> Yog.Multi.add_node(1, %{name: "Alice"})
      |> Yog.Multi.add_node(2, %{name: "Bob"})

    {multi, _} = Yog.Multi.add_edge(multi, 1, 2, %{kind: "friend"})

    node_attr = fn data -> %{"name" => data.name} end
    edge_attr = fn data -> %{"kind" => data.kind} end

    node_folder = fn attrs -> %{name: Map.get(attrs, "name", "")} end
    edge_folder = fn attrs -> %{kind: Map.get(attrs, "kind", "")} end

    try do
      assert {:ok, nil} = Multi.write_with(path, node_attr, edge_attr, multi)
      {:ok, graph} = Multi.read_with(path, node_folder, edge_folder)

      assert graph.nodes[1].name == "Alice"
      {_eid, _to, edge_data} = Yog.Multi.Model.successors(graph, 1) |> hd()
      assert edge_data.kind == "friend"
    after
      File.rm(path)
    end
  end

  test "read nonexistent file returns error" do
    assert {:error, :enoent} = Multi.read("/tmp/nonexistent_yog_gexf_multi.gexf")
  end
end
