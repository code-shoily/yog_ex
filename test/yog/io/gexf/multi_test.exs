defmodule Yog.IO.GEXF.MultiTest do
  use ExUnit.Case

  alias Yog.IO.GEXF.Multi
  alias Yog.Multi.Model

  doctest Yog.IO.GEXF.Multi

  # =============================================================================
  # SERIALIZATION TESTS
  # =============================================================================

  test "serialize empty directed multigraph" do
    multi = Yog.Multi.new(:directed)
    xml = Multi.serialize(multi)

    assert String.contains?(xml, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    assert String.contains?(xml, "defaultedgetype=\"directed\"")
    assert String.contains?(xml, "<nodes></nodes>")
    assert String.contains?(xml, "<edges></edges>")
  end

  test "serialize empty undirected multigraph" do
    multi = Yog.Multi.new(:undirected)
    xml = Multi.serialize(multi)

    assert String.contains?(xml, "defaultedgetype=\"undirected\"")
  end

  test "serialize single node" do
    multi =
      Yog.Multi.new(:directed)
      |> Yog.Multi.add_node(1, "Alice")

    xml = Multi.serialize(multi)
    assert String.contains?(xml, "<node id=\"1\" label=\"Alice\">")
  end

  test "serialize parallel edges" do
    multi =
      Yog.Multi.new(:directed)
      |> Yog.Multi.add_node(1, "A")
      |> Yog.Multi.add_node(2, "B")
      |> Yog.Multi.add_edge(1, 2, "route-a")
      |> elem(0)
      |> Yog.Multi.add_edge(1, 2, "route-b")
      |> elem(0)

    xml = Multi.serialize(multi)

    edge_count = xml |> String.split("<edge ") |> length() |> Kernel.-(1)
    assert edge_count == 2
    assert String.contains?(xml, "<edge id=\"0\"")
    assert String.contains?(xml, "<edge id=\"1\"")
  end

  test "serialize undirected parallel edges" do
    multi =
      Yog.Multi.new(:undirected)
      |> Yog.Multi.add_node(1, "A")
      |> Yog.Multi.add_node(2, "B")
      |> Yog.Multi.add_edge(1, 2, "edge1")
      |> elem(0)
      |> Yog.Multi.add_edge(1, 2, "edge2")
      |> elem(0)

    xml = Multi.serialize(multi)

    edge_count = xml |> String.split("<edge ") |> length() |> Kernel.-(1)
    assert edge_count == 2
    assert String.contains?(xml, "defaultedgetype=\"undirected\"")
  end

  test "serialize with custom attributes" do
    multi =
      Yog.Multi.new(:directed)
      |> Yog.Multi.add_node(1, "Alice")
      |> Yog.Multi.add_node(2, "Bob")
      |> Yog.Multi.add_edge(1, 2, "friend")
      |> elem(0)

    node_attr = fn name -> %{"name" => name, "role" => "user"} end
    edge_attr = fn rel -> %{"relation" => rel} end

    xml = Multi.serialize_with(node_attr, edge_attr, multi)

    assert String.contains?(xml, "<attribute id=\"0\" title=\"name\"")
    assert String.contains?(xml, "<attribute id=\"1\" title=\"role\"")
    assert String.contains?(xml, "<attvalue for=\"0\" value=\"Alice\"")
    assert String.contains?(xml, "<attvalue for=\"0\" value=\"friend\"")
  end

  test "serialize escapes XML special chars" do
    multi =
      Yog.Multi.new(:directed)
      |> Yog.Multi.add_node(1, "Alice <admin>")

    xml = Multi.serialize(multi)
    assert String.contains?(xml, "&lt;admin&gt;")
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

    {:ok, graph} = Multi.deserialize(xml)
    assert graph.kind == :directed
    assert Model.order(graph) == 0
    assert Model.size(graph) == 0
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

    {:ok, graph} = Multi.deserialize(xml)
    assert Model.order(graph) == 1
    assert graph.nodes[1]["label"] == "Alice"
  end

  test "deserialize parallel edges" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="directed">
        <nodes>
          <node id="1" label="A"/>
          <node id="2" label="B"/>
        </nodes>
        <edges>
          <edge id="0" source="1" target="2" weight="route-a"/>
          <edge id="1" source="1" target="2" weight="route-b"/>
        </edges>
      </graph>
    </gexf>
    """

    {:ok, graph} = Multi.deserialize(xml)
    assert Model.order(graph) == 2
    assert Model.size(graph) == 2

    edge_ids = Model.all_edge_ids(graph)
    assert length(edge_ids) == 2

    # Both edges should be between 1 and 2
    edges = graph.edges
    assert map_size(edges) == 2
    assert Enum.all?(edges, fn {_eid, {from, to, _}} -> from == 1 and to == 2 end)
  end

  test "deserialize undirected parallel edges" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="undirected">
        <nodes>
          <node id="1" label="A"/>
          <node id="2" label="B"/>
        </nodes>
        <edges>
          <edge id="0" source="1" target="2"/>
          <edge id="1" source="1" target="2"/>
        </edges>
      </graph>
    </gexf>
    """

    {:ok, graph} = Multi.deserialize(xml)
    assert graph.kind == :undirected
    assert Model.size(graph) == 2
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
      %{
        name: Map.get(attrs, "name", ""),
        age: Map.get(attrs, "age", "0") |> String.to_integer()
      }
    end

    edge_folder = fn attrs -> Map.get(attrs, "type", "") end

    {:ok, graph} = Multi.deserialize_with(node_folder, edge_folder, xml)

    person = graph.nodes[1]
    assert person.name == "Alice"
    assert person.age == 30
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

    {:ok, graph} = Multi.deserialize(xml)
    assert Model.order(graph) == 2
    assert Model.size(graph) == 1

    edge = graph.edges |> Map.values() |> hd()
    assert elem(edge, 0) == "alice"
    assert elem(edge, 1) == "bob"
  end

  # =============================================================================
  # ROUNDTRIP TESTS
  # =============================================================================

  test "roundtrip directed multigraph with parallel edges" do
    original =
      Yog.Multi.new(:directed)
      |> Yog.Multi.add_node(1, "Alice")
      |> Yog.Multi.add_node(2, "Bob")
      |> Yog.Multi.add_edge(1, 2, "route-a")
      |> elem(0)
      |> Yog.Multi.add_edge(1, 2, "route-b")
      |> elem(0)

    xml = Multi.serialize(original)
    {:ok, loaded} = Multi.deserialize(xml)

    assert Model.order(loaded) == 2
    assert Model.size(loaded) == 2
    assert loaded.nodes[1]["label"] == "Alice"
    assert loaded.nodes[2]["label"] == "Bob"

    # Both edges should exist between 1 and 2
    edges_1_2 =
      loaded.edges
      |> Map.values()
      |> Enum.filter(fn {from, to, _} -> from == 1 and to == 2 end)

    assert length(edges_1_2) == 2
  end

  test "roundtrip undirected multigraph" do
    original =
      Yog.Multi.new(:undirected)
      |> Yog.Multi.add_node(1, "A")
      |> Yog.Multi.add_node(2, "B")
      |> Yog.Multi.add_node(3, "C")
      |> Yog.Multi.add_edge(1, 2, "e1")
      |> elem(0)
      |> Yog.Multi.add_edge(2, 3, "e2")
      |> elem(0)
      |> Yog.Multi.add_edge(1, 2, "e3")
      |> elem(0)

    xml = Multi.serialize(original)
    {:ok, loaded} = Multi.deserialize(xml)

    assert loaded.kind == :undirected
    assert Model.order(loaded) == 3
    assert Model.size(loaded) == 3
  end

  test "roundtrip with custom attributes" do
    original =
      Yog.Multi.new(:directed)
      |> Yog.Multi.add_node(1, %{name: "Alice", age: 30})
      |> Yog.Multi.add_node(2, %{name: "Bob", age: 25})
      |> Yog.Multi.add_edge(1, 2, %{type: "friend", since: "2020"})
      |> elem(0)
      |> Yog.Multi.add_edge(1, 2, %{type: "colleague", since: "2019"})
      |> elem(0)

    node_attr = fn data ->
      %{"name" => data.name, "age" => Integer.to_string(data.age)}
    end

    edge_attr = fn data ->
      %{"type" => data.type, "since" => data.since}
    end

    xml = Multi.serialize_with(node_attr, edge_attr, original)

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

    {:ok, loaded} = Multi.deserialize_with(node_folder, edge_folder, xml)

    assert Model.order(loaded) == 2
    assert Model.size(loaded) == 2
    assert loaded.nodes[1].name == "Alice"
    assert loaded.nodes[1].age == 30

    edge_values =
      loaded.edges
      |> Map.values()
      |> Enum.map(fn {_from, _to, data} -> data.type end)
      |> Enum.sort()

    assert edge_values == ["colleague", "friend"]
  end

  # =============================================================================
  # FILE I/O TESTS
  # =============================================================================

  test "write and read multigraph file" do
    path = "/tmp/test_yog_gexf_multi.gexf"

    original =
      Yog.Multi.new(:directed)
      |> Yog.Multi.add_node(1, "Alice")
      |> Yog.Multi.add_node(2, "Bob")
      |> Yog.Multi.add_edge(1, 2, "e1")
      |> elem(0)
      |> Yog.Multi.add_edge(1, 2, "e2")
      |> elem(0)

    try do
      assert {:ok, nil} = Multi.write(path, original)
      assert File.exists?(path)

      {:ok, loaded} = Multi.read(path)

      assert Model.order(loaded) == 2
      assert Model.size(loaded) == 2
    after
      File.rm(path)
    end
  end

  test "read nonexistent file" do
    assert {:error, _} = Multi.read("/tmp/nonexistent_multi_xyz.gexf")
  end
end
