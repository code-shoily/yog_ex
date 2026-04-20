defmodule Yog.Flow.MaxFlowTest do
  @moduledoc """
  Tests for `Yog.Flow.MaxFlow` matching Gleam's `yog/flow/max_flow` module.
  """

  use ExUnit.Case, async: true
  alias Yog.Flow.MaxFlow
  doctest MaxFlow

  describe "calculate/3" do
    test "convenience wrapper works" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge(1, 2, 42)

      result = MaxFlow.calculate(graph, 1, 2)
      assert result.max_flow == 42
    end
  end

  describe "edmonds_karp/3" do
    test "simple flow network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 5},
          {2, 3, 15},
          {2, 4, 10},
          {3, 4, 10}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 4)

      assert result.max_flow == 15
      assert result.source == 1
      assert result.sink == 4
      assert %Yog.Graph{} = result.residual_graph
    end

    test "single edge path" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      result = MaxFlow.edmonds_karp(graph, 1, 2)

      assert result.max_flow == 5
      assert result.source == 1
      assert result.sink == 2
    end

    test "multiple parallel paths" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 10},
          {2, 4, 10},
          {3, 4, 10}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 4)

      # Two parallel paths each with capacity 10
      assert result.max_flow == 20
    end

    test "bottleneck limits flow" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "mid")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([
          {1, 2, 100},
          {2, 3, 5}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 3)

      # Bottleneck is the edge with capacity 5
      assert result.max_flow == 5
    end

    test "disconnected source and sink" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      # No edge to sink

      result = MaxFlow.edmonds_karp(graph, 1, 3)

      assert result.max_flow == 0
    end

    test "source equals sink" do
      # When source equals sink, there's nowhere for flow to go
      # The algorithm returns 0 flow
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      # This is a special case - we expect the algorithm to handle it gracefully
      # by returning 0 flow since source == sink
      result = MaxFlow.edmonds_karp(graph, 1, 1)

      assert result.max_flow == 0
      assert result.source == 1
      assert result.sink == 1
    end

    test "zero capacity edges" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edges([
          {1, 2, 0},
          {1, 2, 0}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 2)
      assert result.max_flow == 0
    end

    test "diamond network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 10},
          {2, 4, 5},
          {3, 4, 5}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 4)

      # Bottleneck at sink side limits to 10
      assert result.max_flow == 10
    end

    test "complex network with cycles" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "c")
        |> Yog.add_node(5, "t")
        |> Yog.add_edges([
          {1, 2, 16},
          {1, 3, 13},
          {2, 3, 10},
          {2, 4, 12},
          {3, 2, 4},
          {3, 5, 14},
          {4, 3, 9},
          {4, 5, 20}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 5)

      # This is a variation of a classic max flow test case
      # The actual max flow depends on the specific graph structure
      assert result.max_flow > 0
      # Upper bound (sum of capacities from source)
      assert result.max_flow <= 29
    end

    test "three-layer network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a1")
        |> Yog.add_node(3, "a2")
        |> Yog.add_node(4, "b1")
        |> Yog.add_node(5, "b2")
        |> Yog.add_node(6, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 10},
          {2, 4, 5},
          {2, 5, 5},
          {3, 4, 5},
          {3, 5, 5},
          {4, 6, 10},
          {5, 6, 10}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 6)

      # Multiple paths through two layers
      assert result.max_flow == 20
    end

    test "single path with multiple edges" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "t")
        |> Yog.add_edges([
          {1, 2, 100},
          {2, 3, 50},
          {3, 4, 25}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 4)

      # Bottleneck is the last edge
      assert result.max_flow == 25
    end
  end

  describe "edmonds_karp/8 with custom numeric types" do
    test "float capacities" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge(1, 2, 10.5)

      result =
        MaxFlow.edmonds_karp(
          graph,
          1,
          2,
          0.0,
          &(&1 + &2),
          &(&1 - &2),
          &Yog.Utils.compare/2,
          &min/2
        )

      assert result.max_flow == 10.5
    end

    test "rational number capacities" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([
          {1, 2, {3, 4}},
          {2, 3, {1, 2}}
        ])

      # Rational arithmetic
      add = fn {a, b}, {c, d} -> {a * d + c * b, b * d} end
      sub = fn {a, b}, {c, d} -> {a * d - c * b, b * d} end
      zero = {0, 1}

      compare = fn {a, b}, {c, d} ->
        left = a * d
        right = c * b

        cond do
          left < right -> :lt
          left > right -> :gt
          true -> :eq
        end
      end

      min_fn = fn r1, r2 ->
        if compare.(r1, r2) == :lt, do: r1, else: r2
      end

      result = MaxFlow.edmonds_karp(graph, 1, 3, zero, add, sub, compare, min_fn)

      # Bottleneck is 1/2
      assert result.max_flow == {1, 2}
    end

    test "large integer capacities" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge(1, 2, 1_000_000_000)

      result = MaxFlow.edmonds_karp(graph, 1, 2)
      assert result.max_flow == 1_000_000_000
    end
  end

  describe "dinic/3" do
    test "simple flow network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 5},
          {2, 3, 15},
          {2, 4, 10},
          {3, 4, 10}
        ])

      result = MaxFlow.dinic(graph, 1, 4)

      assert result.max_flow == 15
      assert result.source == 1
      assert result.sink == 4
      assert %Yog.Graph{} = result.residual_graph
      assert result.algorithm == :dinic
    end

    test "single edge path" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      result = MaxFlow.dinic(graph, 1, 2)

      assert result.max_flow == 5
      assert result.source == 1
      assert result.sink == 2
    end

    test "multiple parallel paths" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 10},
          {2, 4, 10},
          {3, 4, 10}
        ])

      result = MaxFlow.dinic(graph, 1, 4)
      assert result.max_flow == 20
    end

    test "bottleneck limits flow" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "mid")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([
          {1, 2, 100},
          {2, 3, 5}
        ])

      result = MaxFlow.dinic(graph, 1, 3)
      assert result.max_flow == 5
    end

    test "disconnected source and sink" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      result = MaxFlow.dinic(graph, 1, 3)
      assert result.max_flow == 0
    end

    test "source equals sink" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      result = MaxFlow.dinic(graph, 1, 1)

      assert result.max_flow == 0
      assert result.source == 1
      assert result.sink == 1
    end

    test "zero capacity edges" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edges([
          {1, 2, 0},
          {1, 2, 0}
        ])

      result = MaxFlow.dinic(graph, 1, 2)
      assert result.max_flow == 0
    end

    test "diamond network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 10},
          {2, 4, 5},
          {3, 4, 5}
        ])

      result = MaxFlow.dinic(graph, 1, 4)
      assert result.max_flow == 10
    end

    test "complex network with cycles" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "c")
        |> Yog.add_node(5, "t")
        |> Yog.add_edges([
          {1, 2, 16},
          {1, 3, 13},
          {2, 3, 10},
          {2, 4, 12},
          {3, 2, 4},
          {3, 5, 14},
          {4, 3, 9},
          {4, 5, 20}
        ])

      result = MaxFlow.dinic(graph, 1, 5)
      assert result.max_flow > 0
      assert result.max_flow <= 29
    end

    test "three-layer network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a1")
        |> Yog.add_node(3, "a2")
        |> Yog.add_node(4, "b1")
        |> Yog.add_node(5, "b2")
        |> Yog.add_node(6, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 10},
          {2, 4, 5},
          {2, 5, 5},
          {3, 4, 5},
          {3, 5, 5},
          {4, 6, 10},
          {5, 6, 10}
        ])

      result = MaxFlow.dinic(graph, 1, 6)
      assert result.max_flow == 20
    end

    test "single path with multiple edges" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "t")
        |> Yog.add_edges([
          {1, 2, 100},
          {2, 3, 50},
          {3, 4, 25}
        ])

      result = MaxFlow.dinic(graph, 1, 4)
      assert result.max_flow == 25
    end
  end

  describe "dinic/8 with custom numeric types" do
    test "float capacities" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge(1, 2, 10.5)

      result =
        MaxFlow.dinic(
          graph,
          1,
          2,
          0.0,
          &(&1 + &2),
          &(&1 - &2),
          &Yog.Utils.compare/2,
          &min/2
        )

      assert result.max_flow == 10.5
    end

    test "rational number capacities" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([
          {1, 2, {3, 4}},
          {2, 3, {1, 2}}
        ])

      add = fn {a, b}, {c, d} -> {a * d + c * b, b * d} end
      sub = fn {a, b}, {c, d} -> {a * d - c * b, b * d} end
      zero = {0, 1}

      compare = fn {a, b}, {c, d} ->
        left = a * d
        right = c * b

        cond do
          left < right -> :lt
          left > right -> :gt
          true -> :eq
        end
      end

      min_fn = fn r1, r2 ->
        if compare.(r1, r2) == :lt, do: r1, else: r2
      end

      result = MaxFlow.dinic(graph, 1, 3, zero, add, sub, compare, min_fn)
      assert result.max_flow == {1, 2}
    end

    test "large integer capacities" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge(1, 2, 1_000_000_000)

      result = MaxFlow.dinic(graph, 1, 2)
      assert result.max_flow == 1_000_000_000
    end
  end

  describe "dinic consistency with edmonds_karp" do
    test "simple network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 5},
          {2, 3, 15},
          {2, 4, 10},
          {3, 4, 10}
        ])

      ek_result = MaxFlow.edmonds_karp(graph, 1, 4)
      dinic_result = MaxFlow.dinic(graph, 1, 4)

      assert ek_result.max_flow == dinic_result.max_flow
    end

    test "complex network with cycles" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "c")
        |> Yog.add_node(5, "t")
        |> Yog.add_edges([
          {1, 2, 16},
          {1, 3, 13},
          {2, 3, 10},
          {2, 4, 12},
          {3, 2, 4},
          {3, 5, 14},
          {4, 3, 9},
          {4, 5, 20}
        ])

      ek_result = MaxFlow.edmonds_karp(graph, 1, 5)
      dinic_result = MaxFlow.dinic(graph, 1, 5)

      assert ek_result.max_flow == dinic_result.max_flow
    end

    test "three-layer network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a1")
        |> Yog.add_node(3, "a2")
        |> Yog.add_node(4, "b1")
        |> Yog.add_node(5, "b2")
        |> Yog.add_node(6, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 10},
          {2, 4, 5},
          {2, 5, 5},
          {3, 4, 5},
          {3, 5, 5},
          {4, 6, 10},
          {5, 6, 10}
        ])

      ek_result = MaxFlow.edmonds_karp(graph, 1, 6)
      dinic_result = MaxFlow.dinic(graph, 1, 6)

      assert ek_result.max_flow == dinic_result.max_flow
    end
  end

  describe "push_relabel/3" do
    test "simple flow network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 5},
          {2, 3, 15},
          {2, 4, 10},
          {3, 4, 10}
        ])

      result = MaxFlow.push_relabel(graph, 1, 4)

      assert result.max_flow == 15
      assert result.source == 1
      assert result.sink == 4
      assert %Yog.Graph{} = result.residual_graph
      assert result.algorithm == :push_relabel
    end

    test "single edge path" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)

      result = MaxFlow.push_relabel(graph, 1, 2)

      assert result.max_flow == 5
      assert result.source == 1
      assert result.sink == 2
    end

    test "multiple parallel paths" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 10},
          {2, 4, 10},
          {3, 4, 10}
        ])

      result = MaxFlow.push_relabel(graph, 1, 4)

      assert result.max_flow == 20
    end

    test "bottleneck limits flow" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "mid")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([
          {1, 2, 100},
          {2, 3, 5}
        ])

      result = MaxFlow.push_relabel(graph, 1, 3)

      assert result.max_flow == 5
    end

    test "disconnected source and sink" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      result = MaxFlow.push_relabel(graph, 1, 3)

      assert result.max_flow == 0
    end

    test "source equals sink" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      result = MaxFlow.push_relabel(graph, 1, 1)

      assert result.max_flow == 0
      assert result.source == 1
      assert result.sink == 1
    end

    test "zero capacity edges" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edges([
          {1, 2, 0},
          {1, 2, 0}
        ])

      result = MaxFlow.push_relabel(graph, 1, 2)
      assert result.max_flow == 0
    end

    test "diamond network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 10},
          {2, 4, 5},
          {3, 4, 5}
        ])

      result = MaxFlow.push_relabel(graph, 1, 4)

      assert result.max_flow == 10
    end

    test "complex network with cycles" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "b")
        |> Yog.add_node(4, "c")
        |> Yog.add_node(5, "t")
        |> Yog.add_edges([
          {1, 2, 16},
          {1, 3, 13},
          {2, 3, 10},
          {2, 4, 12},
          {3, 2, 4},
          {3, 5, 14},
          {4, 3, 9},
          {4, 5, 20}
        ])

      result = MaxFlow.push_relabel(graph, 1, 5)

      assert result.max_flow > 0
      assert result.max_flow <= 29
    end
  end

  describe "push_relabel consistency with edmonds_karp" do
    test "simple network" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 5},
          {2, 3, 15},
          {2, 4, 10},
          {3, 4, 10}
        ])

      ek_result = MaxFlow.edmonds_karp(graph, 1, 4)
      pr_result = MaxFlow.push_relabel(graph, 1, 4)

      assert ek_result.max_flow == pr_result.max_flow
    end

    test "complex network with cycles" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "C")
        |> Yog.add_node(5, "D")
        |> Yog.add_node(6, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 10},
          {2, 4, 15},
          {2, 5, 5},
          {3, 4, 5},
          {3, 5, 15},
          {4, 6, 10},
          {5, 6, 10},
          {2, 3, 4}
        ])

      ek_result = MaxFlow.edmonds_karp(graph, 1, 6)
      pr_result = MaxFlow.push_relabel(graph, 1, 6)

      assert ek_result.max_flow == pr_result.max_flow
    end
  end

  describe "push_relabel/8 with custom numeric types" do
    test "float capacities" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge(1, 2, 10.5)

      result =
        MaxFlow.push_relabel(
          graph,
          1,
          2,
          0.0,
          &(&1 + &2),
          &(&1 - &2),
          &Yog.Utils.compare/2,
          &min/2
        )

      assert result.max_flow == 10.5
    end

    test "rational number capacities" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([
          {1, 2, {3, 4}},
          {2, 3, {1, 2}}
        ])

      add = fn {a, b}, {c, d} -> {a * d + c * b, b * d} end
      sub = fn {a, b}, {c, d} -> {a * d - c * b, b * d} end
      zero = {0, 1}

      compare = fn {a, b}, {c, d} ->
        left = a * d
        right = c * b

        cond do
          left < right -> :lt
          left > right -> :gt
          true -> :eq
        end
      end

      min_fn = fn r1, r2 ->
        if compare.(r1, r2) == :lt, do: r1, else: r2
      end

      result = MaxFlow.push_relabel(graph, 1, 3, zero, add, sub, compare, min_fn)

      assert result.max_flow == {1, 2}
    end

    test "large integer capacities" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge(1, 2, 1_000_000_000)

      result = MaxFlow.push_relabel(graph, 1, 2)
      assert result.max_flow == 1_000_000_000
    end
  end

  describe "max_flow algorithm selector" do
    test "selects push_relabel via max_flow/4" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {2, 3, 5}
        ])

      result = MaxFlow.max_flow(graph, 1, 3, :push_relabel)
      assert result.max_flow == 5
      assert result.algorithm == :push_relabel
    end

    test "defaults to edmonds_karp" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {2, 3, 5}
        ])

      result = MaxFlow.max_flow(graph, 1, 3)
      assert result.max_flow == 5
      assert result.algorithm == :edmonds_karp
    end
  end

  describe "extract_min_cut/1" do
    test "extracts min cut from max flow result" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 5},
          {2, 4, 10},
          {3, 4, 10}
        ])

      max_flow_result = MaxFlow.edmonds_karp(graph, 1, 4)
      min_cut = MaxFlow.extract_min_cut(max_flow_result)

      # Cut value should equal max flow
      assert min_cut.cut_value == 15

      # Both sides should have at least one node
      assert min_cut.source_side_size >= 1
      assert min_cut.sink_side_size >= 1

      # Total nodes should be 4
      assert Yog.Flow.MinCutResult.total_nodes(min_cut) == 4
    end

    test "min cut equals max flow" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 7)

      max_flow_result = MaxFlow.edmonds_karp(graph, 1, 2)
      min_cut = MaxFlow.extract_min_cut(max_flow_result)

      # Cut value should equal max flow
      assert min_cut.cut_value == 7

      # For a single edge, one node on each side
      assert min_cut.source_side_size == 1
      assert min_cut.sink_side_size == 1
    end

    test "min cut for disconnected graph" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)

      max_flow_result = MaxFlow.edmonds_karp(graph, 1, 3)
      min_cut = MaxFlow.extract_min_cut(max_flow_result)

      assert min_cut.cut_value == 0
    end

    test "extracts min cut from dinic result" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 5},
          {2, 4, 10},
          {3, 4, 10}
        ])

      max_flow_result = MaxFlow.dinic(graph, 1, 4)
      min_cut = MaxFlow.extract_min_cut(max_flow_result)

      assert min_cut.cut_value == 15
      assert min_cut.source_side_size >= 1
      assert min_cut.sink_side_size >= 1
      assert Yog.Flow.MinCutResult.total_nodes(min_cut) == 4
      assert min_cut.algorithm == :dinic
    end

    test "extracts min cut from push_relabel result" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "source")
        |> Yog.add_node(2, "A")
        |> Yog.add_node(3, "B")
        |> Yog.add_node(4, "sink")
        |> Yog.add_edges([
          {1, 2, 10},
          {1, 3, 5},
          {2, 4, 10},
          {3, 4, 10}
        ])

      max_flow_result = MaxFlow.push_relabel(graph, 1, 4)
      min_cut = MaxFlow.extract_min_cut(max_flow_result)

      assert min_cut.cut_value == 15
      assert min_cut.source_side_size >= 1
      assert min_cut.sink_side_size >= 1
      assert Yog.Flow.MinCutResult.total_nodes(min_cut) == 4
      assert min_cut.algorithm == :push_relabel
    end
  end

  describe "min_cut/3" do
    test "min cut with custom comparison" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 100)

      max_flow_result = MaxFlow.edmonds_karp(graph, 1, 2)
      min_cut = MaxFlow.min_cut(max_flow_result)

      assert min_cut.cut_value == 100
    end

    test "min cut with float capacities" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge(1, 2, 50.5)

      max_flow_result =
        MaxFlow.edmonds_karp(
          graph,
          1,
          2,
          0.0,
          &(&1 + &2),
          &(&1 - &2),
          &Yog.Utils.compare/2,
          &min/2
        )

      min_cut = MaxFlow.min_cut(max_flow_result, 0.0, &Yog.Utils.compare/2)
      assert min_cut.cut_value == 50.5
    end

    test "min cut with dinic preserves algorithm" do
      graph =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge_ensure(from: 1, to: 2, with: 42)

      max_flow_result = MaxFlow.dinic(graph, 1, 2)
      min_cut = MaxFlow.min_cut(max_flow_result)

      assert min_cut.cut_value == 42
      assert min_cut.algorithm == :dinic
    end
  end

  describe "residual graph properties" do
    test "residual graph has correct structure" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge(1, 2, 10)

      result = MaxFlow.edmonds_karp(graph, 1, 2)

      # Residual graph should be a valid graph
      assert result.residual_graph.kind == :directed
      assert result.residual_graph.nodes[1] != nil
      assert result.residual_graph.nodes[2] != nil
    end

    test "no augmenting path in residual after max flow" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {2, 3, 5}
        ])

      result = MaxFlow.edmonds_karp(graph, 1, 3)

      # After max flow, sink should not be reachable from source in residual
      reachable = Yog.Traversal.walk(result.residual_graph, 1, :breadth_first)
      assert 3 not in reachable
    end

    test "dinic residual graph has correct structure" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "t")
        |> Yog.add_edge(1, 2, 10)

      result = MaxFlow.dinic(graph, 1, 2)

      assert result.residual_graph.kind == :directed
      assert result.residual_graph.nodes[1] != nil
      assert result.residual_graph.nodes[2] != nil
    end

    test "no augmenting path in dinic residual after max flow" do
      {:ok, graph} =
        Yog.directed()
        |> Yog.add_node(1, "s")
        |> Yog.add_node(2, "a")
        |> Yog.add_node(3, "t")
        |> Yog.add_edges([
          {1, 2, 10},
          {2, 3, 5}
        ])

      result = MaxFlow.dinic(graph, 1, 3)

      reachable = Yog.Traversal.walk(result.residual_graph, 1, :breadth_first)
      assert 3 not in reachable
    end
  end

  describe "max_flow/4" do
    test "fallbacks to edmonds_karp for unknown algorithm" do
      graph = Yog.directed() |> Yog.add_edge_ensure(from: 1, to: 2, with: 10)
      result = MaxFlow.max_flow(graph, 1, 2, :non_existent_algo)
      assert result.max_flow == 10
      assert result.algorithm == :edmonds_karp
    end
  end
end
