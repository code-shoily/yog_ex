defmodule Yog.IO.GraphMLTest do
  use ExUnit.Case

  alias Yog.IO.GraphML

  doctest Yog.IO.GraphML

  # =============================================================================
  # SERIALIZATION TESTS
  # =============================================================================

  test "serialize empty directed graph" do
    graph = Yog.directed()
    xml = GraphML.serialize(graph)

    assert String.contains?(xml, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    assert String.contains?(xml, "<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\"")
    assert String.contains?(xml, "edgedefault=\"directed\"")
    assert String.contains?(xml, "</graphml>")
  end

  test "serialize empty undirected graph" do
    graph = Yog.undirected()
    xml = GraphML.serialize(graph)

    assert String.contains?(xml, "edgedefault=\"undirected\"")
  end

  test "serialize single node" do
    graph = Yog.directed() |> Yog.add_node(1, "Alice")
    xml = GraphML.serialize(graph)

    assert String.contains?(xml, "<node id=\"1\">")
    assert String.contains?(xml, "<data key=\"label\">Alice</data>")
    assert String.contains?(xml, "</node>")
    assert String.contains?(xml, "<key id=\"label\" for=\"node\"")
  end

  test "serialize multiple nodes" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_node(3, "Charlie")

    xml = GraphML.serialize(graph)

    assert String.contains?(xml, "<node id=\"1\">")
    assert String.contains?(xml, "<node id=\"2\">")
    assert String.contains?(xml, "<node id=\"3\">")
  end

  test "serialize simple edge" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "5")

    xml = GraphML.serialize(graph)

    assert String.contains?(xml, "<edge source=\"1\" target=\"2\">")
    assert String.contains?(xml, "<data key=\"weight\">5</data>")
    assert String.contains?(xml, "<key id=\"weight\" for=\"edge\"")
  end

  test "serialize multiple edges" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edges!([{1, 2, "10"}, {2, 3, "20"}, {1, 3, "30"}])

    xml = GraphML.serialize(graph)

    assert String.contains?(xml, "<edge source=\"1\" target=\"2\">")
    assert String.contains?(xml, "<edge source=\"2\" target=\"3\">")
    assert String.contains?(xml, "<edge source=\"1\" target=\"3\">")
  end

  test "serialize undirected edge" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: "10")

    xml = GraphML.serialize(graph)

    # For undirected graphs, we should only have one edge
    edge_count = xml |> String.split("<edge ") |> length() |> Kernel.-(1)
    assert edge_count == 1
  end

  test "serialize with custom attributes" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "friend")

    node_attr = fn name -> %{"name" => name, "type" => "person"} end
    edge_attr = fn rel -> %{"relation" => rel, "strength" => "strong"} end

    xml = GraphML.serialize_with(node_attr, edge_attr, graph)

    assert String.contains?(xml, "<key id=\"name\" for=\"node\"")
    assert String.contains?(xml, "<key id=\"type\" for=\"node\"")
    assert String.contains?(xml, "<key id=\"relation\" for=\"edge\"")
    assert String.contains?(xml, "<key id=\"strength\" for=\"edge\"")
    assert String.contains?(xml, "<data key=\"name\">Alice</data>")
    assert String.contains?(xml, "<data key=\"type\">person</data>")
    assert String.contains?(xml, "<data key=\"relation\">friend</data>")
    assert String.contains?(xml, "<data key=\"strength\">strong</data>")
  end

  test "serialize escapes XML special chars" do
    graph = Yog.directed() |> Yog.add_node(1, "Alice <admin>")
    xml = GraphML.serialize(graph)

    assert String.contains?(xml, "&lt;admin&gt;")
    refute String.contains?(xml, "<admin>")
  end

  test "serialize with options" do
    graph = Yog.directed() |> Yog.add_node(1, "Alice")

    # The Gleam type GraphMLOptions has fields `indent` and `xml_declaration`
    # Default options returns the structure we can update
    options = GraphML.default_options() |> put_elem(1, 0) |> put_elem(2, false)

    node_attr = fn name -> %{"label" => name} end
    edge_attr = fn _ -> %{} end

    xml = GraphML.serialize_with_options(node_attr, edge_attr, options, graph)

    refute String.contains?(xml, "<?xml")
  end

  # =============================================================================
  # DESERIALIZATION TESTS
  # =============================================================================

  test "deserialize empty graph" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="directed">
      </graph>
    </graphml>
    """

    {:ok, graph} = GraphML.deserialize(xml)

    assert Yog.Model.type(graph) == :directed
    assert Yog.Model.node_count(graph) == 0
  end

  test "deserialize single node" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <key id="label" for="node" attr.name="label" attr.type="string"/>
      <graph id="G" edgedefault="directed">
        <node id="1">
          <data key="label">Alice</data>
        </node>
      </graph>
    </graphml>
    """

    {:ok, graph} = GraphML.deserialize(xml)

    assert Yog.Model.node_count(graph) == 1

    node_data = Yog.Model.node(graph, 1)
    assert node_data["label"] == "Alice"
  end

  test "deserialize multiple nodes" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <key id="label" for="node" attr.name="label" attr.type="string"/>
      <graph id="G" edgedefault="directed">
        <node id="1"><data key="label">Alice</data></node>
        <node id="2"><data key="label">Bob</data></node>
        <node id="3"><data key="label">Charlie</data></node>
      </graph>
    </graphml>
    """

    {:ok, graph} = GraphML.deserialize(xml)

    assert Yog.Model.node_count(graph) == 3
    assert Yog.Model.node(graph, 1)["label"] == "Alice"
    assert Yog.Model.node(graph, 2)["label"] == "Bob"
    assert Yog.Model.node(graph, 3)["label"] == "Charlie"
  end

  test "deserialize simple edge" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <key id="label" for="node" attr.name="label" attr.type="string"/>
      <key id="weight" for="edge" attr.name="weight" attr.type="string"/>
      <graph id="G" edgedefault="directed">
        <node id="1"><data key="label">A</data></node>
        <node id="2"><data key="label">B</data></node>
        <edge source="1" target="2">
          <data key="weight">10</data>
        </edge>
      </graph>
    </graphml>
    """

    {:ok, graph} = GraphML.deserialize(xml)

    successors = Yog.successors(graph, 1)
    assert length(successors) == 1

    {dst, edge_data} = hd(successors)
    assert dst == 2
    assert edge_data["weight"] == "10"
  end

  test "deserialize undirected graph" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <key id="label" for="node" attr.name="label" attr.type="string"/>
      <graph id="G" edgedefault="undirected">
        <node id="1"><data key="label">A</data></node>
        <node id="2"><data key="label">B</data></node>
        <edge source="1" target="2"/>
      </graph>
    </graphml>
    """

    {:ok, graph} = GraphML.deserialize(xml)

    assert Yog.Model.type(graph) == :undirected

    # In undirected graphs, both directions should exist
    assert length(Yog.successors(graph, 1)) == 1
    assert length(Yog.successors(graph, 2)) == 1
  end

  test "deserialize with custom mappers" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <key id="name" for="node" attr.name="name" attr.type="string"/>
      <key id="age" for="node" attr.name="age" attr.type="string"/>
      <key id="relation" for="edge" attr.name="relation" attr.type="string"/>
      <graph id="G" edgedefault="directed">
        <node id="1">
          <data key="name">Alice</data>
          <data key="age">30</data>
        </node>
        <node id="2">
          <data key="name">Bob</data>
          <data key="age">25</data>
        </node>
        <edge source="1" target="2">
          <data key="relation">friend</data>
        </edge>
      </graph>
    </graphml>
    """

    node_folder = fn attrs ->
      name = Map.get(attrs, "name", "")
      age = Map.get(attrs, "age", "0") |> String.to_integer()
      %{name: name, age: age}
    end

    edge_folder = fn attrs -> Map.get(attrs, "relation", "") end

    {:ok, graph} = GraphML.deserialize_with(node_folder, edge_folder, xml)

    person1 = Yog.Model.node(graph, 1)
    assert person1.name == "Alice"
    assert person1.age == 30

    person2 = Yog.Model.node(graph, 2)
    assert person2.name == "Bob"
    assert person2.age == 25

    {_, edge_data} = Yog.successors(graph, 1) |> hd()
    assert edge_data == "friend"
  end

  test "deserialize multiple edges" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <key id="label" for="node" attr.name="label" attr.type="string"/>
      <key id="weight" for="edge" attr.name="weight" attr.type="string"/>
      <graph id="G" edgedefault="directed">
        <node id="1"><data key="label">A</data></node>
        <node id="2"><data key="label">B</data></node>
        <node id="3"><data key="label">C</data></node>
        <edge source="1" target="2"><data key="weight">10</data></edge>
        <edge source="2" target="3"><data key="weight">20</data></edge>
        <edge source="1" target="3"><data key="weight">30</data></edge>
      </graph>
    </graphml>
    """

    {:ok, graph} = GraphML.deserialize(xml)

    assert length(Yog.successors(graph, 1)) == 2
    assert length(Yog.successors(graph, 2)) == 1
    assert length(Yog.successors(graph, 3)) == 0
  end

  # =============================================================================
  # ROUNDTRIP TESTS
  # =============================================================================

  test "roundtrip simple graph" do
    original =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "friend")

    xml = GraphML.serialize(original)
    {:ok, loaded} = GraphML.deserialize(xml)

    assert Yog.Model.node_count(loaded) == 2
    assert Yog.Model.node(loaded, 1)["label"] == "Alice"

    succ = Yog.successors(loaded, 1)
    assert length(succ) == 1

    {dst, edge_data} = hd(succ)
    assert dst == 2
    assert edge_data["weight"] == "friend"
  end

  test "roundtrip undirected graph" do
    original =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edges!([{1, 2, "10"}, {2, 3, "20"}])

    xml = GraphML.serialize(original)
    {:ok, loaded} = GraphML.deserialize(xml)

    assert Yog.Model.type(loaded) == :undirected

    assert length(Yog.successors(loaded, 1)) == 1
    assert length(Yog.successors(loaded, 2)) == 2
  end

  test "roundtrip complex graph" do
    original =
      Yog.directed()
      |> Yog.add_node(1, "Node1")
      |> Yog.add_node(2, "Node2")
      |> Yog.add_node(3, "Node3")
      |> Yog.add_node(4, "Node4")
      |> Yog.add_edges!([
        {1, 2, "a"},
        {1, 3, "b"},
        {2, 4, "c"},
        {3, 4, "d"}
      ])

    xml = GraphML.serialize(original)
    {:ok, loaded} = GraphML.deserialize(xml)

    assert Yog.Model.node_count(loaded) == 4
    assert length(Yog.successors(loaded, 1)) == 2
    assert length(Yog.predecessors(loaded, 4)) == 2
  end

  # =============================================================================
  # FILE I/O TESTS
  # =============================================================================

  test "write and read graphml file" do
    path = "/tmp/test_yog_io_graphml.graphml"

    original =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "5")

    assert {:ok, nil} = GraphML.write(path, original)

    assert {:ok, loaded} = GraphML.read(path)

    assert Yog.Model.node_count(loaded) == 2
    assert Yog.Model.node(loaded, 1)["label"] == "Alice"

    File.rm(path)
  end

  test "read nonexistent file" do
    assert {:error, _} = GraphML.read("/tmp/nonexistent_file_xyz.graphml")
  end
end
