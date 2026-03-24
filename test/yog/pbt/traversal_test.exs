defmodule Yog.PBT.TraversalTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Traversal Properties" do
    property "BFS visits each reachable node exactly once" do
      check all(
              graph <- graph_gen(),
              nodes = Yog.all_nodes(graph),
              start_node <- StreamData.member_of(nodes)
            ) do
        visited =
          Yog.fold_walk(graph, start_node, :breadth_first, [], fn acc, node, _metadata ->
            {Yog.continue(), [node | acc]}
          end)

        assert length(visited) == length(Enum.uniq(visited))
      end
    end
  end
end
