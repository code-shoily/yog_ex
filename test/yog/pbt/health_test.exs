defmodule Yog.PBT.HealthTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yog.Generator.Classic
  alias Yog.Health

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

  describe "Distance Metric Properties" do
    property "diameter of path P_n is n-1" do
      check all(n <- StreamData.integer(2..30)) do
        g = Classic.path(n)
        assert Health.diameter(g, opts()) == n - 1
      end
    end

    property "radius of path P_n is floor(n/2) for n >= 2" do
      check all(n <- StreamData.integer(2..30)) do
        g = Classic.path(n)
        assert Health.radius(g, opts()) == div(n, 2)
      end
    end

    property "diameter of cycle C_n is floor(n/2)" do
      check all(n <- StreamData.integer(3..30)) do
        g = Classic.cycle(n)
        assert Health.diameter(g, opts()) == div(n, 2)
      end
    end

    property "diameter equals radius for complete graph K_n" do
      check all(n <- StreamData.integer(2..20)) do
        g = Classic.complete(n)
        d = Health.diameter(g, opts())
        r = Health.radius(g, opts())
        assert d == 1
        assert r == 1
        assert d == r
      end
    end

    property "eccentricity in complete graph K_n is always 1" do
      check all(
              n <- StreamData.integer(2..15),
              node <- StreamData.integer(0..(n - 1))
            ) do
        g = Classic.complete(n)
        assert Health.eccentricity(g, node, opts()) == 1
      end
    end

    property "diameter of empty graph (0 nodes) is nil" do
      check all(_ <- StreamData.constant(nil)) do
        g = Classic.empty(0)
        assert Health.diameter(g, opts()) == nil
      end
    end

    property "radius of empty graph (0 nodes) is nil" do
      check all(_ <- StreamData.constant(nil)) do
        g = Classic.empty(0)
        assert Health.radius(g, opts()) == nil
      end
    end
  end

  describe "Assortativity Properties" do
    property "regular graphs have assortativity 0.0" do
      check all(n <- StreamData.integer(3..20)) do
        g = Classic.cycle(n)
        assert Health.assortativity(g) == 0.0
      end
    end

    property "star graph has negative assortativity" do
      check all(n <- StreamData.integer(3..20)) do
        g = Classic.star(n)
        assert Health.assortativity(g) < 0.0
      end
    end

    property "empty graph has assortativity 0.0" do
      check all(n <- StreamData.integer(0..10)) do
        g = Classic.empty(n)
        assert Health.assortativity(g) == 0.0
      end
    end
  end

  describe "Average Path Length Properties" do
    property "average_path_length of complete graph K_n is 1.0" do
      check all(n <- StreamData.integer(2..20)) do
        g = Classic.complete(n)
        apl = Health.average_path_length(g, opts())
        assert_in_delta apl, 1.0, 0.0001
      end
    end

    property "average_path_length of star S_n is 2 - 2/n" do
      check all(n <- StreamData.integer(2..20)) do
        g = Classic.star(n)
        apl = Health.average_path_length(g, opts())
        assert_in_delta apl, 2.0 - 2.0 / n, 0.0001
      end
    end

    property "average_path_length of empty graph is nil" do
      check all(n <- StreamData.integer(0..10)) do
        g = Classic.empty(n)
        assert Health.average_path_length(g, opts()) == nil
      end
    end

    property "average_path_length of disconnected graph is nil" do
      check all(
              n1 <- StreamData.integer(2..10),
              n2 <- StreamData.integer(2..10)
            ) do
        g1 = Classic.path(n1)
        g2 = Classic.path(n2)
        g = Yog.Operation.disjoint_union(g1, g2)
        assert Health.average_path_length(g, opts()) == nil
      end
    end
  end
end
