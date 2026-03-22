defmodule Yog.Render.JSONTest do
  use ExUnit.Case

  alias Yog.Render.JSON

  doctest JSON

  describe "default_options/0" do
    test "returns mapper functions" do
      opts = JSON.default_options()

      assert is_function(opts.node_mapper, 2)
      assert is_function(opts.edge_mapper, 3)

      # Test the mappers
      node_result = opts.node_mapper.(1, "Alice")
      assert node_result["id"] == 1
      assert node_result["label"] == "Alice"

      edge_result = opts.edge_mapper.(1, 2, "follows")
      assert edge_result["source"] == 1
      assert edge_result["target"] == 2
      assert edge_result["weight"] == "follows"
    end
  end

  describe "to_json/2" do
    test "exports directed graph" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Alice")
        |> Yog.add_node(2, "Bob")
        |> Yog.add_edge!(from: 1, to: 2, with: "follows")

      json = JSON.to_json(graph, JSON.default_options())

      assert String.contains?(json, "Alice")
      assert String.contains?(json, "Bob")
      assert String.contains?(json, "follows")
      assert String.contains?(json, "nodes")
      assert String.contains?(json, "edges")
    end

    test "exports undirected graph" do
      graph =
        Yog.undirected()
        |> Yog.add_node(1, "A")
        |> Yog.add_node(2, "B")
        |> Yog.add_edge!(from: 1, to: 2, with: "1")

      json = JSON.to_json(graph, JSON.default_options())

      assert String.contains?(json, "A")
      assert String.contains?(json, "B")
    end

    test "exports graph with multiple nodes and edges" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Start")
        |> Yog.add_node(2, "Middle")
        |> Yog.add_node(3, "End")
        |> Yog.add_edge!(from: 1, to: 2, with: "5")
        |> Yog.add_edge!(from: 2, to: 3, with: "3")

      json = JSON.to_json(graph, JSON.default_options())

      assert String.contains?(json, "Start")
      assert String.contains?(json, "Middle")
      assert String.contains?(json, "End")
      assert String.contains?(json, "5")
      assert String.contains?(json, "3")
    end

    test "produces valid JSON structure" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "Test")
        |> Yog.add_edge!(from: 1, to: 1, with: "loop")

      json = JSON.to_json(graph, JSON.default_options())

      # Should start with { and end with }
      assert String.starts_with?(json, "{")
      assert String.ends_with?(json, "}")

      # Should be parseable as JSON
      decoded = Jason.decode!(json)
      assert is_list(decoded["nodes"])
      assert is_list(decoded["edges"])
    end
  end
end
