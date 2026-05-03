defmodule Yog.Multi.MermaidTest do
  use ExUnit.Case
  alias Yog.Multi.Mermaid

  describe "default_options/0" do
    test "returns multigraph defaults" do
      opts = Mermaid.default_options()
      assert opts.direction == :td
      assert opts.node_shape == :rounded_rect
      assert is_function(opts.node_label, 2)
      assert is_function(opts.edge_label, 2)
      assert is_function(opts.node_attributes, 2)
      assert is_function(opts.edge_attributes, 4)
    end
  end

  describe "to_mermaid/2" do
    test "renders empty multigraph" do
      multi = Yog.Multi.Graph.new(:directed)
      mermaid = Mermaid.to_mermaid(multi)

      assert String.contains?(mermaid, "graph TD")
      refute String.contains?(mermaid, "-->")
    end

    test "renders parallel edges in directed graph" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "Server")
        |> Yog.Multi.add_node(2, "Database")

      {multi, _id1} = Yog.Multi.add_edge(multi, 1, 2, 5.0)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 15.0)

      mermaid = Mermaid.to_mermaid(multi)

      assert String.contains?(mermaid, "graph TD")
      assert String.contains?(mermaid, "1 -->|5.0| 2")
      assert String.contains?(mermaid, "1 -->|15.0| 2")
      # It should output multiple edge lines
      edge_lines = String.split(mermaid, "\n") |> Enum.filter(&String.contains?(&1, "-->"))
      assert length(edge_lines) == 2
    end

    test "renders parallel edges in undirected graph without duplication" do
      multi =
        Yog.Multi.undirected()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, _id1} = Yog.Multi.add_edge(multi, 1, 2, 10)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 20)

      mermaid = Mermaid.to_mermaid(multi)

      assert String.contains?(mermaid, "graph TD")
      assert String.contains?(mermaid, "1 ---|10| 2")
      assert String.contains?(mermaid, "1 ---|20| 2")
      edge_lines = String.split(mermaid, "\n") |> Enum.filter(&String.contains?(&1, "---"))
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
        Mermaid.default_options()
        | edge_attributes: fn _u, _v, edge_id, _weight ->
            if edge_id == id1, do: [{:stroke, "#d32f2f"}], else: [{:stroke, "#1976d2"}]
          end,
          edge_label: fn _edge_id, weight -> "id:#{weight}" end
      }

      mermaid = Mermaid.to_mermaid(multi, opts)
      assert String.contains?(mermaid, "linkStyle 0")
      assert String.contains?(mermaid, "linkStyle 1")
      assert String.contains?(mermaid, "stroke:#d32f2f")
      assert String.contains?(mermaid, "stroke:#1976d2")
      assert String.contains?(mermaid, "|id:1.0|")
      assert String.contains?(mermaid, "|id:2.0|")
    end

    test "highlights specific multigraph edge by edge_id" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, id1} = Yog.Multi.add_edge(multi, 1, 2, 10)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 20)

      opts = %{Mermaid.default_options() | highlighted_edges: [id1]}

      mermaid = Mermaid.to_mermaid(multi, opts)
      # One line should have highlight styling, the other standard
      assert String.contains?(mermaid, "linkStyle")
      assert String.contains?(mermaid, "stroke:#f57c00")
    end

    test "highlights multigraph edge by node tuple" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, _id1} = Yog.Multi.add_edge(multi, 1, 2, 10)
      {multi, _id2} = Yog.Multi.add_edge(multi, 1, 2, 20)

      opts = %{Mermaid.default_options() | highlighted_edges: [{1, 2}]}

      mermaid = Mermaid.to_mermaid(multi, opts)
      # Both edges should be highlighted since they share the same node tuple
      link_styles =
        String.split(mermaid, "\n") |> Enum.filter(&String.starts_with?(&1, "  linkStyle"))

      assert length(link_styles) == 2
    end

    test "renders with subgraphs" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")
        |> Yog.Multi.add_node(3, "C")

      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1.0)
      {multi, _} = Yog.Multi.add_edge(multi, 2, 3, 1.0)

      opts = %{
        Mermaid.default_options()
        | subgraphs: [
            %{
              name: "Group1",
              label: "SubGroup",
              node_ids: [1, 2]
            }
          ]
      }

      mermaid = Mermaid.to_mermaid(multi, opts)
      assert String.contains?(mermaid, "subgraph Group1")
      assert String.contains?(mermaid, "[\"SubGroup\"]")
      assert String.contains?(mermaid, "1")
      assert String.contains?(mermaid, "2")
      assert String.contains?(mermaid, "end")
    end

    test "renders with per-node attributes" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1.0)

      opts = %{
        Mermaid.default_options()
        | node_attributes: fn id, _data ->
            if id == 1, do: [{:fill, "#e1f5fe"}, {:stroke, "#0288d1"}], else: []
          end
      }

      mermaid = Mermaid.to_mermaid(multi, opts)
      assert String.contains?(mermaid, "style 1 fill:#e1f5fe,stroke:#0288d1")
    end

    test "renders with combined highlight and per-node attributes" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1.0)

      opts = %{
        Mermaid.default_options()
        | highlighted_nodes: [1],
          node_attributes: fn id, _data ->
            if id == 1, do: [{:stroke_width, "4px"}], else: []
          end
      }

      mermaid = Mermaid.to_mermaid(multi, opts)
      # Should have both highlight class and custom style
      assert String.contains?(mermaid, ":::highlight")

      assert String.contains?(
               mermaid,
               "style 1 fill:#ffeb3b,stroke:#f57c00,stroke-width:3px,stroke-width:4px"
             )
    end

    test "renders large complex multigraph" do
      # Create a large mock system architecture graph
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node("API", %{type: :service, desc: "Gateway API"})
        |> Yog.Multi.add_node("Auth", %{type: :service, desc: "Auth Service"})
        |> Yog.Multi.add_node("UserDB", %{type: :db, desc: "PostgreSQL"})
        |> Yog.Multi.add_node("Payment", %{type: :service, desc: "Stripe Integration"})
        |> Yog.Multi.add_node("Cache", %{type: :infra, desc: "Redis"})
        |> Yog.Multi.add_node("Analytics", %{type: :service, desc: "Data Pipeline"})

      # Establish parallel flows
      {multi, _} = Yog.Multi.add_edge(multi, "API", "Auth", "Auth Check (REST)")
      {multi, _} = Yog.Multi.add_edge(multi, "API", "Auth", "Token Refresh (gRPC)")
      {multi, _} = Yog.Multi.add_edge(multi, "Auth", "UserDB", "Read (SQL)")
      {multi, _} = Yog.Multi.add_edge(multi, "Auth", "UserDB", "Update Session (SQL)")
      {multi, _} = Yog.Multi.add_edge(multi, "API", "Payment", "Process Charge")
      {multi, _} = Yog.Multi.add_edge(multi, "Payment", "Cache", "Idempotency Lock")
      {multi, _} = Yog.Multi.add_edge(multi, "Payment", "Analytics", "Metric emission")

      opts = %{
        Mermaid.default_options()
        | direction: :lr,
          node_attributes: fn _id, data ->
            case Map.get(data || %{}, :type) do
              :service -> [{:fill, "#4a90e2"}]
              :db -> [{:fill, "#50e3c2"}]
              :infra -> [{:fill, "#f5a623"}]
              _ -> []
            end
          end,
          edge_attributes: fn _from, _to, _edge_id, weight ->
            case weight do
              w when is_binary(w) -> [{:stroke, "#8b949e"}]
              _ -> []
            end
          end,
          subgraphs: [
            %{
              name: "SecurityDomain",
              label: "Security Domain",
              node_ids: ["Auth", "UserDB"]
            }
          ]
      }

      mermaid = Mermaid.to_mermaid(multi, opts)

      assert String.contains?(mermaid, "graph LR")
      assert String.contains?(mermaid, "API -->|Auth Check (REST)| Auth")
      assert String.contains?(mermaid, "Auth -->|Read (SQL)| UserDB")
      assert String.contains?(mermaid, "style API fill:#4a90e2")
      assert String.contains?(mermaid, "style UserDB fill:#50e3c2")
      assert String.contains?(mermaid, "subgraph SecurityDomain")

      # Parallel edges should both be present
      api_auth_lines =
        String.split(mermaid, "\n")
        |> Enum.filter(&(String.contains?(&1, "API -->") and String.contains?(&1, "Auth")))

      assert length(api_auth_lines) == 2
    end

    test "renders with all directions" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1)

      for dir <- [:td, :lr, :bt, :rl] do
        opts = Map.put(Mermaid.default_options(), :direction, dir)
        mermaid = Mermaid.to_mermaid(multi, opts)
        assert String.contains?(mermaid, "graph #{String.upcase(to_string(dir))}")
      end
    end

    test "renders with all node shapes" do
      multi =
        Yog.Multi.directed()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 1)

      shapes = [
        :rounded_rect,
        :stadium,
        :subroutine,
        :cylinder,
        :circle,
        :asymmetric,
        :rhombus,
        :hexagon,
        :parallelogram,
        :parallelogram_alt,
        :trapezoid,
        :trapezoid_alt
      ]

      for shape <- shapes do
        opts = Map.put(Mermaid.default_options(), :node_shape, shape)
        mermaid = Mermaid.to_mermaid(multi, opts)
        assert String.contains?(mermaid, "graph TD"), "Shape #{shape} should render"
      end
    end

    test "handles undirected edge highlighting with reversed tuple" do
      multi =
        Yog.Multi.undirected()
        |> Yog.Multi.add_node(1, "A")
        |> Yog.Multi.add_node(2, "B")

      {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 10)

      opts = %{Mermaid.default_options() | highlighted_edges: [{2, 1}]}

      mermaid = Mermaid.to_mermaid(multi, opts)
      assert String.contains?(mermaid, "linkStyle")
    end
  end
end
