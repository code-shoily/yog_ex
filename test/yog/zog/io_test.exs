defmodule Yog.Zog.IOTest do
  use ExUnit.Case, async: true

  alias Yog.Zog.ResourceGraph

  @moduletag :zigler

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "yog_zog_io_test_#{System.system_time()}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  test "native edgelist reader", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "graph.edgelist")

    File.write!(path, """
    # Directed edge list with optional weights
    1 2 2.5
    2 3 1.0
    3 1
    """)

    # 1. Directed graph
    res_graph = ResourceGraph.read_edgelist(path, directed: true)
    assert res_graph.builder.kind == :directed
    assert res_graph.builder.next_id == 3
    assert Enum.sort(Yog.Builder.Zog.all_labels(res_graph.builder)) == ["1", "2", "3"]

    # Run PageRank on loaded graph
    pr = ResourceGraph.pagerank(res_graph)
    assert Map.keys(pr) == ["1", "2", "3"]
    ResourceGraph.destroy(res_graph)

    # 2. Undirected graph
    res_graph_un = ResourceGraph.read_edgelist(path, directed: false)
    assert res_graph_un.builder.kind == :undirected
    assert res_graph_un.builder.next_id == 3
    ResourceGraph.destroy(res_graph_un)
  end

  test "native adjlist reader", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "graph.adjlist")

    File.write!(path, """
    # Adjacency list
    1: 2,2.5 3
    2: 3,1.0
    3: 1
    """)

    res_graph = ResourceGraph.read_adjlist(path, directed: true)
    assert res_graph.builder.kind == :directed
    assert res_graph.builder.next_id == 3
    assert Enum.sort(Yog.Builder.Zog.all_labels(res_graph.builder)) == ["1", "2", "3"]

    # Run PageRank on loaded graph
    pr = ResourceGraph.pagerank(res_graph)
    assert Map.keys(pr) == ["1", "2", "3"]
    ResourceGraph.destroy(res_graph)
  end

  test "native tgf reader", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "graph.tgf")

    File.write!(path, """
    1 Node1
    2 Node2
    3 Node3
    #
    1 2 2.5
    2 3 1.0
    3 1
    """)

    res_graph = ResourceGraph.read_tgf(path, directed: true)
    assert res_graph.builder.kind == :directed
    assert res_graph.builder.next_id == 3
    assert Enum.sort(Yog.Builder.Zog.all_labels(res_graph.builder)) == ["1", "2", "3"]

    # Run PageRank on loaded graph
    pr = ResourceGraph.pagerank(res_graph)
    assert Map.keys(pr) == ["1", "2", "3"]
    ResourceGraph.destroy(res_graph)
  end
end
