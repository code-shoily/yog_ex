defmodule Yog.Community.CliquePercolationTest do
  @moduledoc """
  Tests for Yog.Community.CliquePercolation module.

  Clique Percolation Method (CPM) finds overlapping communities by
  detecting k-cliques that share k-1 nodes.
  """

  use ExUnit.Case

  alias Yog.Community.CliquePercolation

  doctest CliquePercolation

  # ============================================================
  # Basic Detection Tests
  # ============================================================

  test "detect_overlapping on graph with overlapping cliques" do
    # Create a graph where cliques overlap
    # Two triangles sharing an edge (forms a diamond shape)
    graph =
      Yog.undirected()
      |> Yog.add_node(0, nil)
      |> Yog.add_node(1, nil)
      |> Yog.add_node(2, nil)
      |> Yog.add_node(3, nil)
      |> Yog.add_edges!([
        {0, 1, 1},
        {1, 2, 1},
        {2, 0, 1},
        {1, 3, 1},
        {3, 2, 1}
      ])

    result = CliquePercolation.detect_overlapping(graph)

    # Should find overlapping communities
    assert is_map(result.memberships)
    assert result.num_communities >= 1
  end

  test "detect_overlapping_with_options" do
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

    opts = [k: 3]
    result = CliquePercolation.detect_overlapping_with_options(graph, opts)

    assert is_map(result.memberships)
  end

  test "detect_overlapping on empty graph" do
    graph = Yog.undirected()
    result = CliquePercolation.detect_overlapping(graph)

    assert result.num_communities == 0
  end
end
