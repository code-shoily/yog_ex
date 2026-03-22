defmodule Yog.IO.JSONTest do
  use ExUnit.Case

  alias Yog.IO.JSON
  alias Yog.Multi.Model

  doctest Yog.IO.JSON

  # Gleam JSON module for serialization inside Elixir wrapper tests
  # json.string/1 translates to :gleam@json.string/1
  def string_serializer(x), do: :gleam@json.string(to_string(x))
  def int_serializer(x), do: :gleam@json.int(x)

  # =============================================================================
  # Generic Format Tests
  # =============================================================================

  test "to_json_generic_format" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")

    json_str = JSON.to_json(graph, JSON.default_export_options())

    assert String.contains?(json_str, ~s("format":"yog-generic"))
    assert String.contains?(json_str, ~s("version":"2.0"))
    assert String.contains?(json_str, ~s("nodes"))
    assert String.contains?(json_str, ~s("edges"))
    assert String.contains?(json_str, ~s("metadata"))
  end

  test "to_json_undirected_graph" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: "connected")

    json_str = JSON.to_json(graph, JSON.default_export_options())

    assert String.contains?(json_str, ~s("graph_type":"undirected"))
  end

  # =============================================================================
  # Formats Helper Options Tests
  # =============================================================================

  test "to_json_d3_force_format" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "5")

    json_str = JSON.to_d3_json(graph, &string_serializer/1, &string_serializer/1)

    assert String.contains?(json_str, ~s("links"))
    assert String.contains?(json_str, ~s("nodes"))
    refute String.contains?(json_str, ~s("format"))
  end

  test "to_json_cytoscape_format" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Node1")
      |> Yog.add_node(2, "Node2")
      |> Yog.add_edge!(from: 1, to: 2, with: "edge1")

    json_str = JSON.to_cytoscape_json(graph, &string_serializer/1, &string_serializer/1)

    assert String.contains?(json_str, ~s("elements"))
  end

  test "to_json_visjs_format" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: "link")

    json_str = JSON.to_visjs_json(graph, &string_serializer/1, &string_serializer/1)

    assert String.contains?(json_str, ~s("from"))
    assert String.contains?(json_str, ~s("to"))
  end

  test "to_json_networkx_format (via direct options manipulation)" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "X")
      |> Yog.add_node(2, "Y")
      |> Yog.add_edge!(from: 1, to: 2, with: "edge")

    # Reconstruct options since there's no direct "to_networkx_json" alias
    # Generic format tuple: {:json_export_options, format, metadata?, n_s, e_s, pretty?, meta}
    # Gleam 1.x translates format NetworkingX as `:network_x`
    options = JSON.default_export_options() |> put_elem(1, :network_x) |> put_elem(2, false)
    json_str = JSON.to_json(graph, options)

    assert String.contains?(json_str, ~s("directed":true))
    assert String.contains?(json_str, ~s("multigraph":false))
    assert String.contains?(json_str, ~s("links"))
  end

  # =============================================================================
  # File I/O Tests
  # =============================================================================

  test "to_json_file" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Test")
      |> Yog.add_node(2, "Node")
      |> Yog.add_edge!(from: 1, to: 2, with: "link")

    path = "test_output.json"

    assert {:ok, nil} = JSON.to_json_file(graph, path, JSON.default_export_options())
    assert {:ok, _contents} = File.read(path)

    File.rm(path)
  end

  # =============================================================================
  # Custom Serializer Tests
  # =============================================================================

  test "custom_serializer" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, %{name: "Alice", age: 30})
      |> Yog.add_node(2, %{name: "Bob", age: 25})
      |> Yog.add_edge!(from: 1, to: 2, with: 5)

    node_ser = fn person ->
      :gleam@json.object([
        {"name", :gleam@json.string(person.name)},
        {"age", :gleam@json.int(person.age)}
      ])
    end

    edge_ser = fn weight -> :gleam@json.int(weight) end

    options = JSON.export_options_with(node_ser, edge_ser)
    json_str = JSON.to_json(graph, options)

    assert String.contains?(json_str, ~s("Alice"))
    assert String.contains?(json_str, ~s("Bob"))
  end

  # =============================================================================
  # Metadata Tests
  # =============================================================================

  test "no metadata" do
    graph = Yog.directed() |> Yog.add_node(1, "A")

    options = JSON.default_export_options() |> put_elem(2, false)
    json_str = JSON.to_json(graph, options)

    refute String.contains?(json_str, ~s("metadata"))
  end

  # =============================================================================
  # Edge Case Tests
  # =============================================================================

  test "empty graph" do
    graph = Yog.directed()

    json_str = JSON.to_json(graph, JSON.default_export_options())

    assert String.contains?(json_str, ~s("nodes"))
    assert String.contains?(json_str, ~s("edges"))
  end

  test "single node" do
    graph = Yog.directed() |> Yog.add_node(42, "Lonely")

    json_str = JSON.to_json(graph, JSON.default_export_options())

    assert String.contains?(json_str, ~s("id":42))
    assert String.contains?(json_str, ~s("Lonely"))
  end

  # =============================================================================
  # MultiGraph Export Tests
  # =============================================================================

  test "to_json_multi generic format" do
    graph =
      Model.directed()
      |> Model.add_node(1, "Alice")
      |> Model.add_node(2, "Bob")

    {graph, _} = Model.add_edge(graph, 1, 2, "follows")
    {graph, _} = Model.add_edge(graph, 1, 2, "mentions")
    {graph, _} = Model.add_edge(graph, 1, 2, "likes")

    json_str = JSON.to_json_multi(graph, JSON.default_export_options())

    assert String.contains?(json_str, ~s("format":"yog-generic"))
    assert String.contains?(json_str, ~s("multigraph":true))
    assert String.contains?(json_str, ~s("id":))
    assert String.contains?(json_str, ~s("edge_count":3))
  end
end
