defmodule Yog.PBT.CommunityTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Community Properties" do
    property "Louvain: Partitioning nodes into sets" do
      check all(graph <- undirected_graph_gen()) do
        result = Yog.Community.Louvain.detect(graph)
        verify_partition(graph, result)
      end
    end

    property "Leiden: Partitioning nodes into sets" do
      check all(graph <- undirected_graph_gen()) do
        result = Yog.Community.Leiden.detect(graph)
        verify_partition(graph, result)
      end
    end

    property "Label Propagation: Partitioning nodes into sets" do
      check all(graph <- undirected_graph_gen()) do
        result = Yog.Community.LabelPropagation.detect(graph)
        verify_partition(graph, result)
      end
    end

    property "Fluid Communities: Partitioning" do
      check all(graph <- undirected_graph_gen()) do
        # Fluid requires k=2 by default
        result = Yog.Community.FluidCommunities.detect(graph)
        verify_partition(graph, result)
      end
    end

    property "Infomap: Partitioning nodes into sets" do
      # Infomap uses random walks/PageRank which requires non-negative weights
      # Filter out graphs with negative or zero weights
      check all(graph <- directed_graph_gen()) do
        # Skip graphs with invalid weights for random walk algorithms
        has_valid_weights =
          Yog.all_nodes(graph)
          |> Enum.all?(fn node ->
            Yog.Model.successors(graph, node)
            |> Enum.all?(fn {_, weight} -> weight > 0 end)
          end)

        if has_valid_weights do
          result = Yog.Community.Infomap.detect(graph)
          verify_partition(graph, result)
        end
      end
    end

    property "Walktrap: Partitioning nodes into sets" do
      check all(graph <- graph_gen()) do
        result = Yog.Community.Walktrap.detect(graph)
        verify_partition(graph, result)
      end
    end

    property "Clique Percolation: Overlapping partitioning" do
      check all(graph <- undirected_graph_gen()) do
        overlapping = Yog.Community.CliquePercolation.detect_overlapping(graph)
        # Verify overlapping structure
        all_nodes = Yog.all_nodes(graph) |> MapSet.new()

        # Nodes that are in at least one k-clique (k=3) are in memberships
        # Nodes not in any 3-clique may be missing from memberships in CPM
        assigned_nodes = Map.keys(overlapping.memberships) |> MapSet.new()
        assert MapSet.subset?(assigned_nodes, all_nodes)

        # Verify conversion to non-overlapping Result
        result = Yog.Community.CliquePercolation.to_communities(overlapping)
        # CPM result.assignments might not cover all nodes if they aren't part of any 3-clique
        # However, it should be a valid partial assignment
        case map_size(result.assignments) do
          0 ->
            :ok

          _ ->
            ids = Map.values(result.assignments) |> Enum.uniq()
            assert result.num_communities >= length(ids)
        end
      end
    end

    property "Local Community: Extracting community around a seed" do
      check all(
              graph <- undirected_graph_gen(),
              nodes = Yog.all_nodes(graph),
              length(nodes) > 0,
              seed <- StreamData.member_of(nodes)
            ) do
        community = Yog.Community.LocalCommunity.detect(graph, seeds: [seed])
        assert MapSet.member?(community, seed)

        # All members must be in the graph
        all_nodes = MapSet.new(nodes)
        assert MapSet.subset?(community, all_nodes)
      end
    end

    property "Girvan-Newman: Partitioning" do
      # Small graphs for GN because it's expensive (O(E^2V))
      check all(
              nodes <- node_list_gen(2, 10, 50),
              weights <- weight_list_gen(length(nodes), 0..100)
            ) do
        graph = build_graph(:undirected, nodes, weights)
        result = Yog.Community.GirvanNewman.detect(graph)
        verify_partition(graph, result)
      end
    end

    property "Clique Detection: Separate components should stay separated" do
      # Two disjoint cliques should yield at least 2 communities
      check all(graph <- disjoint_cliques_gen(2)) do
        r_louvain = Yog.Community.Louvain.detect(graph)
        r_lp = Yog.Community.LabelPropagation.detect(graph)

        # Louvain is robust
        assert r_louvain.num_communities >= 2

        # Label propagation might converge slowly, but should usually separate disjoint components 
        assert r_lp.num_communities >= 2
      end
    end
  end

  defp verify_partition(graph, result) do
    all_nodes = Yog.all_nodes(graph) |> MapSet.new()
    assigned_nodes = Map.keys(result.assignments) |> MapSet.new()

    # 1. Coverage
    assert MapSet.equal?(all_nodes, assigned_nodes)

    # 2. Each node in exactly one community (Implicit in Map)

    # 3. Community ID consistency
    ids = Map.values(result.assignments) |> Enum.uniq()
    assert result.num_communities == length(ids)
  end
end
