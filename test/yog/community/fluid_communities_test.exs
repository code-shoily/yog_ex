defmodule Yog.Community.FluidCommunitiesTest do
  @moduledoc """
  Tests for Yog.Community.FluidCommunities module.

  Fluid Communities algorithm uses density-based propagation to find
  communities, allowing control over the number of communities.
  """

  use ExUnit.Case

  alias Yog.Community.FluidCommunities

  doctest FluidCommunities

  # ============================================================
  # Basic Detection Tests
  # ============================================================

  test "detect on two triangles connected by bridge" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_node(4, nil)
      |> Yog.add_node(5, nil)
      # First triangle
      |> Yog.add_edge!(from: 0, to: 1, with: 1)
      |> Yog.add_edge!(from: 1, to: 2, with: 1)
      |> Yog.add_edge!(from: 2, to: 0, with: 1)
      # Second triangle
      |> Yog.add_edge!(from: 3, to: 4, with: 1)
      |> Yog.add_edge!(from: 4, to: 5, with: 1)
      |> Yog.add_edge!(from: 5, to: 3, with: 1)
      # Bridge edge
      |> Yog.add_edge!(from: 2, to: 3, with: 1)

    comms = FluidCommunities.detect(graph)

    # Should find communities
    assert comms.num_communities >= 1
    assert map_size(comms.assignments) == 6
  end

  test "detect_with_options" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 0, 1}
      ])

    opts = [max_iterations: 50, seed: 123]
    comms = FluidCommunities.detect_with_options(graph, opts)

    assert comms.num_communities >= 1
    assert map_size(comms.assignments) == 3
  end

  test "detect on empty graph" do
    graph = Yog.undirected()
    comms = FluidCommunities.detect(graph)

    assert comms.num_communities == 0
  end

  test "detect on single node" do
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)

    comms = FluidCommunities.detect(graph)

    assert comms.num_communities == 1
  end
end
