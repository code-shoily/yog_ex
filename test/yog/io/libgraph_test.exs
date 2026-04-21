defmodule Yog.IO.LibgraphTest do
  use ExUnit.Case, async: true
  doctest Yog.IO.Libgraph

  alias Yog.IO.Libgraph

  test "converts simple directed graph" do
    libgraph =
      Graph.new(type: :directed)
      |> Graph.add_vertex(1, "A")
      |> Graph.add_vertex(2, "B")
      |> Graph.add_edge(1, 2, weight: 5)

    # Use force_type: :simple to avoid DAG detection
    assert {:ok, graph} = Libgraph.from_libgraph(libgraph, force_type: :simple)
    assert graph.kind == :directed
    assert Yog.Model.order(graph) == 2
    assert Yog.Model.degree(graph, 1) == 1
    # all_nodes returns a list of node IDs
    assert 1 in Yog.Model.all_nodes(graph)
    assert graph.nodes[1] == "A"
  end

  test "converts simple undirected graph" do
    libgraph =
      Graph.new(type: :undirected)
      |> Graph.add_vertex(1, "A")
      |> Graph.add_vertex(2, "B")
      |> Graph.add_edge(1, 2, weight: 5)

    assert {:ok, graph} = Libgraph.from_libgraph(libgraph, force_type: :simple)
    assert graph.kind == :undirected
    assert Yog.Model.order(graph) == 2
    assert graph.nodes[1] == "A"
  end

  test "converts Libgraph to Yog.Multi.Graph via force_type" do
    # Note: libgraph itself doesn't support parallel edges (overwrites on same edge)
    # So we use force_type to create a multigraph
    libgraph =
      Graph.new(type: :directed)
      |> Graph.add_edge(1, 2, weight: 5)

    assert {:ok, %Yog.Multi.Model.Graph{} = multi} =
             Libgraph.from_libgraph(libgraph, force_type: :multi)

    assert multi.kind == :directed
    assert map_size(multi.edges) == 1
  end

  test "converts Libgraph to Yog.DAG if acyclic" do
    libgraph =
      Graph.new(type: :directed)
      |> Graph.add_edge(1, 2, weight: 5)
      |> Graph.add_edge(2, 3, weight: 10)

    # Without force_type, acyclic directed graphs become DAGs
    assert {:ok, %Yog.DAG{} = dag} = Libgraph.from_libgraph(libgraph)
    # Access the wrapped graph via .graph field
    assert Yog.Model.order(dag.graph) == 3
  end

  test "converts Libgraph to Yog.Graph even if acyclic if force_type is :simple" do
    libgraph =
      Graph.new(type: :directed)
      |> Graph.add_edge(1, 2, weight: 5)

    assert {:ok, %Yog.Graph{} = graph} = Libgraph.from_libgraph(libgraph, force_type: :simple)
    refute is_struct(graph, Yog.DAG)
  end

  test "bidirectional conversion preserves data" do
    graph =
      Yog.directed()
      |> Yog.add_node(1, "source")
      |> Yog.add_node(2, "target")
      |> Yog.add_edge_ensure(1, 2, 123)

    libgraph = Libgraph.to_libgraph(graph)
    assert libgraph.type == :directed
    assert Graph.vertices(libgraph) |> length() == 2

    # When converting back, use force_type to get a simple graph (not DAG)
    assert {:ok, second_graph} = Libgraph.from_libgraph(libgraph, force_type: :simple)
    assert second_graph.nodes[1] == "source"
    assert second_graph.nodes[2] == "target"

    # Check edge via successors
    successors = Yog.Model.successors(second_graph, 1)
    assert {2, 123} in successors
  end

  test "converts DAG to libgraph and back" do
    {:ok, dag} =
      Yog.DAG.from_graph(
        Yog.directed()
        |> Yog.add_node(1, "a")
        |> Yog.add_node(2, "b")
        |> Yog.add_edge_ensure(1, 2, 5)
      )

    libgraph = Libgraph.to_libgraph(dag)
    assert libgraph.type == :directed

    # Converting back from libgraph will detect it as a DAG (acyclic)
    assert {:ok, %Yog.DAG{} = yog_dag} = Libgraph.from_libgraph(libgraph)
    assert Yog.Model.order(yog_dag.graph) == 2
    assert yog_dag.graph.nodes[1] == "a"
  end

  test "to_libgraph handles map-based weights safely" do
    graph =
      Yog.directed()
      |> Yog.add_edge_with(1, 2, %{weight: 10, meta: "foo"}, & &1)

    libgraph = Libgraph.to_libgraph(graph)
    edge = hd(Graph.edges(libgraph))
    assert edge.weight == 10
    # Original data preserved in label
    assert edge.label == %{weight: 10, meta: "foo"}
  end

  test "to_libgraph handles custom weight_fn for complex data" do
    # User case: %{travel_time: {10, :minute}}
    data = %{route: :bus, travel_time: {10, :minute}}

    graph =
      Yog.directed()
      |> Yog.add_edge_with(1, 2, data, & &1)

    # Use custom weight_fn to extract the 10
    libgraph =
      Libgraph.to_libgraph(graph,
        weight_fn: fn
          %{travel_time: {mins, :minute}} -> mins
          _ -> 1
        end
      )

    edge = hd(Graph.edges(libgraph))
    assert edge.weight == 10
    assert edge.label == data
  end

  test "to_libgraph handles multigraphs safely" do
    {multi, _} =
      Yog.Multi.new(:directed)
      |> Yog.Multi.add_edge(1, 2, 5)

    {multi, _} = Yog.Multi.add_edge(multi, 1, 2, 10)

    libgraph = Libgraph.to_libgraph(multi)
    assert libgraph.type == :directed
    assert length(Graph.edges(libgraph)) == 2
    # Libgraph handles parallel edges by having multiple entries in edges list
    weights = Graph.edges(libgraph) |> Enum.map(& &1.weight) |> Enum.sort()
    assert weights == [5, 10]
  end

  test "to_libgraph uses default weight 1 for non-numerical weights in maps" do
    graph =
      Yog.directed()
      |> Yog.add_edge_with(1, 2, %{weight: "not a number"}, & &1)

    libgraph = Libgraph.to_libgraph(graph)
    edge = hd(Graph.edges(libgraph))
    assert edge.weight == 1
    assert edge.label == %{weight: "not a number"}
  end

  test "to_libgraph handles non-map non-number data safely" do
    graph =
      Yog.directed()
      |> Yog.add_edge_with(1, 2, :some_atom, & &1)

    libgraph = Libgraph.to_libgraph(graph)
    edge = hd(Graph.edges(libgraph))
    assert edge.weight == 1
    assert edge.label == :some_atom
  end
end
