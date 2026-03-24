defmodule Yog.Generator.RandomTest do
  use ExUnit.Case

  alias Yog.Generator.Random

  doctest Yog.Generator.Random

  # ============= Random Regular Graph Tests =============

  test "random_regular/2 generates d-regular graph" do
    reg = Random.random_regular(10, 3)
    assert Yog.Model.order(reg) == 10
    # n*d/2 = 10*3/2
    assert Yog.Model.edge_count(reg) == 15

    # All nodes have degree exactly d
    degrees = for v <- 0..9, do: length(Yog.neighbors(reg, v))
    assert Enum.all?(degrees, fn d -> d == 3 end)
  end

  test "random_regular/2 generates 0-regular graph (isolated nodes)" do
    reg = Random.random_regular(5, 0)
    assert Yog.Model.order(reg) == 5
    assert Yog.Model.edge_count(reg) == 0

    degrees = for v <- 0..4, do: length(Yog.neighbors(reg, v))
    assert Enum.all?(degrees, fn d -> d == 0 end)
  end

  test "random_regular/2 generates 1-regular graph (matching)" do
    reg = Random.random_regular(10, 1)
    assert Yog.Model.order(reg) == 10
    # n*d/2 = 10*1/2
    assert Yog.Model.edge_count(reg) == 5

    degrees = for v <- 0..9, do: length(Yog.neighbors(reg, v))
    assert Enum.all?(degrees, fn d -> d == 1 end)
  end

  test "random_regular/2 generates 2-regular graph (disjoint cycles)" do
    reg = Random.random_regular(10, 2)
    assert Yog.Model.order(reg) == 10
    # n*d/2 = 10*2/2
    assert Yog.Model.edge_count(reg) == 10

    degrees = for v <- 0..9, do: length(Yog.neighbors(reg, v))
    assert Enum.all?(degrees, fn d -> d == 2 end)
  end

  test "random_regular/2 invalid n*d odd returns empty" do
    # n*d must be even for any d-regular graph to exist
    reg = Random.random_regular(5, 3)
    # 5*3 = 15 is odd, so should return empty graph
    assert Yog.Model.order(reg) == 0
  end

  test "random_regular/2 d >= n returns empty" do
    reg = Random.random_regular(5, 5)
    assert Yog.Model.order(reg) == 0
  end

  test "random_regular/2 negative n returns empty" do
    reg = Random.random_regular(-1, 2)
    assert Yog.Model.order(reg) == 0
  end

  test "random_regular/2 negative d returns empty" do
    reg = Random.random_regular(10, -1)
    assert Yog.Model.order(reg) == 0
  end

  test "random_regular_with_type/3 directed regular graph" do
    reg = Random.random_regular_with_type(10, 3, :directed)
    assert Yog.Model.type(reg) == :directed
    assert Yog.Model.order(reg) == 10
  end

  test "random_regular/2 single node" do
    reg = Random.random_regular(1, 0)
    assert Yog.Model.order(reg) == 1
    assert Yog.Model.edge_count(reg) == 0
  end

  test "random_regular/2 no self-loops" do
    reg = Random.random_regular(10, 3)

    for v <- 0..9 do
      refute v in Yog.neighbors(reg, v)
    end
  end

  test "random_regular/2 no parallel edges" do
    reg = Random.random_regular(10, 3)

    for v <- 0..9 do
      neigh = Yog.neighbors(reg, v)
      # Check no duplicates
      assert length(neigh) == length(Enum.uniq(neigh))
    end
  end
end
