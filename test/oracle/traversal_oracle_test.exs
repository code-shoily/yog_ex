defmodule Yog.Oracle.TraversalTest do
  @moduledoc """
  Oracle parity tests for traversal algorithms against NetworkX.
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
  # Generators
  # ---------------------------------------------------------------------------

  @doc """
  Generates a random directed acyclic graph (DAG).
  Nodes are ordered by a random permutation; edges only go from
  earlier to later in the permutation, guaranteeing acyclicity.
  """
  def dag_gen do
    gen all(
          nodes <- Yog.Generators.node_list_gen(1, 15),
          edge_prob <- StreamData.float(min: 0.2, max: 0.8)
        ) do
      order = Enum.shuffle(nodes)
      pos = Enum.with_index(order) |> Map.new()

      graph = Enum.reduce(nodes, Yog.directed(), fn id, g -> Yog.add_node(g, id, nil) end)

      edges =
        for u <- nodes,
            v <- nodes,
            u != v,
            Map.get(pos, u) < Map.get(pos, v),
            :rand.uniform() <= edge_prob,
            do: {u, v}

      Enum.reduce(edges, graph, fn {u, v}, g ->
        case Yog.add_edge(g, u, v, 1) do
          {:ok, new_g} -> new_g
          {:error, _} -> g
        end
      end)
    end
  end

  @doc """
  Generates a random directed graph (may contain cycles).
  """
  def directed_graph_gen do
    gen all(
          nodes <- Yog.Generators.node_list_gen(1, 15),
          edges <- Yog.Generators.weight_list_gen(length(nodes))
        ) do
      Yog.Generators.build_graph(:directed, nodes, edges)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp bfs_layers(graph, source) do
    layers =
      Yog.Traversal.fold_walk(
        over: graph,
        from: source,
        using: :breadth_first,
        initial: %{},
        with: fn acc, node_id, meta ->
          {:continue, Map.update(acc, meta.depth, [node_id], &[node_id | &1])}
        end
      )

    layers
    |> Enum.map(fn {d, nodes} -> {d, Enum.sort(nodes)} end)
    |> Enum.sort_by(fn {d, _} -> d end)
    |> Enum.map(fn {_, nodes} -> nodes end)
  end

  defp dag_from_graph(graph) do
    case Yog.DAG.Model.from_graph(graph) do
      {:ok, dag} -> dag
      {:error, _} -> nil
    end
  end

  defp assert_layers_equal(yog_layers, nx_layers) do
    assert length(yog_layers) == length(nx_layers)

    Enum.zip(yog_layers, nx_layers)
    |> Enum.each(fn {yog_layer, nx_layer} ->
      assert Enum.sort(yog_layer) == Enum.sort(nx_layer)
    end)
  end

  # ---------------------------------------------------------------------------
  # BFS layers
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-TRAV-001 BFS layers agree with NetworkX" do
    check all(
            graph <- directed_graph_gen(),
            nodes = Yog.Model.all_nodes(graph),
            source <- StreamData.member_of(nodes),
            max_runs: 50
          ) do
      yog_layers = bfs_layers(graph, source)
      nx_layers = NetworkX.run("bfs_layers", graph, %{"source" => source})

      assert_layers_equal(yog_layers, nx_layers)
    end
  end

  # ---------------------------------------------------------------------------
  # Lexicographical topological sort
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-TRAV-002 Lexicographical topological sort agrees with NetworkX" do
    check all(
            graph <- dag_gen(),
            max_runs: 50
          ) do
      compare = fn _a, _b -> :eq end
      {:ok, yog_order} = Yog.Traversal.lexicographical_topological_sort(graph, compare)
      nx_order = NetworkX.run("lexicographical_topological_sort", graph, [])

      assert yog_order == nx_order
    end
  end

  # ---------------------------------------------------------------------------
  # Topological generations
  # ---------------------------------------------------------------------------

  @tag :oracle
  property "P-ORAC-TRAV-003 Topological generations agree with NetworkX" do
    check all(
            graph <- dag_gen(),
            max_runs: 50
          ) do
      dag = dag_from_graph(graph)
      yog_gens = Yog.DAG.Algorithm.topological_generations(dag)
      nx_gens = NetworkX.run("topological_generations", graph, [])

      assert_layers_equal(yog_gens, nx_gens)
    end
  end
end
