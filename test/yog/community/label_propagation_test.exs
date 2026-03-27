defmodule Yog.Community.LabelPropagationTest do
  @moduledoc """
  Tests for Yog.Community.LabelPropagation module.

  Label Propagation Algorithm (LPA) is a fast, near-linear time
  community detection algorithm based on label spreading.
  """

  use ExUnit.Case

  alias Yog.Community.LabelPropagation

  doctest LabelPropagation

  # ============================================================
  # Basic Detection Tests
  # ============================================================

  test "detect on complete graph K5 converges to single community" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_edges!([
        {0, 1, nil},
        {0, 2, nil},
        {0, 3, nil},
        {0, 4, nil},
        {1, 2, nil},
        {1, 3, nil},
        {1, 4, nil},
        {2, 3, nil},
        {2, 4, nil},
        {3, 4, nil}
      ])

    comms = LabelPropagation.detect(graph)

    # In a complete graph, all nodes should end up in the same community
    assert comms.num_communities == 1
  end

  test "detect on two disjoint cliques" do
    # Two triangles: {0,1,2} and {3,4,5}
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      |> Yog.add_edges!([
        {0, 1, nil},
        {1, 2, nil},
        {2, 0, nil},
        {3, 4, nil},
        {4, 5, nil},
        {5, 3, nil}
      ])

    comms = LabelPropagation.detect(graph)

    # Should find 2 communities
    assert comms.num_communities == 2

    # Nodes in each triangle should have the same label
    label_0 = comms.assignments[0]
    label_2 = comms.assignments[2]
    label_3 = comms.assignments[3]
    label_5 = comms.assignments[5]

    assert label_0 == label_2
    assert label_3 == label_5
    assert label_0 != label_3
  end

  test "detect with options" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edges!([
        {0, 1, nil},
        {1, 2, nil},
        {2, 0, nil}
      ])

    opts = [max_iterations: 100, seed: 123]
    comms = LabelPropagation.detect_with_options(graph, opts)

    assert comms.num_communities >= 1
    assert map_size(comms.assignments) == 3
  end

  test "detect on empty graph" do
    graph = Yog.undirected()
    comms = LabelPropagation.detect(graph)

    assert comms.num_communities == 0
  end

  test "detect on single node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)

    comms = LabelPropagation.detect(graph)

    assert comms.num_communities == 1
    assert comms.assignments[0] == 0
  end

  # ============================================================
  # Rigorous Community Benchmarks
  # ============================================================

  test "detect on Zachary's Karate Club" do
    graph = Yog.Test.Datasets.karate_club()
    result = LabelPropagation.detect_with_options(graph, max_iterations: 100, seed: 1)

    # Label propagation outcome can be highly sensitive to seeds
    assert result.num_communities >= 1
    assert result.num_communities <= 12
    assert map_size(result.assignments) == 34
  end
end
