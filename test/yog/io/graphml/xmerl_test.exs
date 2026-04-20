defmodule Yog.IO.GraphML.XmerlTest do
  use ExUnit.Case, async: true
  alias Yog.IO.GraphML.Xmerl
  alias Yog.IO.XMLUtils

  test "parse_graphml_xmerl with valid xml" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="undirected">
        <node id="1"><data key="name">A</data></node>
        <node id="2"><data key="name">B</data></node>
        <edge source="1" target="2"><data key="weight">5</data></edge>
      </graph>
    </graphml>
    """

    {:ok, graph} = Xmerl.parse_graphml_xmerl(xml, fn attrs -> attrs end, fn attrs -> attrs end)

    assert Yog.Model.type(graph) == :undirected
    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.node(graph, 1)["name"] == "A"
    assert length(Yog.successors(graph, 1)) == 1
  end

  test "parse_graphml_xmerl with directed graph" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="directed">
        <node id="1"></node>
        <node id="2"></node>
        <edge source="1" target="2"></edge>
      </graph>
    </graphml>
    """

    {:ok, graph} = Xmerl.parse_graphml_xmerl(xml, fn attrs -> attrs end, fn attrs -> attrs end)
    assert Yog.Model.type(graph) == :directed
  end

  test "parse_graphml_xmerl defaults to directed when edgedefault missing" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G">
        <node id="1"></node>
      </graph>
    </graphml>
    """

    {:ok, graph} = Xmerl.parse_graphml_xmerl(xml, fn attrs -> attrs end, fn attrs -> attrs end)
    assert Yog.Model.type(graph) == :directed
  end

  test "parse_graphml_xmerl with string node ids" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="directed">
        <node id="alice"></node>
        <node id="bob"></node>
        <edge source="alice" target="bob"></edge>
      </graph>
    </graphml>
    """

    {:ok, graph} = Xmerl.parse_graphml_xmerl(xml, fn attrs -> attrs end, fn attrs -> attrs end)
    assert Yog.Model.node_count(graph) == 2
    assert Yog.has_edge?(graph, "alice", "bob")
  end

  test "parse_graphml_xmerl with custom mappers" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="directed">
        <node id="1">
          <data key="name">Alice</data>
          <data key="age">30</data>
        </node>
        <edge source="1" target="2">
          <data key="relation">friend</data>
        </edge>
      </graph>
    </graphml>
    """

    node_folder = fn attrs ->
      %{
        name: Map.get(attrs, "name", ""),
        age: String.to_integer(Map.get(attrs, "age", "0"))
      }
    end

    edge_folder = fn attrs -> Map.get(attrs, "relation", "") end

    {:ok, graph} = Xmerl.parse_graphml_xmerl(xml, node_folder, edge_folder)
    assert Yog.Model.node(graph, 1).name == "Alice"
    assert Yog.Model.node(graph, 1).age == 30
  end

  test "parse_graphml_xmerl with empty nodes and edges" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="directed">
        <node id="1"></node>
        <node id="2"></node>
        <edge source="1" target="2"></edge>
      </graph>
    </graphml>
    """

    {:ok, graph} = Xmerl.parse_graphml_xmerl(xml, fn attrs -> attrs end, fn attrs -> attrs end)
    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1
    assert Yog.Model.node(graph, 1) == %{}
  end

  test "parse_graphml_xmerl sanitizes bad characters" do
    xml =
      "<?xml version=\"1.0\"?><graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\"><graph id=\"G\" edgedefault=\"directed\"><node id=\"1\"><data key=\"label\">hello\bworld</data></node></graph></graphml>"

    {:ok, graph} = Xmerl.parse_graphml_xmerl(xml, fn attrs -> attrs end, fn attrs -> attrs end)
    assert Yog.Model.node(graph, 1)["label"] == "helloworld"
  end

  test "parse_graphml_xmerl returns error for malformed xml" do
    assert {:error, _} = Xmerl.parse_graphml_xmerl("not xml", fn _ -> %{} end, fn _ -> %{} end)
  end

  test "build_graph_from_doc constructs graph from xmerl doc" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="directed">
        <node id="1"><data key="name">A</data></node>
        <node id="2"><data key="name">B</data></node>
        <edge source="1" target="2"><data key="w">10</data></edge>
      </graph>
    </graphml>
    """

    {:ok, doc} = XMLUtils.try_parse_xml(xml)
    {:ok, graph} = Xmerl.build_graph_from_doc(doc, fn attrs -> attrs end, fn attrs -> attrs end)

    assert Yog.Model.node_count(graph) == 2
    assert Yog.Model.edge_count(graph) == 1
  end

  test "extract_graph_type from xmerl doc" do
    directed_xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="directed"></graph>
    </graphml>
    """

    undirected_xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="undirected"></graph>
    </graphml>
    """

    missing_xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G"></graph>
    </graphml>
    """

    {:ok, directed_doc} = XMLUtils.try_parse_xml(directed_xml)
    {:ok, undirected_doc} = XMLUtils.try_parse_xml(undirected_xml)
    {:ok, missing_doc} = XMLUtils.try_parse_xml(missing_xml)

    assert Xmerl.extract_graph_type(directed_doc) == :directed
    assert Xmerl.extract_graph_type(undirected_doc) == :undirected
    assert Xmerl.extract_graph_type(missing_doc) == :directed
  end

  test "extract_nodes from xmerl doc" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="directed">
        <node id="1"><data key="name">Alice</data></node>
        <node id="2"><data key="name">Bob</data></node>
      </graph>
    </graphml>
    """

    {:ok, doc} = XMLUtils.try_parse_xml(xml)
    nodes = Xmerl.extract_nodes(doc, fn attrs -> attrs end)

    assert length(nodes) == 2
    assert Enum.find(nodes, fn {id, _} -> id == 1 end)
    assert Enum.find(nodes, fn {_, data} -> data["name"] == "Alice" end)
  end

  test "extract_nodes with string ids" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="directed">
        <node id="alice"></node>
      </graph>
    </graphml>
    """

    {:ok, doc} = XMLUtils.try_parse_xml(xml)
    nodes = Xmerl.extract_nodes(doc, fn attrs -> attrs end)

    assert nodes == [{"alice", %{}}]
  end

  test "extract_edges from xmerl doc" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="directed">
        <edge source="1" target="2"><data key="w">10</data></edge>
      </graph>
    </graphml>
    """

    {:ok, doc} = XMLUtils.try_parse_xml(xml)
    edges = Xmerl.extract_edges(doc, fn attrs -> attrs end)

    assert edges == [{1, 2, %{"w" => "10"}}]
  end

  test "extract_edges with string ids" do
    xml = """
    <?xml version="1.0"?>
    <graphml xmlns="http://graphml.graphdrawing.org/xmlns">
      <graph id="G" edgedefault="directed">
        <edge source="alice" target="bob"></edge>
      </graph>
    </graphml>
    """

    {:ok, doc} = XMLUtils.try_parse_xml(xml)
    edges = Xmerl.extract_edges(doc, fn attrs -> attrs end)

    assert edges == [{"alice", "bob", %{}}]
  end

  test "xmerl_string_value handles xmlObj" do
    assert Xmerl.xmerl_string_value({:xmlObj, :string, ~c"hello"}) == "hello"
    assert Xmerl.xmerl_string_value(~c"world") == "world"
    assert Xmerl.xmerl_string_value(:unexpected) == ""
    assert Xmerl.xmerl_string_value(nil) == ""
  end
end
