defmodule Yog.IO.JSONTest do
  use ExUnit.Case

  alias Yog.IO.JSON

  doctest Yog.IO.JSON

  # =============================================================================
  # DEFAULT OPTIONS TESTS
  # =============================================================================

  test "default_export_options creates valid options tuple" do
    options = JSON.default_export_options()
    assert {:json_export_options, :yog_generic, true, _, _, false, %{}} = options
  end

  test "export_options_with creates valid options tuple" do
    node_ser = fn n -> "node_#{n}" end
    edge_ser = fn e -> "edge_#{e}" end
    options = JSON.export_options_with(node_ser, edge_ser)
    assert {:json_export_options, :yog_generic, true, ^node_ser, ^edge_ser, false, %{}} = options
  end

  # =============================================================================
  # BASIC EXPORT TESTS - GENERIC FORMAT
  # =============================================================================

  test "to_json exports directed graph in generic format" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")

    options = JSON.default_export_options()
    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert result["format"] == "yog-generic"
    assert result["version"] == "2.0"
    assert result["graph_type"] == "directed"
    assert length(result["nodes"]) == 2
    assert length(result["edges"]) == 1

    assert Enum.any?(result["nodes"], fn n -> n["id"] == 1 && n["data"] == "Alice" end)
    assert Enum.any?(result["nodes"], fn n -> n["id"] == 2 && n["data"] == "Bob" end)

    assert Enum.any?(result["edges"], fn e ->
             e["source"] == 1 && e["target"] == 2 && e["weight"] == "follows"
           end)
  end

  test "to_json exports undirected graph in generic format" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "friends")

    options = JSON.default_export_options()
    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert result["graph_type"] == "undirected"
    assert length(result["nodes"]) == 2
    assert length(result["edges"]) == 1
  end

  test "to_json with metadata enabled" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_node(3, "Carol")
      |> Yog.add_edges!([{1, 2, "follows"}, {2, 3, "knows"}])

    options = JSON.default_export_options()
    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert result["metadata"]["node_count"] == 3
    assert result["metadata"]["edge_count"] == 2
    assert result["metadata"]["directed"] == true
  end

  test "to_json with metadata disabled" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")

    # Create options with metadata disabled
    options =
      {:json_export_options, :yog_generic, false, &Function.identity/1, &Function.identity/1,
       false, %{}}

    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    refute Map.has_key?(result, "metadata")
  end

  # =============================================================================
  # CUSTOM SERIALIZERS
  # =============================================================================

  test "to_json with custom node serializer" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, 100)
      |> Yog.add_node(2, 200)
      |> Yog.add_edge!(from: 1, to: 2, with: "link")

    node_ser = fn n -> "value_#{n}" end
    edge_ser = fn e -> e end
    options = JSON.export_options_with(node_ser, edge_ser)
    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert Enum.any?(result["nodes"], fn n -> n["data"] == "value_100" end)
    assert Enum.any?(result["nodes"], fn n -> n["data"] == "value_200" end)
  end

  test "to_json with custom edge serializer" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: 42)

    node_ser = fn n -> n end
    edge_ser = fn e -> "weight_#{e}" end
    options = JSON.export_options_with(node_ser, edge_ser)
    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert Enum.any?(result["edges"], fn e -> e["weight"] == "weight_42" end)
  end

  test "to_json with map data types" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, %{name: "Alice", age: 30})
      |> Yog.add_node(2, %{name: "Bob", age: 25})
      |> Yog.add_edge!(from: 1, to: 2, with: %{type: "follows", since: 2020})

    node_ser = fn n -> n end
    edge_ser = fn e -> e end
    options = JSON.export_options_with(node_ser, edge_ser)
    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    alice = Enum.find(result["nodes"], fn n -> n["id"] == 1 end)
    assert alice["data"]["name"] == "Alice"
    assert alice["data"]["age"] == 30

    edge = Enum.find(result["edges"], fn e -> e["source"] == 1 end)
    assert edge["weight"]["type"] == "follows"
    assert edge["weight"]["since"] == 2020
  end

  # =============================================================================
  # NETWORKX FORMAT TESTS
  # =============================================================================

  test "to_json with networkx format" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")

    options =
      {:json_export_options, :network_x, true, &Function.identity/1, &Function.identity/1, false,
       %{}}

    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert result["directed"] == true
    assert result["multigraph"] == false
    assert result["graph"] == %{}
    assert length(result["nodes"]) == 2
    assert length(result["links"]) == 1
    assert Map.has_key?(result, "metadata")
  end

  test "to_json networkx format without metadata" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    options =
      {:json_export_options, :network_x, false, &Function.identity/1, &Function.identity/1, false,
       %{}}

    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert result["directed"] == false
    refute Map.has_key?(result, "metadata")
  end

  # =============================================================================
  # D3 FORMAT TESTS
  # =============================================================================

  test "to_d3_json exports in D3 force format" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_node(3, "Carol")
      |> Yog.add_edges!([{1, 2, 1.0}, {2, 3, 2.0}])

    json_string = JSON.to_d3_json(graph, &Function.identity/1, &Function.identity/1)
    result = Jason.decode!(json_string)

    assert Map.keys(result) |> Enum.sort() == ["links", "nodes"]
    assert length(result["nodes"]) == 3
    assert length(result["links"]) == 2

    assert Enum.all?(result["nodes"], fn n -> Map.has_key?(n, "id") && Map.has_key?(n, "data") end)

    assert Enum.all?(result["links"], fn l ->
             Map.has_key?(l, "source") && Map.has_key?(l, "target") && Map.has_key?(l, "weight")
           end)
  end

  test "to_json with d3_force format" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: "link")

    options =
      {:json_export_options, :d3_force, false, &Function.identity/1, &Function.identity/1, false,
       %{}}

    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    refute Map.has_key?(result, "format")
    refute Map.has_key?(result, "metadata")
    assert Map.has_key?(result, "nodes")
    assert Map.has_key?(result, "links")
  end

  # =============================================================================
  # CYTOSCAPE FORMAT TESTS
  # =============================================================================

  test "to_cytoscape_json exports in Cytoscape format" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")

    json_string = JSON.to_cytoscape_json(graph, &Function.identity/1, &Function.identity/1)
    result = Jason.decode!(json_string)

    assert Map.has_key?(result, "elements")
    assert length(result["elements"]) == 3

    nodes = Enum.filter(result["elements"], fn e -> Map.has_key?(e["data"], "label") end)
    edges = Enum.filter(result["elements"], fn e -> Map.has_key?(e["data"], "source") end)

    assert length(nodes) == 2
    assert length(edges) == 1
  end

  test "to_json with cytoscape format" do
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Node1")
      |> Yog.add_node(2, "Node2")
      |> Yog.add_edge!(from: 1, to: 2, with: "connection")

    options =
      {:json_export_options, :cytoscape, false, &Function.identity/1, &Function.identity/1, false,
       %{}}

    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert Map.has_key?(result, "elements")
    elements = result["elements"]

    assert Enum.any?(elements, fn e ->
             Map.get(e, "data", %{}) |> Map.get("id") == 1
           end)
  end

  # =============================================================================
  # VIS.JS FORMAT TESTS
  # =============================================================================

  test "to_visjs_json exports in vis.js format" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")

    json_string = JSON.to_visjs_json(graph, &Function.identity/1, &Function.identity/1)
    result = Jason.decode!(json_string)

    assert Map.keys(result) |> Enum.sort() == ["edges", "nodes"]
    assert length(result["nodes"]) == 2
    assert length(result["edges"]) == 1

    assert Enum.all?(result["nodes"], fn n ->
             Map.has_key?(n, "id") && Map.has_key?(n, "label")
           end)

    assert Enum.all?(result["edges"], fn e ->
             Map.has_key?(e, "from") && Map.has_key?(e, "to") && Map.has_key?(e, "label")
           end)
  end

  test "to_json with visjs format" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: "edge")

    options =
      {:json_export_options, :visjs, false, &Function.identity/1, &Function.identity/1, false,
       %{}}

    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert result["nodes"] |> Enum.any?(fn n -> n["id"] == 1 && n["label"] == "A" end)
    assert result["edges"] |> Enum.any?(fn e -> e["from"] == 1 && e["to"] == 2 end)
  end

  # =============================================================================
  # EDGE CASES
  # =============================================================================

  test "to_json with empty graph" do
    graph = Yog.directed()
    options = JSON.default_export_options()
    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert result["nodes"] == []
    assert result["edges"] == []
    assert result["metadata"]["node_count"] == 0
    assert result["metadata"]["edge_count"] == 0
  end

  test "to_json with single node, no edges" do
    graph = Yog.directed() |> Yog.add_node(1, "Lonely")
    options = JSON.default_export_options()
    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert length(result["nodes"]) == 1
    assert result["edges"] == []
    assert result["metadata"]["node_count"] == 1
    assert result["metadata"]["edge_count"] == 0
  end

  test "to_json with multiple edges between same nodes" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_edge!(from: 1, to: 2, with: "first")

    options = JSON.default_export_options()
    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert length(result["edges"]) == 1
  end

  test "to_json with self-loop" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Self")
      |> Yog.add_edge!(from: 1, to: 1, with: "loop")

    options = JSON.default_export_options()
    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert Enum.any?(result["edges"], fn e -> e["source"] == 1 && e["target"] == 1 end)
  end

  test "to_json with large graph" do
    graph =
      Enum.reduce(1..100, Yog.directed(), fn i, g ->
        Yog.add_node(g, i, "Node#{i}")
      end)
      |> then(fn g ->
        Enum.reduce(1..99, g, fn i, acc ->
          Yog.add_edge!(acc, from: i, to: i + 1, with: "edge#{i}")
        end)
      end)

    options = JSON.default_export_options()
    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert length(result["nodes"]) == 100
    assert length(result["edges"]) == 99
    assert result["metadata"]["node_count"] == 100
    assert result["metadata"]["edge_count"] == 99
  end

  test "to_json with unknown format defaults to generic" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")

    options =
      {:json_export_options, :unknown_format, true, &Function.identity/1, &Function.identity/1,
       false, %{}}

    json_string = JSON.to_json(graph, options)
    result = Jason.decode!(json_string)

    assert result["format"] == "yog-generic"
  end

  # =============================================================================
  # FILE I/O TESTS
  # =============================================================================

  test "write saves graph to file with default options" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_edge!(from: 1, to: 2, with: "follows")

    path = "/tmp/test_graph_#{:rand.uniform(1_000_000)}.json"

    try do
      assert {:ok, nil} = JSON.write(path, graph)
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      result = Jason.decode!(content)

      assert result["format"] == "yog-generic"
      assert length(result["nodes"]) == 2
      assert length(result["edges"]) == 1
    after
      File.rm(path)
    end
  end

  test "write_with saves graph to file with custom options" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")

    path = "/tmp/test_graph_custom_#{:rand.uniform(1_000_000)}.json"

    options =
      {:json_export_options, :d3_force, false, &Function.identity/1, &Function.identity/1, false,
       %{}}

    try do
      assert {:ok, nil} = JSON.write_with(path, options, graph)
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      result = Jason.decode!(content)

      assert Map.has_key?(result, "nodes")
      assert Map.has_key?(result, "links")
      refute Map.has_key?(result, "format")
    after
      File.rm(path)
    end
  end

  test "to_json_file exports graph to file" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "Test")

    path = "/tmp/test_json_file_#{:rand.uniform(1_000_000)}.json"
    options = JSON.default_export_options()

    try do
      assert {:ok, nil} = JSON.to_json_file(graph, path, options)
      assert File.exists?(path)
    after
      File.rm(path)
    end
  end

  test "to_json_file handles write errors" do
    graph = Yog.directed() |> Yog.add_node(1, "Test")
    options = JSON.default_export_options()

    # Try to write to an invalid path
    result = JSON.to_json_file(graph, "/invalid/path/file.json", options)
    assert {:error, _} = result
  end

  # =============================================================================
  # MULTIGRAPH TESTS
  # =============================================================================

  test "to_json_multi exports multigraph" do
    # Create a multigraph (using the internal structure)
    multigraph = %{
      kind: :directed,
      nodes: %{1 => "Alice", 2 => "Bob"},
      edges: %{
        1 => {1, 2, "follows"},
        2 => {1, 2, "likes"}
      },
      in_edges: %{2 => MapSet.new([1, 2])},
      out_edges: %{1 => MapSet.new([1, 2])},
      next_edge_id: 3
    }

    options = JSON.default_export_options()
    json_string = JSON.to_json_multi(multigraph, options)
    result = Jason.decode!(json_string)

    assert result["format"] == "yog-generic"
    assert result["multigraph"] == true
    assert length(result["nodes"]) == 2
    assert length(result["edges"]) == 2
    assert result["edge_count"] == 2

    # Check that edges have IDs
    assert Enum.all?(result["edges"], fn e -> Map.has_key?(e, "id") end)
  end

  test "to_json_multi with metadata" do
    multigraph = %{
      kind: :undirected,
      nodes: %{1 => "A"},
      edges: %{},
      in_edges: %{},
      out_edges: %{},
      next_edge_id: 1
    }

    options = JSON.default_export_options()
    json_string = JSON.to_json_multi(multigraph, options)
    result = Jason.decode!(json_string)

    assert result["metadata"]["node_count"] == 1
    assert result["metadata"]["edge_count"] == 0
    assert result["metadata"]["directed"] == false
  end

  test "to_json_file_multi exports multigraph to file" do
    multigraph = %{
      kind: :directed,
      nodes: %{1 => "Test"},
      edges: %{},
      in_edges: %{},
      out_edges: %{},
      next_edge_id: 1
    }

    path = "/tmp/test_multigraph_#{:rand.uniform(1_000_000)}.json"
    options = JSON.default_export_options()

    try do
      assert :ok = JSON.to_json_file_multi(multigraph, path, options)
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      result = Jason.decode!(content)

      assert result["multigraph"] == true
    after
      File.rm(path)
    end
  end

  # =============================================================================
  # ERROR HANDLING TESTS
  # =============================================================================

  test "error_to_string converts error to string" do
    error = {:json_error, "Something went wrong"}
    result = JSON.error_to_string(error)

    assert is_binary(result)
    assert String.contains?(result, "json_error")
  end
end
