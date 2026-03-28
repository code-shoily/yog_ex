defmodule Yog.IO.JSONImportTest do
  use ExUnit.Case

  alias Yog.IO.JSON

  describe "from_json/1" do
    test "parses generic yog format" do
      json =
        ~s|{"graph_type":"directed","nodes":[{"id":1,"data":"Alice"},{"id":2,"data":"Bob"}],"edges":[{"source":1,"target":2,"weight":"follows"}]}|

      {:ok, graph} = JSON.from_json(json)
      assert Yog.Model.order(graph) == 2
      assert Yog.Model.type(graph) == :directed
      assert Yog.has_edge?(graph, 1, 2)
    end

    test "parses NetworkX format" do
      json =
        ~s|{"directed":true,"multigraph":false,"graph":{},"nodes":[{"id":1,"data":"A"},{"id":2,"data":"B"}],"links":[{"source":1,"target":2,"weight":5}]}|

      {:ok, graph} = JSON.from_json(json)
      assert Yog.Model.order(graph) == 2
      assert Yog.Model.type(graph) == :directed
      assert Yog.Model.edge_count(graph) == 1
    end

    test "parses D3 format" do
      json =
        ~s|{"nodes":[{"id":1},{"id":2},{"id":3}],"links":[{"source":1,"target":2,"weight":5},{"source":2,"target":3,"weight":7}]}|

      {:ok, graph} = JSON.from_json(json)
      assert Yog.Model.order(graph) == 3
      assert Yog.Model.edge_count(graph) == 2
      assert Yog.Model.type(graph) == :undirected
    end

    test "parses Cytoscape format" do
      json =
        ~s|{"elements":[{"data":{"id":1,"label":"A"}},{"data":{"id":2,"label":"B"}},{"data":{"source":1,"target":2,"weight":10}}]}|

      {:ok, graph} = JSON.from_json(json)
      assert Yog.Model.order(graph) == 2
      assert Yog.Model.edge_count(graph) == 1
    end

    test "parses VisJs format" do
      json =
        ~s|{"nodes":[{"id":1,"label":"A"},{"id":2,"label":"B"}],"edges":[{"from":1,"to":2,"label":"10"}]}|

      {:ok, graph} = JSON.from_json(json)
      assert Yog.Model.order(graph) == 2
      assert Yog.Model.edge_count(graph) == 1
    end

    test "handles empty graph" do
      json = ~s|{"graph_type":"undirected","nodes":[],"edges":[]}|
      {:ok, graph} = JSON.from_json(json)
      assert Yog.Model.order(graph) == 0
    end

    test "handles string IDs" do
      json = ~s|{"nodes":[{"id":"a"},{"id":"b"}],"links":[{"source":"a","target":"b"}]}|
      {:ok, graph} = JSON.from_json(json)
      assert Yog.Model.order(graph) == 2
      assert Yog.has_edge?(graph, "a", "b")
    end

    test "handles numeric string IDs" do
      json = ~s|{"nodes":[{"id":"1"},{"id":"2"}],"links":[{"source":"1","target":"2"}]}|
      {:ok, graph} = JSON.from_json(json)
      # Should parse "1" as integer 1
      assert Yog.has_edge?(graph, 1, 2)
    end
  end

  describe "from_json!/1" do
    test "returns graph on success" do
      json = ~s|{"graph_type":"undirected","nodes":[{"id":1}],"edges":[]}|
      graph = JSON.from_json!(json)
      assert Yog.Model.order(graph) == 1
    end

    test "raises on invalid JSON" do
      assert_raise ArgumentError, fn ->
        JSON.from_json!("not valid json")
      end
    end
  end

  describe "from_map/1" do
    test "parses from Elixir map (PostgreSQL JSONB style)" do
      map = %{
        "graph_type" => "directed",
        "nodes" => [
          %{"id" => 1, "data" => "Task A"},
          %{"id" => 2, "data" => "Task B"}
        ],
        "edges" => [
          %{"source" => 1, "target" => 2, "weight" => "depends_on"}
        ]
      }

      {:ok, graph} = JSON.from_map(map)
      assert Yog.Model.order(graph) == 2
      assert Yog.Model.type(graph) == :directed
      assert Yog.has_edge?(graph, 1, 2)
    end

    test "handles simple format with 'type' key" do
      map = %{
        "type" => "undirected",
        "nodes" => [%{"id" => 1}, %{"id" => 2}],
        "edges" => [%{"from" => 1, "to" => 2}]
      }

      {:ok, graph} = JSON.from_map(map)
      assert Yog.Model.order(graph) == 2
      assert Yog.Model.type(graph) == :undirected
    end

    test "round-trip: export then import" do
      original =
        Yog.undirected()
        |> Yog.add_node(1, "Node A")
        |> Yog.add_node(2, "Node B")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      # Export to JSON
      json = JSON.to_json(original, JSON.default_export_options())

      # Import back
      {:ok, restored} = JSON.from_json(json)

      assert Yog.Model.order(restored) == Yog.Model.order(original)
      assert Yog.Model.edge_count(restored) == Yog.Model.edge_count(original)
      assert Yog.Model.type(restored) == Yog.Model.type(original)
    end

    test "round-trip via map (PostgreSQL JSONB simulation)" do
      original =
        Yog.directed()
        |> Yog.add_node(1, %{name: "Task 1", status: :pending})
        |> Yog.add_node(2, %{name: "Task 2", status: :done})
        |> Yog.add_edge_ensure(from: 1, to: 2, with: :depends_on)

      # Export
      json = JSON.to_json(original, JSON.default_export_options())
      map = Jason.decode!(json)

      # Import from map (as if loaded from JSONB)
      {:ok, restored} = JSON.from_map(map)

      assert Yog.Model.order(restored) == 2
      assert Yog.Model.edge_count(restored) == 1
      assert Yog.Model.type(restored) == :directed
    end
  end

  describe "PostgreSQL JSONB workflow" do
    test "typical LiveView/JSONB round-trip" do
      # User creates graph in LiveView
      graph =
        Yog.directed()
        |> Yog.add_node(1, %{title: "Learn Elixir", completed: false})
        |> Yog.add_node(2, %{title: "Build Graph App", completed: false})
        |> Yog.add_node(3, %{title: "Deploy to Production", completed: false})
        |> Yog.add_edge_ensure(from: 1, to: 2, with: :prerequisite)
        |> Yog.add_edge_ensure(from: 2, to: 3, with: :prerequisite)

      # Save to Postgres (as JSONB)
      json_string = JSON.to_json(graph, JSON.default_export_options())
      jsonb_data = Jason.decode!(json_string)

      # Later... load from Postgres
      {:ok, loaded_graph} = JSON.from_map(jsonb_data)

      # Verify
      assert Yog.Model.order(loaded_graph) == 3
      assert Yog.Model.edge_count(loaded_graph) == 2

      # Check no cycles in prerequisites
      assert Yog.Property.Cyclicity.acyclic?(loaded_graph)
    end
  end
end
