defmodule Yog.IO.GEXF.VizTest do
  use ExUnit.Case, async: true
  alias Yog.IO.GEXF

  test "round-trip with all viz attributes" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, %{
        "viz:color" => %{r: 255, g: 100, b: 50, a: 0.5},
        "viz:position" => %{x: 10.5, y: -20.0, z: 0.0},
        "viz:size" => 15.2,
        "viz:shape" => "disc"
      })

    xml = GEXF.serialize_with(fn a -> a end, fn a -> a end, graph)
    assert xml =~ ~s(<viz:color r="255" g="100" b="50" a="0.5"/>)
    assert xml =~ ~s(<viz:position x="10.5" y="-20.0" z="0.0"/>)
    assert xml =~ ~s(<viz:size value="15.2"/>)
    assert xml =~ ~s(<viz:shape value="disc"/>)

    {:ok, deserialized} = GEXF.deserialize(xml)
    node_data = Yog.Model.node(deserialized, 1)

    assert node_data["viz:color"] == %{r: 255, g: 100, b: 50, a: 0.5}
    assert node_data["viz:position"] == %{x: 10.5, y: -20.0, z: 0.0}
    assert node_data["viz:size"] == 15.2
    assert node_data["viz:shape"] == "disc"
  end

  test "round-trip with typed attributes (simple)" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, %{"age" => 30, "active" => true, "score" => 95.5, "name" => "Alice"})

    xml = GEXF.serialize_with(fn a -> a end, fn a -> a end, graph)
    assert xml =~ ~s(type="integer")
    assert xml =~ ~s(type="boolean")
    assert xml =~ ~s(type="double")
    assert xml =~ ~s(type="string")

    {:ok, deserialized} = GEXF.deserialize(xml)
    node_data = Yog.Model.node(deserialized, 1)

    assert node_data["age"] === 30
    assert node_data["active"] === true
    assert node_data["score"] === 95.5
    assert node_data["name"] === "Alice"
  end

  test "round-trip with typed attributes (multi)" do
    alias Yog.IO.GEXF.Multi
    alias Yog.Multi.Model

    graph =
      Model.new(:directed)
      |> Model.add_node(1, %{"age" => 30})
      |> Model.add_edge(1, 1, %{"score" => 10.5, "confirmed" => false})
      |> elem(0)

    xml = Multi.serialize_with(fn a -> a end, fn a -> a end, graph)
    assert xml =~ ~s(type="integer")
    assert xml =~ ~s(type="double")
    assert xml =~ ~s(type="boolean")

    {:ok, deserialized} = Multi.deserialize(xml)
    node_data = deserialized.nodes[1]
    edge_data = Enum.at(Map.values(deserialized.edges), 0) |> elem(2)

    assert node_data["age"] === 30
    assert edge_data["score"] === 10.5
    assert edge_data["confirmed"] === false
  end

  test "xmerl fallback (manual exercise)" do
    # We can't easily disable Saxy globally without affecting other tests,
    # but we can call the private functions if we want to be sure.
    # However, testing with special characters often triggers the fallback logic
    # if there are bad characters.

    bad_xml =
      "<?xml version=\"1.0\"?><gexf><graph><nodes><node id=\"1\" label=\"Alice\b\"/></nodes></graph></gexf>"

    # \b (backspace) is invalid in XML 1.0.

    # This should trigger the sanitization path in parse_gexf_xmerl if Saxy was missing.
    # But since Saxy is present, it might just fail or handle it.
    # Let's test the sanitize_xml directly via XMLUtils.

    sanitized = Yog.IO.XMLUtils.sanitize_xml(bad_xml)
    refute sanitized =~ "\b"
  end
end
