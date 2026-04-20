defmodule Yog.IO.GEXF.CommonTest do
  use ExUnit.Case, async: true
  alias Yog.IO.GEXF.Common
  alias Yog.IO.XMLUtils

  test "build_graph_from_doc simple graph via xmerl" do
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

    {:ok, doc} = XMLUtils.try_parse_xml(xml)

    {:ok, graph} =
      Common.build_graph_from_doc(
        doc,
        fn attrs -> attrs end,
        fn attrs -> attrs end,
        Yog.Model,
        false
      )

    assert Yog.Model.type(graph) == :undirected
    assert Yog.Model.node_count(graph) == 2
    assert length(Yog.successors(graph, 1)) == 1
  end

  test "build_graph_from_doc multigraph via xmerl" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="directed">
        <nodes>
          <node id="1" label="A"/>
          <node id="2" label="B"/>
        </nodes>
        <edges>
          <edge id="0" source="1" target="2" weight="e1"/>
          <edge id="1" source="1" target="2" weight="e2"/>
        </edges>
      </graph>
    </gexf>
    """

    {:ok, doc} = XMLUtils.try_parse_xml(xml)

    {:ok, graph} =
      Common.build_graph_from_doc(
        doc,
        fn attrs -> attrs end,
        fn attrs -> attrs end,
        Yog.Multi.Model,
        true
      )

    assert graph.kind == :directed
    assert Yog.Multi.Model.order(graph) == 2
    assert Yog.Multi.Model.size(graph) == 2
  end

  test "build_graph_from_doc with typed attributes via xmerl" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="directed">
        <attributes class="node">
          <attribute id="0" title="count" type="integer"/>
          <attribute id="1" title="score" type="double"/>
          <attribute id="2" title="active" type="boolean"/>
        </attributes>
        <nodes>
          <node id="1">
            <attvalues>
              <attvalue for="0" value="42"/>
              <attvalue for="1" value="3.14"/>
              <attvalue for="2" value="true"/>
            </attvalues>
          </node>
        </nodes>
        <edges></edges>
      </graph>
    </gexf>
    """

    {:ok, doc} = XMLUtils.try_parse_xml(xml)

    {:ok, graph} =
      Common.build_graph_from_doc(
        doc,
        fn attrs -> attrs end,
        fn attrs -> attrs end,
        Yog.Model,
        false
      )

    node_data = Yog.Model.node(graph, 1)
    assert node_data["count"] === 42
    assert node_data["score"] === 3.14
    assert node_data["active"] === true
  end

  test "xmerl_cast_value types" do
    assert Common.xmerl_cast_value("42", "integer") === 42
    assert Common.xmerl_cast_value("42", "long") === 42
    assert Common.xmerl_cast_value("3.14", "double") === 3.14
    assert Common.xmerl_cast_value("3.14", "float") === 3.14
    assert Common.xmerl_cast_value("true", "boolean") === true
    assert Common.xmerl_cast_value("false", "boolean") === false
    assert Common.xmerl_cast_value("hello", "string") === "hello"
    assert Common.xmerl_cast_value("hello", "unknown") === "hello"
  end

  test "xmerl_get_float with invalid value returns default" do
    xml = "<foo value=\"not_a_float\"/>"
    {doc, _} = :xmerl_scan.string(String.to_charlist(xml), quiet: true)
    [elem] = :xmerl_xpath.string(~c'/foo', doc)
    assert Common.xmerl_get_float(elem, "value", 1.0) === 1.0
  end

  test "xmerl_get_float with empty value returns default" do
    xml = "<foo/>"
    {doc, _} = :xmerl_scan.string(String.to_charlist(xml), quiet: true)
    [elem] = :xmerl_xpath.string(~c'/foo', doc)
    assert Common.xmerl_get_float(elem, "value", 2.5) === 2.5
  end

  test "xmerl_get_int with empty value returns default" do
    xml = "<foo/>"
    {doc, _} = :xmerl_scan.string(String.to_charlist(xml), quiet: true)
    [elem] = :xmerl_xpath.string(~c'/foo', doc)
    assert Common.xmerl_get_int(elem, "value", 99) === 99
  end

  test "parse_id with integer string" do
    assert Common.parse_id("123") === 123
  end

  test "parse_id with non-integer string" do
    assert Common.parse_id("abc") === "abc"
    assert Common.parse_id("123abc") === "123abc"
  end

  test "discover_keys_with_types excludes viz keys and special key" do
    attrs_list = [
      %{"label" => "A", "viz:color" => %{r: 255}, "normal_key" => "value"}
    ]

    keys = Common.discover_keys_with_types(attrs_list, "label")
    assert Map.has_key?(keys, "normal_key")
    refute Map.has_key?(keys, "label")
    refute Map.has_key?(keys, "viz:color")
  end

  test "build_viz_xml with no viz attrs returns empty list" do
    assert Common.build_viz_xml(%{"label" => "A", "normal" => "value"}) === []
  end

  test "build_viz_xml with viz attrs returns xml fragments" do
    attrs = %{
      "viz:color" => %{r: 255, g: 0, b: 0, a: 1.0},
      "viz:size" => 10.5,
      "label" => "A"
    }

    result = Common.build_viz_xml(attrs)
    viz_str = IO.iodata_to_binary(result)

    assert viz_str =~ ~s(<viz:color r="255" g="0" b="0" a="1.0"/>)
    assert viz_str =~ ~s(<viz:size value="10.5"/>)
    refute viz_str =~ "label"
  end

  test "build_attvalues filters special and viz keys" do
    keys = %{"normal_key" => %{id: 0, type: "string"}}

    attrs = %{
      "label" => "A",
      "weight" => "10",
      "viz:color" => %{},
      "normal_key" => "val"
    }

    result = Common.build_attvalues(attrs, keys, "label") |> IO.iodata_to_binary()
    assert result =~ ~s(<attvalue for="0" value="val"/>)
    refute result =~ "label"
    refute result =~ "weight"
    refute result =~ "viz:color"

    result2 = Common.build_attvalues(attrs, keys, "weight") |> IO.iodata_to_binary()
    assert result2 =~ ~s(<attvalue for="0" value="val"/>)
    refute result2 =~ "weight"
  end

  test "to_string_key avoids to_string on binaries" do
    assert Common.to_string_key("hello") === "hello"
    assert Common.to_string_key(:hello) === "hello"
    assert Common.to_string_key(123) === "123"
  end

  test "infer_type maps values correctly" do
    assert Common.infer_type(42) === "integer"
    assert Common.infer_type(3.14) === "double"
    assert Common.infer_type(true) === "boolean"
    assert Common.infer_type("hello") === "string"
    assert Common.infer_type(nil) === "string"
  end

  test "build_attribute_definitions handles empty keys" do
    assert Common.build_attribute_definitions(%{}, %{}) === [[], []]
  end

  test "extract_graph_type with charlist result" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph defaultedgetype="undirected">
        <nodes><node id="1"/></nodes>
      </graph>
    </gexf>
    """

    {:ok, doc} = XMLUtils.try_parse_xml(xml)
    assert Common.extract_graph_type(doc) == :undirected
  end

  test "extract_graph_type defaults to directed when missing" do
    xml = """
    <?xml version="1.0"?>
    <gexf version="1.3">
      <graph>
        <nodes><node id="1"/></nodes>
      </graph>
    </gexf>
    """

    {:ok, doc} = XMLUtils.try_parse_xml(xml)
    assert Common.extract_graph_type(doc) == :directed
  end
end
