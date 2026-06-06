defmodule Yog.Connectivity.KCoreTest do
  use ExUnit.Case, async: true
  doctest Yog.Connectivity.KCore

  test "k-core algorithms raise ArgumentError for directed graphs" do
    graph = Yog.directed() |> Yog.add_node(1) |> Yog.add_node(2)

    assert_raise ArgumentError, ~r/requires an undirected graph/, fn ->
      Yog.Connectivity.KCore.detect(graph, 2)
    end

    assert_raise ArgumentError, ~r/requires an undirected graph/, fn ->
      Yog.Connectivity.KCore.core_numbers(graph)
    end
  end
end
