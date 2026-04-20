defmodule Yog.IO.GEXFTest do
  use ExUnit.Case

  alias Yog.IO.GEXF

  doctest Yog.IO.GEXF

  # =============================================================================
  # SERIALIZATION TESTS
  # =============================================================================

  test "serialize empty directed graph" do
    graph = Yog.directed()
    xml = GEXF.serialize(graph)

    assert String.contains?(xml, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    assert String.contains?(xml, "<gexf xmlns=\"http://gexf.net/1.3\"")
    assert String.contains?(xml, "defaultedgetype=\"directed\"")
    assert String.contains?(xml, "</gexf>")
  end

  test "serialize empty undirected graph" do
    graph = Yog.undirected()
    xml = GEXF.serialize(graph)

    assert String.contains?(xml, "defaultedgetype=\"undirected\"")
  end

  test "serialize single node" do
    graph = Yog.directed() |> Yog.add_node(1, "Alice")
    xml = GEXF.serialize(graph)

    assert String.contains?(xml, "<node id=\"1\" label=\"Alice\">")
    assert String.contains?(xml, "</node>")
  end

  test "serialize multiple nodes" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_node(3, "Charlie")

    xml = GEXF.serialize(graph)

    assert String.contains?(xml, "<node id=\"1\"")
    assert String.contains?(xml, "<node id=\"2\"")
    assert String.contains?(xml, "<node id=\"3\"")
  end

  test "serialize simple edge" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")

    xml = GEXF.serialize(graph)

    assert String.contains?(xml, "<edge")
    assert String.contains?(xml, "source=\"1\"")
    assert String.contains?(xml, "target=\"2\"")
    assert String.contains?(xml, "weight=\"5\"")
  end

  test "serialize undirected edge" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "10")

    xml = GEXF.serialize(graph)

    edge_count = xml |> String.split("<edge ") |> length() |> Kernel.-(1)
    assert edge_count == 1
    assert String.contains?(xml, "defaultedgetype=\"undirected\"")
  end

  test "serialize with custom attributes" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "friend")

    node_attr = fn name -> %{"name" => name, "role" => "user"} end
    edge_attr = fn rel -> %{"relation" => rel, "strength" => "strong"} end

    xml = GEXF.serialize_with(node_attr, edge_attr, graph)

    assert String.contains?(xml, "<attribute id=\"0\" title=\"name\"")
    assert String.contains?(xml, "<attribute id=\"1\" title=\"role\"")
    assert String.contains?(xml, "<attribute id=\"0\" title=\"relation\"")
    assert String.contains?(xml, "<attribute id=\"1\" title=\"strength\"")
    assert String.contains?(xml, "<attvalue for=\"0\" value=\"Alice\"")
    assert String.contains?(xml, "<attvalue for=\"1\" value=\"user\"")
    assert String.contains?(xml, "<attvalue for=\"0\" value=\"friend\"")
    assert String.contains?(xml, "<attvalue for=\"1\" value=\"strong\"")
  end

  test "serialize escapes XML special chars" do
    graph = Yog.directed() |> Yog.add_node(1, "Alice <admin>")
    xml = GEXF.serialize(graph)

    assert String.contains?(xml, "&lt;admin&gt;")
    refute String.contains?(xml, "<admin>")
  end

  test "serialize graph with empty map node data" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, %{})
      |> Yog.add_node(2, %{})
      |> Yog.add_edge_ensure(from: 1, to: 2, with: %{})

    xml = GEXF.serialize(graph)

    assert String.contains?(xml, "<node id=\"1\"")
    assert String.contains?(xml, "<node id=\"2\"")
    assert String.contains?(xml, "<edge")
  end

  test "serialize graph with nil node data" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)

    xml = GEXF.serialize(graph)

    assert String.contains?(xml, "<node id=\"1\"")
    assert String.contains?(xml, "<node id=\"2\"")
  end

  # =============================================================================
  # DESERIALIZATION TESTS
  # =============================================================================

  test "deserialize empty graph" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="directed">
        <nodes></nodes>
        <edges></edges>
      </graph>
    </gexf>
    """

    {:ok, graph} = GEXF.deserialize(xml)
    assert Yog.Model.type(graph) == :directed
    assert Yog.Model.node_count(graph) == 0
  end

  test "deserialize single node" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="directed">
        <nodes>
          <node id="1" label="Alice"/>
        </nodes>
        <edges></edges>
      </graph>
    </gexf>
    """

    {:ok, graph} = GEXF.deserialize(xml)
    assert Yog.Model.node_count(graph) == 1
    node_data = Yog.Model.node(graph, 1)
    assert node_data["label"] == "Alice"
  end

  test "deserialize multiple nodes" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="directed">
        <nodes>
          <node id="1" label="Alice"/>
          <node id="2" label="Bob"/>
          <node id="3" label="Charlie"/>
        </nodes>
        <edges></edges>
      </graph>
    </gexf>
    """

    {:ok, graph} = GEXF.deserialize(xml)
    assert Yog.Model.node_count(graph) == 3
    assert Yog.Model.node(graph, 1)["label"] == "Alice"
    assert Yog.Model.node(graph, 2)["label"] == "Bob"
    assert Yog.Model.node(graph, 3)["label"] == "Charlie"
  end

  test "deserialize simple edge" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="directed">
        <nodes>
          <node id="1" label="A"/>
          <node id="2" label="B"/>
        </nodes>
        <edges>
          <edge source="1" target="2" weight="10"/>
        </edges>
      </graph>
    </gexf>
    """

    {:ok, graph} = GEXF.deserialize(xml)
    successors = Yog.successors(graph, 1)
    assert length(successors) == 1

    {dst, edge_data} = hd(successors)
    assert dst == 2
    assert edge_data["weight"] == "10"
  end

  test "deserialize undirected graph" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="undirected">
        <nodes>
          <node id="1" label="A"/>
          <node id="2" label="B"/>
        </nodes>
        <edges>
          <edge source="1" target="2"/>
        </edges>
      </graph>
    </gexf>
    """

    {:ok, graph} = GEXF.deserialize(xml)
    assert Yog.Model.type(graph) == :undirected
    assert length(Yog.successors(graph, 1)) == 1
    assert length(Yog.successors(graph, 2)) == 1
  end

  test "deserialize with custom mappers" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="directed">
        <attributes class="node">
          <attribute id="0" title="name" type="string"/>
          <attribute id="1" title="age" type="string"/>
        </attributes>
        <nodes>
          <node id="1">
            <attvalues>
              <attvalue for="0" value="Alice"/>
              <attvalue for="1" value="30"/>
            </attvalues>
          </node>
          <node id="2">
            <attvalues>
              <attvalue for="0" value="Bob"/>
              <attvalue for="1" value="25"/>
            </attvalues>
          </node>
        </nodes>
        <edges>
          <edge source="1" target="2">
            <attvalues>
              <attvalue for="0" value="friend"/>
            </attvalues>
          </edge>
        </edges>
      </graph>
    </gexf>
    """

    node_folder = fn attrs ->
      name = Map.get(attrs, "name", "")
      age = Map.get(attrs, "age", "0") |> String.to_integer()
      %{name: name, age: age}
    end

    edge_folder = fn attrs -> Map.get(attrs, "type", "") end

    {:ok, graph} = GEXF.deserialize_with(node_folder, edge_folder, xml)

    person1 = Yog.Model.node(graph, 1)
    assert person1.name == "Alice"
    assert person1.age == 30

    person2 = Yog.Model.node(graph, 2)
    assert person2.name == "Bob"
    assert person2.age == 25

    assert length(Yog.successors(graph, 1)) == 1
  end

  test "deserialize multiple edges" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="directed">
        <nodes>
          <node id="1" label="A"/>
          <node id="2" label="B"/>
          <node id="3" label="C"/>
        </nodes>
        <edges>
          <edge source="1" target="2" weight="10"/>
          <edge source="2" target="3" weight="20"/>
          <edge source="1" target="3" weight="30"/>
        </edges>
      </graph>
    </gexf>
    """

    {:ok, graph} = GEXF.deserialize(xml)
    assert length(Yog.successors(graph, 1)) == 2
    assert length(Yog.successors(graph, 2)) == 1
    assert Yog.successors(graph, 3) == []
  end

  test "deserialize handles string node ids" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="directed">
        <nodes>
          <node id="alice" label="Alice"/>
          <node id="bob" label="Bob"/>
        </nodes>
        <edges>
          <edge source="alice" target="bob"/>
        </edges>
      </graph>
    </gexf>
    """

    {:ok, graph} = GEXF.deserialize(xml)
    assert Yog.Model.node_count(graph) == 2
    assert Yog.has_edge?(graph, "alice", "bob")
  end

  test "deserialize missing graph type defaults to directed" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph>
        <nodes><node id="1"/></nodes>
        <edges></edges>
      </graph>
    </gexf>
    """

    {:ok, graph} = GEXF.deserialize(xml)
    assert Yog.Model.type(graph) == :directed
  end

  # =============================================================================
  # ROUNDTRIP TESTS
  # =============================================================================

  test "roundtrip simple graph" do
    original =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "friend")

    xml = GEXF.serialize(original)
    {:ok, loaded} = GEXF.deserialize(xml)

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

    xml = GEXF.serialize(original)
    {:ok, loaded} = GEXF.deserialize(xml)

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

    xml = GEXF.serialize(original)
    {:ok, loaded} = GEXF.deserialize(xml)

    assert Yog.Model.node_count(loaded) == 4
    assert length(Yog.successors(loaded, 1)) == 2
    assert length(Yog.predecessors(loaded, 4)) == 2
  end

  test "roundtrip with custom attributes" do
    original =
      Yog.directed()
      |> Yog.add_node(1, %{name: "Alice", age: 30})
      |> Yog.add_node(2, %{name: "Bob", age: 25})
      |> Yog.add_edge_ensure(from: 1, to: 2, with: %{type: "friend", since: "2020"})

    node_attr = fn data ->
      %{
        "name" => data.name,
        "age" => Integer.to_string(data.age)
      }
    end

    edge_attr = fn data ->
      %{
        "type" => data.type,
        "since" => data.since
      }
    end

    xml = GEXF.serialize_with(node_attr, edge_attr, original)

    node_folder = fn attrs ->
      %{
        name: Map.get(attrs, "name", ""),
        age: String.to_integer(Map.get(attrs, "age", "0"))
      }
    end

    edge_folder = fn attrs ->
      %{
        type: Map.get(attrs, "type", ""),
        since: Map.get(attrs, "since", "")
      }
    end

    {:ok, loaded} = GEXF.deserialize_with(node_folder, edge_folder, xml)

    assert Yog.Model.node_count(loaded) == 2
    assert Yog.Model.node(loaded, 1).name == "Alice"
    assert Yog.Model.node(loaded, 1).age == 30
    assert Yog.Model.node(loaded, 2).name == "Bob"

    {_, edge_data} = Yog.successors(loaded, 1) |> hd()
    assert edge_data.type == "friend"
    assert edge_data.since == "2020"
  end

  # =============================================================================
  # FILE I/O TESTS
  # =============================================================================

  test "write and read gexf file" do
    path = "/tmp/test_yog_io_gexf.gexf"

    original =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge_ensure(from: 1, to: 2, with: "5")

    try do
      assert {:ok, nil} = GEXF.write(path, original)
      assert File.exists?(path)

      {:ok, loaded} = GEXF.read(path)

      assert Yog.Model.node_count(loaded) == 2
      assert Yog.Model.node(loaded, 1)["label"] == "Alice"
    after
      File.rm(path)
    end
  end

  test "read nonexistent file" do
    assert {:error, _} = GEXF.read("/tmp/nonexistent_file_xyz_123.gexf")
  end

  # =============================================================================
  # FIXTURE FILE TESTS
  # =============================================================================

  test "read sample fixture file" do
    fixture_path = "test/fixtures/io/sample.gexf"
    assert File.exists?(fixture_path), "Fixture file does not exist"

    {:ok, graph} = GEXF.read(fixture_path)

    assert Yog.Model.node_count(graph) == 3
    assert Yog.Model.edge_count(graph) == 3
    assert Yog.Model.type(graph) == :directed

    assert Yog.Model.node(graph, 1)["label"] == "Alice"
    assert Yog.Model.node(graph, 2)["label"] == "Bob"
    assert Yog.Model.node(graph, 3)["label"] == "Charlie"

    assert length(Yog.successors(graph, 1)) == 2
    assert length(Yog.successors(graph, 2)) == 1
  end

  test "roundtrip fixture file" do
    fixture_path = "test/fixtures/io/sample.gexf"
    output_path = "/tmp/test_yog_gexf_output.gexf"

    {:ok, original} = GEXF.read(fixture_path)

    node_attr = fn data when is_map(data) -> data end
    edge_attr = fn data when is_map(data) -> data end

    try do
      assert {:ok, nil} = GEXF.write_with(output_path, node_attr, edge_attr, original)
      assert File.exists?(output_path)

      {:ok, reloaded} = GEXF.read(output_path)

      assert Yog.Model.node_count(reloaded) == Yog.Model.node_count(original)
      assert Yog.Model.edge_count(reloaded) == Yog.Model.edge_count(original)
      assert Yog.Model.type(reloaded) == Yog.Model.type(original)

      assert Yog.Model.node(reloaded, 1)["label"] == "Alice"
      assert Yog.Model.node(reloaded, 2)["label"] == "Bob"
      assert Yog.Model.node(reloaded, 3)["label"] == "Charlie"
    after
      File.rm(output_path)
    end
  end

  test "deserialize invalid xml returns error" do
    assert {:error, _} = GEXF.deserialize("not xml at all")
    assert {:error, _} = GEXF.deserialize("<?xml version=\"1.0\"?><invalid>")
  end

  test "deserialize duplicate edges keeps only one" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="directed">
        <nodes>
          <node id="1" label="A"/>
          <node id="2" label="B"/>
        </nodes>
        <edges>
          <edge source="1" target="2" weight="first"/>
          <edge source="1" target="2" weight="second"/>
        </edges>
      </graph>
    </gexf>
    """

    {:ok, graph} = GEXF.deserialize(xml)
    assert length(Yog.successors(graph, 1)) == 1
  end

  test "write_with and read_with file" do
    path = "/tmp/test_yog_gexf_write_with.gexf"

    original =
      Yog.directed()
      |> Yog.add_node(1, %{name: "Alice", age: 30})
      |> Yog.add_node(2, %{name: "Bob", age: 25})
      |> Yog.add_edge_ensure(from: 1, to: 2, with: %{type: "friend", since: "2020"})

    node_attr = fn data ->
      %{"name" => data.name, "age" => Integer.to_string(data.age)}
    end

    edge_attr = fn data ->
      %{"type" => data.type, "since" => data.since}
    end

    node_folder = fn attrs ->
      %{
        name: Map.get(attrs, "name", ""),
        age: String.to_integer(Map.get(attrs, "age", "0"))
      }
    end

    edge_folder = fn attrs ->
      %{
        type: Map.get(attrs, "type", ""),
        since: Map.get(attrs, "since", "")
      }
    end

    try do
      assert {:ok, nil} = GEXF.write_with(path, node_attr, edge_attr, original)
      assert File.exists?(path)

      {:ok, loaded} = GEXF.read_with(path, node_folder, edge_folder)

      assert Yog.Model.node(loaded, 1).name == "Alice"
      assert Yog.Model.node(loaded, 1).age == 30

      {_, edge_data} = Yog.successors(loaded, 1) |> hd()
      assert edge_data.type == "friend"
      assert edge_data.since == "2020"
    after
      File.rm(path)
    end
  end
end
