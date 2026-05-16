defmodule Yog.Multi.DOTTest do
  use ExUnit.Case
  alias Yog.Multi.DOT

  describe "default_options/0" do
    test "returns multigraph defaults" do
      opts = DOT.default_options()
      assert opts.graph_name == "G"
      assert opts.node_shape == :ellipse
      assert is_function(opts.node_label, 2)
      assert is_function(opts.edge_label, 2)
    end
  end

  describe "to_dot/2" do
    test "renders empty multigraph" do
      multi = Yog.Multi.Graph.new(:directed)
      dot = DOT.to_dot(multi)

      assert String.contains?(dot, "digraph G {")
      assert String.contains?(dot, "}")
    end

    test "renders parallel edges in directed graph" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "Server")
        |> Yog.Multi.add_node(2, "Database")

      {multi, _id1} = Yog.Multi.add_edge(multi, 1, 2, 5.0)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 15.0)

      dot = DOT.to_dot(multi)

      assert String.contains?(dot, "digraph")
      assert String.contains?(dot, "1 -> 2")
      # It should output multiple edge lines
      edge_lines = String.split(dot, "\n") |> Enum.filter(&String.contains?(&1, "->"))
      assert length(edge_lines) == 2
    end

    test "renders parallel edges in undirected graph without duplication" do
      multi =
        Yog.Multi.undirected()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, _id1} = Yog.Multi.add_edge(multi, 1, 2, 10)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 20)

      dot = DOT.to_dot(multi)

      assert String.contains?(dot, "graph")
      assert String.contains?(dot, "1 -- 2")
      edge_lines = String.split(dot, "\n") |> Enum.filter(&String.contains?(&1, "--"))
      assert length(edge_lines) == 2
    end

    test "supports per-edge configuration via edge_id" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, id1} = Yog.Multi.add_edge(multi, 1, 2, 1.0)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 2.0)

      opts = %{
        DOT.default_options()
        | edge_attributes: fn _u, _v, edge_id, _weight ->
            if edge_id == id1, do: [{:color, "red"}], else: [{:color, "blue"}]
          end,
          edge_label: fn _edge_id, weight -> "id:#{weight}" end
      }

      dot = DOT.to_dot(multi, opts)
      assert String.contains?(dot, "color=\"red\"")
      assert String.contains?(dot, "color=\"blue\"")
      assert String.contains?(dot, "label=\"id:1.0\"")
      assert String.contains?(dot, "label=\"id:2.0\"")
    end

    test "highlights specific multigraph edge by edge_id" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, id1} = Yog.Multi.add_edge(multi, 1, 2, 10)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 20)

      opts = %{DOT.default_options() | highlighted_edges: [id1]}

      dot = DOT.to_dot(multi, opts)
      # One line should have highlight styling (red by default), the other standard
      assert String.contains?(dot, "color=\"red\"")
      assert String.contains?(dot, "color=\"black\"")
    end

    test "renders with subgraphs and styling" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")
        |> Yog.Multi.add_node(3, "C")

      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1.0)
      {multi, _} = Yog.Multi.add_edge(multi, 2, 3, 1.0)

      opts = %{
        DOT.default_options()
        | subgraphs: [
            %{
              name: "cluster_0",
              label: "SubGroup",
              node_ids: [1, 2],
              style: :filled,
              fillcolor: "yellow",
              color: "black"
            }
          ]
      }

      dot = DOT.to_dot(multi, opts)
      assert String.contains?(dot, "subgraph cluster_0")
      assert String.contains?(dot, "label=\"SubGroup\"")
      assert String.contains?(dot, "style=filled")
      assert String.contains?(dot, "fillcolor=\"yellow\"")
    end

    test "renders large complex multigraph for Livebook visual inspection" do
      # Create a large mock system architecture graph
      multi =
        Yog.Multi.directed()
        # Core microservices
        |> Yog.Multi.add_node("API", %{type: :service, desc: "Gateway API"})
        |> Yog.Multi.add_node("Auth", %{type: :service, desc: "Auth Service"})
        |> Yog.Multi.add_node("UserDB", %{type: :db, desc: "PostgreSQL"})
        |> Yog.Multi.add_node("Payment", %{type: :service, desc: "Stripe Integration"})
        |> Yog.Multi.add_node("Cache", %{type: :infra, desc: "Redis"})
        |> Yog.Multi.add_node("Analytics", %{type: :service, desc: "Data Pipeline"})

      # Establish parallel flows
      # API <-> Auth traffic
      {multi, _} = Yog.Multi.add_edge(multi, "API", "Auth", "Auth Check (REST)")
      {multi, _} = Yog.Multi.add_edge(multi, "API", "Auth", "Token Refresh (gRPC)")

      # Auth <-> DB connections
      {multi, _} = Yog.Multi.add_edge(multi, "Auth", "UserDB", "Read (SQL)")
      {multi, _} = Yog.Multi.add_edge(multi, "Auth", "UserDB", "Update Session (SQL)")

      # Payment pipeline
      {multi, _} = Yog.Multi.add_edge(multi, "API", "Payment", "Process Charge")
      {multi, _} = Yog.Multi.add_edge(multi, "Payment", "Cache", "Idempotency Lock")
      {multi, _} = Yog.Multi.add_edge(multi, "Payment", "Analytics", "Metric emission")

      # Custom large styling options suitable for direct Livebook copy
      opts = %{
        DOT.default_options()
        | graph_name: "SystemDesign",
          layout: :dot,
          rankdir: :lr,
          bgcolor: "#1e1e24",
          node_shape: :box,
          node_fontname: "Helvetica-Bold",
          node_fontsize: 14,
          node_fontcolor: "#ffffff",
          edge_fontname: "Courier",
          node_attributes: fn _id, data ->
            case Map.get(data || %{}, :type) do
              :service -> [{:fillcolor, "#4a90e2"}, {:style, "filled,rounded"}]
              :db -> [{:fillcolor, "#50e3c2"}, {:style, "filled,box"}, {:shape, "cylinder"}]
              :infra -> [{:fillcolor, "#f5a623"}, {:style, "filled"}]
              _ -> []
            end
          end,
          edge_attributes: fn _from, _to, _edge_id, weight ->
            case weight do
              w when is_binary(w) -> [{:label, w}, {:color, "#8b949e"}]
              _ -> []
            end
          end,
          subgraphs: [
            %{
              name: "cluster_security",
              label: "Security Domain",
              node_ids: ["Auth", "UserDB"],
              style: :dashed,
              fillcolor: nil,
              color: "#ff4d4f"
            }
          ]
      }

      dot = DOT.to_dot(multi, opts)

      assert String.contains?(dot, "digraph SystemDesign")
      assert String.contains?(dot, "API -> Auth")
      assert String.contains?(dot, "Auth -> UserDB")
      assert String.contains?(dot, "shape=\"cylinder\"")
      assert String.contains?(dot, "fillcolor=\"#4a90e2\"")
      assert String.contains?(dot, "Token Refresh")
    end
  end
end
