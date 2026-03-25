defmodule Yog.PBT.CentralityTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Centrality Properties" do
    property "Star Graph: Center node has strictly highest centrality" do
      check all({graph, center, leaves} <- star_graph_gen()) do
        degree = Yog.Centrality.degree_total(graph)
        closeness = Yog.Centrality.closeness(graph)
        betweenness = Yog.Centrality.betweenness(graph)
        pagerank = Yog.Centrality.pagerank(graph, max_iterations: 200)
        eigenvector = Yog.Centrality.eigenvector(graph, max_iterations: 200)

        for leaf <- leaves do
          assert degree[center] > degree[leaf]
          assert closeness[center] > closeness[leaf]
          assert betweenness[center] > betweenness[leaf]
          assert pagerank[center] > pagerank[leaf]
          assert eigenvector[center] > eigenvector[leaf]
        end
      end
    end

    property "PageRank scores sum to 1.0 (Unity Law)" do
      check all(graph <- graph_gen()) do
        scores = Yog.Centrality.pagerank(graph)
        sum = Enum.sum(Map.values(scores))
        assert_in_delta sum, 1.0, 0.01
      end
    end
  end
end
