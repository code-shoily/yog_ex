defmodule Yog.Property.PlanarityTest do
  use ExUnit.Case

  alias Yog.Property.Planarity
  alias Yog.Generator.Classic

  test "planar? basic checks" do
    # K4 is planar
    nodes = 1..4

    k4 =
      for u <- nodes, v <- nodes, u < v, reduce: Yog.undirected() do
        acc -> Yog.add_edge_ensure(acc, u, v, 1, nil)
      end

    assert Planarity.planar?(k4)

    # K5 is NOT planar (Exact Test)
    g_k5 = Classic.complete(5)
    assert not Planarity.planar?(g_k5)

    # K3,3 is NOT planar (Exact Test)
    k33 = Classic.complete_bipartite(3, 3)
    assert not Planarity.planar?(k33)

    # Petersen Graph is NOT planar (Exact Test)
    petersen = Classic.petersen()
    assert not Planarity.planar?(petersen)
  end

  test "planar_embedding" do
    # Triangle
    triangle = Classic.cycle(3)

    case Planarity.planar_embedding(triangle) do
      {:ok, embedding} ->
        # Check cyclic order around node 1
        adj = Map.get(embedding, 1)
        assert length(adj) == 2
        assert Enum.sort(adj) == [0, 2]

      :nonplanar ->
        flunk("Triangle should be planar")
    end

    # K5 should be nonplanar with witness
    g_k5 = Classic.complete(5)

    case Planarity.planar_embedding(g_k5) do
      {:nonplanar, witness} ->
        assert witness.type == :k5
        assert length(witness.nodes) == 5

      {:ok, _} ->
        flunk("K5 should not be planar")
    end
  end

  test "kuratowski_witness" do
    # K3,3
    k33 = Classic.complete_bipartite(3, 3)

    case Planarity.kuratowski_witness(k33) do
      {:ok, witness} ->
        assert witness.type == :k33
        assert length(witness.nodes) == 6

      :planar ->
        flunk("K3,3 should be non-planar")
    end

    # K5
    k5 = Classic.complete(5)

    case Planarity.kuratowski_witness(k5) do
      {:ok, witness} ->
        assert witness.type == :k5
        assert length(witness.nodes) == 5

      :planar ->
        flunk("K5 should be non-planar")
    end
  end
end
