defmodule Yog.HealthTest do
  use ExUnit.Case

  alias Yog.Generator.Classic
  alias Yog.Health

  doctest Yog.Health

  defp opts do
    [
      with_zero: 0,
      with_add: &Kernel.+/2,
      with_compare: fn a, b ->
        cond do
          a < b -> :lt
          a > b -> :gt
          true -> :eq
        end
      end,
      with: &Function.identity/1,
      with_to_float: fn x -> x * 1.0 end
    ]
  end

  # ============= Diameter Tests =============

  test "diameter of path graph P_n is n-1" do
    for n <- 2..10 do
      g = Classic.path(n)
      assert Health.diameter(g, opts()) == n - 1
    end
  end

  test "diameter of cycle graph C_n is floor(n/2)" do
    for n <- 3..10 do
      g = Classic.cycle(n)
      assert Health.diameter(g, opts()) == div(n, 2)
    end
  end

  test "diameter of star graph S_n is 2" do
    for n <- 3..10 do
      g = Classic.star(n)
      assert Health.diameter(g, opts()) == 2
    end
  end

  test "diameter of complete graph K_n is 1" do
    for n <- 2..10 do
      g = Classic.complete(n)
      assert Health.diameter(g, opts()) == 1
    end
  end

  test "diameter of empty graph (0 nodes) is nil" do
    g = Classic.empty(0)
    assert Health.diameter(g, opts()) == nil
  end

  test "diameter of single isolated node is 0" do
    g = Classic.empty(1)
    assert Health.diameter(g, opts()) == 0
  end

  test "diameter of disconnected graph is nil" do
    g = Yog.Operation.disjoint_union(Classic.path(3), Classic.path(3))
    assert Health.diameter(g, opts()) == nil
  end

  test "diameter of grid_2d(rows, cols) is rows + cols - 2" do
    for rows <- 2..5, cols <- 2..5 do
      g = Classic.grid_2d(rows, cols)
      assert Health.diameter(g, opts()) == rows + cols - 2
    end
  end

  test "diameter of single node is 0" do
    g = Classic.path(1)
    assert Health.diameter(g, opts()) == 0
  end

  # ============= Radius Tests =============

  test "radius of path graph P_n is ceil((n-1)/2)" do
    for n <- 2..10 do
      g = Classic.path(n)
      expected = div(n, 2)
      assert Health.radius(g, opts()) == expected
    end
  end

  test "radius of cycle graph C_n is floor(n/2)" do
    for n <- 3..10 do
      g = Classic.cycle(n)
      assert Health.radius(g, opts()) == div(n, 2)
    end
  end

  test "radius of star graph S_n is 1" do
    for n <- 2..10 do
      g = Classic.star(n)
      assert Health.radius(g, opts()) == 1
    end
  end

  test "radius of complete graph K_n is 1" do
    for n <- 2..10 do
      g = Classic.complete(n)
      assert Health.radius(g, opts()) == 1
    end
  end

  test "radius of empty graph (0 nodes) is nil" do
    g = Classic.empty(0)
    assert Health.radius(g, opts()) == nil
  end

  test "radius of single isolated node is 0" do
    g = Classic.empty(1)
    assert Health.radius(g, opts()) == 0
  end

  test "radius of disconnected graph is nil" do
    g = Yog.Operation.disjoint_union(Classic.path(3), Classic.path(3))
    assert Health.radius(g, opts()) == nil
  end

  # ============= Eccentricity Tests =============

  test "eccentricity of end nodes in path P_n is n-1" do
    for n <- 2..10 do
      g = Classic.path(n)
      assert Health.eccentricity(g, 0, opts()) == n - 1
      assert Health.eccentricity(g, n - 1, opts()) == n - 1
    end
  end

  test "eccentricity of center node in star S_n is 1" do
    for n <- 2..10 do
      g = Classic.star(n)
      assert Health.eccentricity(g, 0, opts()) == 1
    end
  end

  test "eccentricity of leaf node in star S_n is 2" do
    for n <- 3..10 do
      g = Classic.star(n)
      assert Health.eccentricity(g, 1, opts()) == 2
    end
  end

  test "eccentricity in complete graph K_n is 1" do
    for n <- 2..10 do
      g = Classic.complete(n)
      assert Health.eccentricity(g, 0, opts()) == 1
    end
  end

  test "eccentricity of isolated node is 0" do
    g = Classic.empty(1)
    assert Health.eccentricity(g, 0, opts()) == 0
  end

  test "eccentricity returns nil for unreachable nodes" do
    g = Yog.Operation.disjoint_union(Classic.path(3), Classic.path(3))
    assert Health.eccentricity(g, 0, opts()) == nil
  end

  # ============= Assortativity Tests =============

  test "assortativity of regular graph is 0.0" do
    # Cycle: all nodes have degree 2
    for n <- 3..10 do
      g = Classic.cycle(n)
      assert Health.assortativity(g) == 0.0
    end

    # Complete: all nodes have degree n-1
    for n <- 2..10 do
      g = Classic.complete(n)
      assert Health.assortativity(g) == 0.0
    end

    # Empty: all nodes have degree 0
    for n <- 1..5 do
      g = Classic.empty(n)
      assert Health.assortativity(g) == 0.0
    end
  end

  test "assortativity of star graph is negative" do
    for n <- 3..10 do
      g = Classic.star(n)
      assert Health.assortativity(g) < 0.0
    end
  end

  test "assortativity of path graph for n > 2 is negative" do
    for n <- 4..10 do
      g = Classic.path(n)
      assert Health.assortativity(g) < 0.0
    end
  end

  test "assortativity of two-edge path is 0.0" do
    g = Classic.path(2)
    assert Health.assortativity(g) == 0.0
  end

  # ============= Average Path Length Tests =============

  test "average_path_length of complete graph K_n is 1.0" do
    for n <- 2..10 do
      g = Classic.complete(n)
      apl = Health.average_path_length(g, opts())
      assert_in_delta apl, 1.0, 0.0001
    end
  end

  test "average_path_length of star graph S_n is 2 - 2/n" do
    for n <- 2..10 do
      g = Classic.star(n)
      apl = Health.average_path_length(g, opts())
      assert_in_delta apl, 2.0 - 2.0 / n, 0.0001
    end
  end

  test "average_path_length of path graph P_n is (n+1)/3" do
    for n <- 2..10 do
      g = Classic.path(n)
      apl = Health.average_path_length(g, opts())
      assert_in_delta apl, (n + 1) / 3.0, 0.0001
    end
  end

  test "average_path_length of empty graph is nil" do
    for n <- 0..1 do
      g = Classic.empty(n)
      assert Health.average_path_length(g, opts()) == nil
    end
  end

  test "average_path_length of disconnected graph is nil" do
    g = Yog.Operation.disjoint_union(Classic.path(3), Classic.path(3))
    assert Health.average_path_length(g, opts()) == nil
  end

  test "average_path_length of 2x2 grid is 4/3" do
    g = Classic.grid_2d(2, 2)
    apl = Health.average_path_length(g, opts())
    assert_in_delta apl, 4.0 / 3.0, 0.0001
  end

  test "average_path_length of single node is nil" do
    g = Classic.path(1)
    assert Health.average_path_length(g, opts()) == nil
  end

  # ============= Efficiency Tests =============

  test "efficiency of adjacent nodes is 1.0" do
    g = Classic.path(3)
    assert_in_delta Health.efficiency(g, 0, 1, opts()), 1.0, 0.0001
  end

  test "efficiency of distant nodes is inverse of distance" do
    g = Classic.path(4)
    assert_in_delta Health.efficiency(g, 0, 3, opts()), 1.0 / 3.0, 0.0001
  end

  test "efficiency of unreachable nodes is 0.0" do
    g = Yog.Operation.disjoint_union(Classic.path(3), Classic.path(3))
    assert Health.efficiency(g, 0, 3, opts()) == 0.0
  end

  test "efficiency of node to itself is 0.0" do
    g = Classic.path(3)
    assert Health.efficiency(g, 1, 1, opts()) == 0.0
  end

  test "global_efficiency of complete graph K_n is 1.0" do
    for n <- 2..10 do
      g = Classic.complete(n)
      assert_in_delta Health.global_efficiency(g, opts()), 1.0, 0.0001
    end
  end

  test "global_efficiency of disconnected graph is well-defined" do
    g = Yog.Operation.disjoint_union(Classic.path(3), Classic.path(3))
    ge = Health.global_efficiency(g, opts())
    assert ge > 0.0
    assert ge < 1.0
  end

  test "global_efficiency of empty graph is 0.0" do
    g = Classic.empty(0)
    assert Health.global_efficiency(g, opts()) == 0.0
  end

  test "global_efficiency of single node is 0.0" do
    g = Classic.empty(1)
    assert Health.global_efficiency(g, opts()) == 0.0
  end

  test "local_efficiency of node with 0 neighbors is 0.0" do
    g = Classic.empty(1)
    assert Health.local_efficiency(g, 0, opts()) == 0.0
  end

  test "local_efficiency of leaf node is 0.0" do
    g = Classic.star(4)
    assert Health.local_efficiency(g, 1, opts()) == 0.0
  end

  test "local_efficiency of center in star is 0.0" do
    g = Classic.star(4)
    assert Health.local_efficiency(g, 0, opts()) == 0.0
  end

  test "average_local_efficiency of complete graph K_n is 1.0 for n >= 3" do
    for n <- 3..10 do
      g = Classic.complete(n)
      assert_in_delta Health.average_local_efficiency(g, opts()), 1.0, 0.0001
    end
  end

  test "average_local_efficiency of K_2 is 0.0" do
    g = Classic.complete(2)
    assert Health.average_local_efficiency(g, opts()) == 0.0
  end

  test "average_local_efficiency of empty graph is 0.0" do
    g = Classic.empty(0)
    assert Health.average_local_efficiency(g, opts()) == 0.0
  end
end
