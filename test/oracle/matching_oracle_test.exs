defmodule Yog.Oracle.MatchingTest do
  @moduledoc """
  Oracle parity tests for matching algorithms against NetworkX.
  """
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Yog.Oracle.NetworkX

  setup_all do
    case NetworkX.adapter_health() do
      :ok ->
        :ok

      {:error, reason} ->
        {:skip, "NetworkX adapter not healthy: #{inspect(reason)}"}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp matching_size(matching) when is_map(matching), do: div(map_size(matching), 2)

  # ---------------------------------------------------------------------------
  # Generators
  # ---------------------------------------------------------------------------

  @doc """
  Generates a random bipartite undirected graph.
  Nodes are partitioned into `left = 1..left_size` and `right = left_size+1..left_size+right_size`.
  Edges only go between the two partitions.
  """
  def bipartite_graph_gen do
    gen all(
          left_size <- StreamData.integer(0..12),
          right_size <- StreamData.integer(0..12),
          edge_keep <- StreamData.list_of(StreamData.boolean(), length: left_size * right_size)
        ) do
      left = if left_size > 0, do: Enum.to_list(1..left_size), else: []

      right =
        if right_size > 0, do: Enum.to_list((left_size + 1)..(left_size + right_size)), else: []

      graph =
        Enum.reduce(left ++ right, Yog.undirected(), fn id, g -> Yog.add_node(g, id, nil) end)

      candidates = for u <- left, v <- right, do: {u, v}

      Enum.zip(candidates, edge_keep)
      |> Enum.reduce(graph, fn {{u, v}, keep}, acc ->
        if keep do
          case Yog.add_edge(acc, u, v, 1) do
            {:ok, new_g} -> new_g
            {:error, _} -> acc
          end
        else
          acc
        end
      end)
    end
  end

  @doc """
  Generates a complete bipartite undirected graph with random integer weights.
  """
  def complete_bipartite_weighted_gen do
    gen all(
          left_size <- StreamData.integer(1..6),
          right_size <- StreamData.integer(1..6),
          weights <-
            StreamData.list_of(StreamData.integer(1..100), length: left_size * right_size)
        ) do
      left = Enum.to_list(1..left_size)
      right = Enum.to_list((left_size + 1)..(left_size + right_size))

      graph =
        Enum.reduce(left ++ right, Yog.undirected(), fn id, g -> Yog.add_node(g, id, nil) end)

      {graph, _} =
        Enum.reduce(left, {graph, weights}, fn u, {g, ws} ->
          Enum.reduce(right, {g, ws}, fn v, {acc, [w | rest]} ->
            {:ok, new_g} = Yog.add_edge(acc, u, v, w)
            {new_g, rest}
          end)
        end)

      graph
    end
  end

  # ---------------------------------------------------------------------------
  # Hopcroft-Karp (bipartite maximum matching)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-MATCH-001 Hopcroft-Karp cardinality agrees with NetworkX" do
    check all(
            graph <- bipartite_graph_gen(),
            max_runs: 50
          ) do
      yog_result = Yog.Matching.hopcroft_karp(graph)
      nx_result = NetworkX.run("hopcroft_karp", graph, [])

      assert matching_size(yog_result) == nx_result
    end
  end

  # ---------------------------------------------------------------------------
  # Edmonds' Blossom (general maximum matching)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-MATCH-002 Blossom maximum matching cardinality agrees with NetworkX" do
    check all(
            nodes <- Yog.Generators.node_list_gen(0, 20),
            edges <- Yog.Generators.weight_list_gen(length(nodes)),
            graph = Yog.Generators.build_graph(:undirected, nodes, edges),
            max_runs: 50
          ) do
      yog_result = Yog.Matching.blossom_maximum_matching(graph)
      nx_result = NetworkX.run("blossom_maximum_matching", graph, [])

      assert matching_size(yog_result) == nx_result
    end
  end

  # ---------------------------------------------------------------------------
  # Hungarian (minimum weight perfect matching in bipartite graphs)
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-MATCH-003 Hungarian minimum weight agrees with NetworkX" do
    check all(
            graph <- complete_bipartite_weighted_gen(),
            max_runs: 30
          ) do
      {yog_cost, _yog_matching} = Yog.Matching.hungarian(graph, :min)
      nx_result = NetworkX.run("minimum_weight_full_matching", graph, %{"optimization" => "min"})

      assert yog_cost == nx_result
    end
  end

  @tag :oracle
  property "P-ORAC-MATCH-004 Hungarian maximum weight agrees with NetworkX" do
    check all(
            graph <- complete_bipartite_weighted_gen(),
            max_runs: 30
          ) do
      {yog_cost, _yog_matching} = Yog.Matching.hungarian(graph, :max)
      nx_result = NetworkX.run("minimum_weight_full_matching", graph, %{"optimization" => "max"})

      assert yog_cost == nx_result
    end
  end
end
