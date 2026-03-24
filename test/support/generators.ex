defmodule Yog.Generators do
  @moduledoc """
  StreamData generators for Yog.Graph.
  """
  use ExUnitProperties

  @doc """
  Generates a random graph.
  """
  def graph_gen do
    gen all(
          kind <- kind_gen(),
          nodes <- node_list_gen(),
          weights <- weight_list_gen(length(nodes))
        ) do
      graph = build_graph(kind, nodes, weights)
      graph
    end
  end

  @doc """
  Generates a random directed graph.
  """
  def directed_graph_gen do
    gen all(
          nodes <- node_list_gen(),
          weights <- weight_list_gen(length(nodes))
        ) do
      build_graph(:directed, nodes, weights)
    end
  end

  @doc """
  Generates a random undirected graph.
  """
  def undirected_graph_gen do
    gen all(
          nodes <- node_list_gen(),
          weights <- weight_list_gen(length(nodes))
        ) do
      build_graph(:undirected, nodes, weights)
    end
  end

  # --- Private Generators ---

  defp kind_gen do
    StreamData.member_of([:directed, :undirected])
  end

  def node_list_gen(min_len \\ 1, max_len \\ 15, max_id \\ 100) do
    # Generate min-max unique nodes with integer IDs
    StreamData.uniq_list_of(StreamData.integer(0..max_id),
      min_length: min_len,
      max_length: max_len
    )
  end

  def small_graph_gen do
    gen all(
          kind <- kind_gen(),
          nodes <- node_list_gen(6, 20),
          weights <- weight_list_gen(length(nodes))
        ) do
      build_graph(kind, nodes, weights)
    end
  end

  def flow_problem_gen do
    # Generate a graph with at least 2 nodes and distinct source/sink
    gen all(
          nodes <- node_list_gen(2, 50, 100),
          length(nodes) >= 2,
          weights <- weight_list_gen(length(nodes), 0..100)
        ) do
      graph = build_graph(:directed, nodes, weights)
      # Ensure distinct s and t
      [s, t | _] = Enum.shuffle(nodes)
      {graph, s, t}
    end
  end

  def star_graph_gen do
    gen all(size <- StreamData.integer(3..20)) do
      center = 0
      leaves = Enum.to_list(1..(size - 1))
      nodes = Enum.to_list(0..(size - 1))
      # Build undirected star for simplicity in centrality tests
      graph = Enum.reduce(nodes, Yog.new(:undirected), fn id, g -> Yog.add_node(g, id, nil) end)

      graph =
        Enum.reduce(leaves, graph, fn v, g ->
          {:ok, g} = Yog.add_edge(g, center, v, 1)
          g
        end)

      {graph, center, leaves}
    end
  end

  def disjoint_cliques_gen(num_cliques \\ 2, size_range \\ 3..6) do
    gen all(sizes <- StreamData.list_of(StreamData.integer(size_range), length: num_cliques)) do
      graph = Yog.undirected()

      {final_graph, _} =
        Enum.reduce(sizes, {graph, 0}, fn size, {g, offset} ->
          nodes = Enum.to_list(offset..(offset + size - 1))
          g = Enum.reduce(nodes, g, fn node, acc -> Yog.add_node(acc, node, nil) end)

          # Add all-to-all edges in clique
          g =
            for u <- nodes, v <- nodes, u < v, reduce: g do
              acc ->
                {:ok, new_acc} = Yog.add_edge(acc, u, v, 1)
                new_acc
            end

          {g, offset + size}
        end)

      final_graph
    end
  end

  def weight_list_gen(num_nodes, range \\ -100..100) do
    # Generate 0 to 30 edges
    StreamData.list_of(
      {StreamData.integer(0..(num_nodes - 1)), StreamData.integer(0..(num_nodes - 1)),
       StreamData.integer(range)},
      max_length: 30
    )
  end

  def graph_of_kind_gen(kind) do
    gen all(
          nodes <- node_list_gen(),
          weights <- weight_list_gen(length(nodes))
        ) do
      build_graph(kind, nodes, weights)
    end
  end

  def same_kind_graphs_gen do
    gen all(
          kind <- kind_gen(),
          g1 <- graph_of_kind_gen(kind),
          g2 <- graph_of_kind_gen(kind)
        ) do
      {g1, g2}
    end
  end

  def tree_gen(size_range \\ 2..20) do
    gen all(size <- StreamData.integer(size_range)) do
      nodes = Enum.to_list(1..size)
      graph = Enum.reduce(nodes, Yog.undirected(), fn id, g -> Yog.add_node(g, id, nil) end)

      # Build tree by connecting each node i > 1 to some random node j < i
      Enum.reduce(2..size, graph, fn i, g ->
        parent = Enum.random(1..(i - 1))
        {:ok, g} = Yog.add_edge(g, parent, i, 1)
        g
      end)
    end
  end

  def arborescence_gen(size_range \\ 2..20) do
    gen all(size <- StreamData.integer(size_range)) do
      nodes = Enum.to_list(1..size)
      graph = Enum.reduce(nodes, Yog.directed(), fn id, g -> Yog.add_node(g, id, nil) end)

      # Root is node 1, connect each node i > 1 to some random node j < i
      Enum.reduce(2..size, graph, fn i, g ->
        parent = Enum.random(1..(i - 1))
        {:ok, g} = Yog.add_edge(g, parent, i, 1)
        g
      end)
    end
  end

  def build_graph(kind, nodes, edges) do
    # Map raw indices to actual node IDs
    node_map = Enum.with_index(nodes) |> Enum.into(%{}, fn {id, idx} -> {idx, id} end)

    graph = Enum.reduce(nodes, Yog.new(kind), fn id, g -> Yog.add_node(g, id, nil) end)

    Enum.reduce(edges, graph, fn {from_idx, to_idx, weight}, g ->
      from = Map.get(node_map, from_idx)
      to = Map.get(node_map, to_idx)

      if from != nil and to != nil do
        case Yog.add_edge(g, from, to, weight) do
          {:ok, new_g} -> new_g
          {:error, _} -> g
        end
      else
        g
      end
    end)
  end
end
