defmodule Yog.CentralitySmokeTest do
  @moduledoc """
  Regression guard against centrality functions that raise on default
  opts across canonical graph shapes.

  Triggered by the Katz `KeyError` bug (commit history: "fix(centrality):
  default Katz alpha to 0.1") — `Yog.Centrality.katz/1` had `opts \\\\ []`
  in its signature but `Keyword.fetch!(opts, :alpha)` in its body, so
  every call with no opts crashed. No existing test caught it because
  the doctest always passed `alpha: 0.1` explicitly.

  This file does NOT check numeric correctness. That belongs to
  `test/yog/centrality_test.exs` (unit tests),
  `test/yog/pbt/centrality_test.exs` (properties), and
  `test/oracle/centrality_oracle_test.exs` (NetworkX parity).

  It only asserts: every public centrality function, called with no
  opts, on a battery of canonical graph shapes, returns a map without
  raising.
  """
  use ExUnit.Case, async: true

  defp shape(:connected_undirected) do
    g = Yog.undirected()
    g = Enum.reduce(1..5, g, &Yog.add_node(&2, &1, nil))

    Enum.reduce([{1, 2}, {2, 3}, {3, 4}, {4, 5}, {1, 5}, {2, 4}, {1, 3}], g, fn {u, v}, acc ->
      {:ok, ng} = Yog.add_edge(acc, u, v, 1)
      ng
    end)
  end

  defp shape(:connected_directed_cyclic) do
    g = Yog.directed()
    g = Enum.reduce(1..5, g, &Yog.add_node(&2, &1, nil))

    Enum.reduce([{1, 2}, {2, 3}, {3, 4}, {4, 5}, {5, 1}, {1, 3}, {4, 2}], g, fn {u, v}, acc ->
      {:ok, ng} = Yog.add_edge(acc, u, v, 1)
      ng
    end)
  end

  defp shape(:dag) do
    g = Yog.directed()
    g = Enum.reduce(1..5, g, &Yog.add_node(&2, &1, nil))

    Enum.reduce([{1, 2}, {1, 3}, {2, 4}, {3, 4}, {4, 5}, {2, 5}], g, fn {u, v}, acc ->
      {:ok, ng} = Yog.add_edge(acc, u, v, 1)
      ng
    end)
  end

  defp shape(:disconnected_undirected) do
    g = Yog.undirected()
    g = Enum.reduce(1..6, g, &Yog.add_node(&2, &1, nil))

    Enum.reduce([{1, 2}, {2, 3}, {4, 5}, {5, 6}], g, fn {u, v}, acc ->
      {:ok, ng} = Yog.add_edge(acc, u, v, 1)
      ng
    end)
  end

  defp shape(:bipartite_undirected) do
    g = Yog.undirected()
    g = Enum.reduce(1..6, g, &Yog.add_node(&2, &1, nil))

    Enum.reduce([{1, 4}, {1, 5}, {2, 4}, {2, 6}, {3, 5}, {3, 6}], g, fn {u, v}, acc ->
      {:ok, ng} = Yog.add_edge(acc, u, v, 1)
      ng
    end)
  end

  defp shape(:with_dangling_node) do
    g = Yog.directed()
    g = Enum.reduce(1..5, g, &Yog.add_node(&2, &1, nil))

    Enum.reduce([{1, 2}, {2, 3}, {3, 1}, {1, 5}, {2, 5}], g, fn {u, v}, acc ->
      {:ok, ng} = Yog.add_edge(acc, u, v, 1)
      ng
    end)
  end

  @shapes [
    :connected_undirected,
    :connected_directed_cyclic,
    :dag,
    :disconnected_undirected,
    :bipartite_undirected,
    :with_dangling_node
  ]

  @algorithms [
    {:degree, &Yog.Centrality.degree/1},
    {:closeness, &Yog.Centrality.closeness/1},
    {:harmonic, &Yog.Centrality.harmonic/1},
    {:betweenness, &Yog.Centrality.betweenness/1},
    {:pagerank, &Yog.Centrality.pagerank/1},
    {:hits, &Yog.Centrality.hits/1},
    {:katz, &Yog.Centrality.katz/1},
    {:eigenvector, &Yog.Centrality.eigenvector/1}
  ]

  for {algo_name, algo_fun} <- @algorithms,
      shape_name <- @shapes do
    test "#{algo_name} on #{shape_name} returns a map without raising" do
      graph = shape(unquote(shape_name))
      result = unquote(algo_fun).(graph)

      assert is_map(result),
             "#{unquote(algo_name)} on #{unquote(shape_name)} returned #{inspect(result, limit: 50)} (expected a map)"
    end
  end
end
