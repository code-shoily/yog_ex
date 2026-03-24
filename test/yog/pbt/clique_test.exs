defmodule Yog.PBT.CliqueTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Property Properties: Clique" do
    property "disjoint_cliques_gen produces expected cliques" do
      check all(graph <- disjoint_cliques_gen(2, 3..4)) do
        all_cliques = Yog.Property.Clique.all_maximal_cliques(graph)
        max_clique = Yog.Property.Clique.max_clique(graph)

        assert length(all_cliques) == 2
        assert MapSet.size(max_clique) >= 3
      end
    end
  end
end
