defmodule Yog.IO.GDFTest do
  use ExUnit.Case

  alias Yog.IO.GDF

  doctest Yog.IO.GDF

  # =============================================================================
  # SERIALIZATION TESTS
  # =============================================================================

  test "serialize empty directed graph" do
    graph = Yog.directed()
    gdf_str = GDF.serialize(graph)

    assert String.contains?(gdf_str, "nodedef>name VARCHAR")
    assert String.contains?(gdf_str, "edgedef>node1 VARCHAR")
    assert String.contains?(gdf_str, "directed BOOLEAN")
  end

  test "serialize empty undirected graph" do
    graph = Yog.undirected()
    gdf_str = GDF.serialize(graph)

    # Undirected graphs should still have directed column but all values false
    assert String.contains?(gdf_str, "directed BOOLEAN")
  end

  test "serialize single node" do
    graph = Yog.directed() |> Yog.add_node(1, "Alice")
    gdf_str = GDF.serialize(graph)

    assert String.contains?(gdf_str, "1,Alice")
    assert String.contains?(gdf_str, "label VARCHAR")
  end

  test "serialize multiple nodes" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_node(3, "Charlie")

    gdf_str = GDF.serialize(graph)

    assert String.contains?(gdf_str, "1,Alice")
    assert String.contains?(gdf_str, "2,Bob")
    assert String.contains?(gdf_str, "3,Charlie")
  end

  test "serialize simple edge" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "5")

    gdf_str = GDF.serialize(graph)

    assert String.contains?(gdf_str, "edgedef>")
    assert String.contains?(gdf_str, "1,2,true,5")
    assert String.contains?(gdf_str, "label VARCHAR")
  end

  test "serialize multiple edges" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edges!([{1, 2, "10"}, {2, 3, "20"}, {1, 3, "30"}])

    gdf_str = GDF.serialize(graph)

    assert String.contains?(gdf_str, "1,2,true,10")
    assert String.contains?(gdf_str, "2,3,true,20")
    assert String.contains?(gdf_str, "1,3,true,30")
  end

  test "serialize undirected edge" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: "10")

    gdf_str = GDF.serialize(graph)

    # For undirected graphs, we should only have one edge
    edge_lines =
      gdf_str
      |> String.split("\n")
      |> Enum.filter(fn line ->
        String.starts_with?(line, "1,2,") or String.starts_with?(line, "2,1,")
      end)

    assert length(edge_lines) == 1
    assert String.contains?(gdf_str, "false")
  end

  test "serialize weighted graph" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: 42)

    gdf_str = GDF.serialize_weighted(graph)

    assert String.contains?(gdf_str, "weight VARCHAR")
    assert String.contains?(gdf_str, "1,2,true,42")
  end

  test "serialize with custom attributes" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "friend")

    node_attr = fn name -> %{"name" => name, "role" => "user"} end
    edge_attr = fn rel -> %{"relation" => rel, "weight" => "strong"} end

    gdf_str = GDF.serialize_with(node_attr, edge_attr, GDF.default_options(), graph)

    assert String.contains?(gdf_str, "nodedef>name VARCHAR,name VARCHAR,role VARCHAR")
    assert String.contains?(gdf_str, "1,Alice,user")
    assert String.contains?(gdf_str, "2,Bob,user")
    assert String.contains?(gdf_str, "edgedef>")
    assert String.contains?(gdf_str, "relation")
    assert String.contains?(gdf_str, "weight")
  end

  test "serialize without types" do
    graph = Yog.directed() |> Yog.add_node(1, "Alice")

    # Access GdfOptions tuple to disable includes_types:
    # {GdfOptions(separator, include_types, include_directed)}
    options = {:gdf_options, ",", false, :none}
    node_attr = fn name -> %{"label" => name} end
    edge_attr = fn _ -> %{} end

    gdf_str = GDF.serialize_with(node_attr, edge_attr, options, graph)

    assert String.contains?(gdf_str, "nodedef>name,label")
    refute String.contains?(gdf_str, "VARCHAR")
  end

  test "serialize with custom separator" do
    graph = Yog.directed() |> Yog.add_node(1, "Alice")

    options = {:gdf_options, ";", true, :none}
    node_attr = fn name -> %{"label" => name} end
    edge_attr = fn _ -> %{} end

    gdf_str = GDF.serialize_with(node_attr, edge_attr, options, graph)

    assert String.contains?(gdf_str, "nodedef>name VARCHAR;label VARCHAR")
    assert String.contains?(gdf_str, "1;Alice")
  end

  test "serialize escapes special chars" do
    graph = Yog.directed() |> Yog.add_node(1, "Alice, Admin")
    gdf_str = GDF.serialize(graph)

    assert String.contains?(gdf_str, "\"Alice, Admin\"")
  end

  test "serialize escapes quotes" do
    graph = Yog.directed() |> Yog.add_node(1, "Alice \"The Admin\"")
    gdf_str = GDF.serialize(graph)

    assert String.contains?(gdf_str, "\"Alice \"\"The Admin\"\"\"")
  end

  # =============================================================================
  # DESERIALIZATION TESTS
  # =============================================================================

  test "deserialize empty graph" do
    gdf_str = """
    nodedef>name VARCHAR,label VARCHAR
    edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
    """

    {:ok, graph} = GDF.deserialize(gdf_str)
    assert Yog.all_nodes(graph) == []
  end

  test "deserialize single node" do
    gdf_str = """
    nodedef>name VARCHAR,label VARCHAR
    1,Alice
    edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
    """

    {:ok, graph} = GDF.deserialize(gdf_str)
    assert length(Yog.all_nodes(graph)) == 1

    node_data = Yog.Model.node(graph, 1)
    assert node_data["label"] == "Alice"
  end

  test "deserialize multiple nodes" do
    gdf_str = """
    nodedef>name VARCHAR,label VARCHAR
    1,Alice
    2,Bob
    3,Charlie
    edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
    """

    {:ok, graph} = GDF.deserialize(gdf_str)
    assert length(Yog.all_nodes(graph)) == 3

    assert Yog.Model.node(graph, 1)["label"] == "Alice"
    assert Yog.Model.node(graph, 2)["label"] == "Bob"
    assert Yog.Model.node(graph, 3)["label"] == "Charlie"
  end

  test "deserialize simple edge" do
    gdf_str = """
    nodedef>name VARCHAR,label VARCHAR
    1,Alice
    2,Bob
    edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,weight VARCHAR
    1,2,true,10
    """

    {:ok, graph} = GDF.deserialize(gdf_str)

    successors = Yog.successors(graph, 1)
    assert length(successors) == 1

    {dst, edge_data} = hd(successors)
    assert dst == 2
    assert edge_data["weight"] == "10"
  end

  test "deserialize undirected graph" do
    gdf_str = """
    nodedef>name VARCHAR,label VARCHAR
    1,A
    2,B
    edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
    1,2,false,edge
    """

    {:ok, graph} = GDF.deserialize(gdf_str)

    # Both directions should exist
    assert length(Yog.successors(graph, 1)) == 1
    assert length(Yog.successors(graph, 2)) == 1
  end

  test "deserialize directed graph" do
    gdf_str = """
    nodedef>name VARCHAR,label VARCHAR
    1,A
    2,B
    edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
    1,2,true,edge
    """

    {:ok, graph} = GDF.deserialize(gdf_str)

    assert Yog.Model.type(graph) == :directed

    assert length(Yog.successors(graph, 1)) == 1
    assert Yog.successors(graph, 2) == []
  end

  test "deserialize multiple edges" do
    gdf_str = """
    nodedef>name VARCHAR,label VARCHAR
    1,A
    2,B
    3,C
    edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,weight VARCHAR
    1,2,true,10
    2,3,true,20
    1,3,true,30
    """

    {:ok, graph} = GDF.deserialize(gdf_str)

    assert length(Yog.successors(graph, 1)) == 2
    assert length(Yog.successors(graph, 2)) == 1
    assert Yog.successors(graph, 3) == []
  end

  test "deserialize without types" do
    gdf_str = """
    nodedef>name,label
    1,Alice
    2,Bob
    edgedef>node1,node2,directed,relation
    1,2,true,friend
    """

    {:ok, graph} = GDF.deserialize(gdf_str)

    assert length(Yog.all_nodes(graph)) == 2
    assert length(Yog.successors(graph, 1)) == 1
  end

  test "deserialize with quotes" do
    gdf_str = """
    nodedef>name VARCHAR,label VARCHAR
    1,"Alice, Admin"
    edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
    """

    {:ok, graph} = GDF.deserialize(gdf_str)

    node_data = Yog.Model.node(graph, 1)
    assert node_data["label"] == "Alice, Admin"
  end

  test "deserialize with custom mappers" do
    gdf_str = """
    nodedef>name VARCHAR,name VARCHAR,age VARCHAR
    1,Alice,30
    2,Bob,25
    edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,relation VARCHAR
    1,2,true,friend
    """

    node_folder = fn attrs ->
      name = Map.get(attrs, "name", "")
      age = Map.get(attrs, "age", "0") |> String.to_integer()
      %{name: name, age: age}
    end

    edge_folder = fn attrs -> Map.get(attrs, "relation", "") end

    {:ok, graph} = GDF.deserialize_with(node_folder, edge_folder, gdf_str)

    # Check nodes
    person1 = Yog.Model.node(graph, 1)
    assert person1.name == "Alice"
    assert person1.age == 30

    person2 = Yog.Model.node(graph, 2)
    assert person2.name == "Bob"
    assert person2.age == 25

    # Check edge
    {_, edge_data} = Yog.successors(graph, 1) |> hd()
    assert edge_data == "friend"
  end

  test "deserialize missing edge section" do
    gdf_str = """
    nodedef>name VARCHAR,label VARCHAR
    1,Alice
    2,Bob
    """

    {:ok, graph} = GDF.deserialize(gdf_str)

    assert length(Yog.all_nodes(graph)) == 2
    assert Yog.successors(graph, 1) == []
  end

  test "deserialize edge without nodes creates nodes" do
    gdf_str = """
    nodedef>name VARCHAR,label VARCHAR
    edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,weight VARCHAR
    1,2,true,10
    """

    {:ok, graph} = GDF.deserialize(gdf_str)

    # Both nodes should exist even though only referenced in edge
    assert length(Yog.all_nodes(graph)) == 2
    assert length(Yog.successors(graph, 1)) == 1
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

    gdf_str = GDF.serialize(original)
    {:ok, loaded} = GDF.deserialize(gdf_str)

    assert length(Yog.all_nodes(loaded)) == 2

    node1 = Yog.Model.node(loaded, 1)
    assert node1["label"] == "Alice"

    succ = Yog.successors(loaded, 1)
    assert length(succ) == 1

    {dst, edge_data} = hd(succ)
    assert dst == 2
    assert edge_data["label"] == "friend"
  end

  test "roundtrip weighted graph" do
    original =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edges!([{1, 2, 10}, {2, 3, 20}])

    gdf_str = GDF.serialize_weighted(original)
    {:ok, loaded} = GDF.deserialize(gdf_str)

    assert length(Yog.all_nodes(loaded)) == 3

    {_, edge_data} = Yog.successors(loaded, 1) |> hd()
    assert edge_data["weight"] == "10"
  end

  test "roundtrip undirected graph" do
    original =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edges!([{1, 2, "10"}, {2, 3, "20"}])

    gdf_str = GDF.serialize(original)
    {:ok, loaded} = GDF.deserialize(gdf_str)

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

    gdf_str = GDF.serialize(original)
    {:ok, loaded} = GDF.deserialize(gdf_str)

    assert length(Yog.all_nodes(loaded)) == 4

    assert length(Yog.successors(loaded, 1)) == 2
    assert length(Yog.predecessors(loaded, 4)) == 2
  end

  # =============================================================================
  # FILE I/O TESTS
  # =============================================================================

  test "write and read gdf file" do
    path = "/tmp/test_yog_io_gdf.gdf"

    original =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "5")

    # Write
    assert {:ok, nil} = GDF.write(path, original)

    # Read back
    assert {:ok, loaded} = GDF.read(path)

    assert length(Yog.all_nodes(loaded)) == 2

    node1 = Yog.Model.node(loaded, 1)
    assert node1["label"] == "Alice"

    File.rm!(path)
  end

  test "read nonexistent file" do
    assert {:error, _} = GDF.read("/tmp/nonexistent_file_xyz_123.gdf")
  end

  # =============================================================================
  # ERROR HANDLING TESTS
  # =============================================================================

  test "deserialize missing nodedef" do
    gdf_str = "some random text without nodedef"
    assert {:error, _} = GDF.deserialize(gdf_str)
  end

  test "deserialize invalid node id" do
    gdf_str = """
    nodedef>name VARCHAR,label VARCHAR
    abc,Alice
    edgedef>node1 VARCHAR,node2 VARCHAR,directed BOOLEAN,label VARCHAR
    """

    {:ok, graph} = GDF.deserialize(gdf_str)

    # Invalid node IDs should be skipped
    assert Yog.all_nodes(graph) == []
  end

  # =============================================================================
  # HEADER PARSING TESTS
  # =============================================================================

  test "deserialize header without types" do
    gdf_str = """
    nodedef>name,label,role
    1,Alice,admin
    edgedef>node1,node2,directed,relation,notes
    1,2,true,friend,colleague
    """

    {:ok, graph} = GDF.deserialize(gdf_str)

    node1 = Yog.Model.node(graph, 1)
    assert node1["name"] == "1"
    assert node1["label"] == "Alice"
    assert node1["role"] == "admin"
  end

  test "deserialize header with mixed types" do
    gdf_str = """
    nodedef>name VARCHAR,label,age INT
    1,Alice,30
    edgedef>node1,node2,directed,weight VARCHAR
    1,2,true,10
    """

    {:ok, graph} = GDF.deserialize(gdf_str)

    node1 = Yog.Model.node(graph, 1)
    assert node1["name"] == "1"
    assert node1["label"] == "Alice"
    assert node1["age"] == "30"
  end
end
