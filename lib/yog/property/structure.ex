defmodule Yog.Property.Structure do
  @moduledoc """
  Structural properties of graphs.

  This module provides checks for various graph classes and regularities.

  ## Algorithms

  | Problem | Function | Complexity |
  |---------|----------|------------|
  | Tree check | `tree?/1` | O(V + E) |
  | Arborescence check | `arborescence?/1` | O(V + E) |
  | Forest check | `forest?/1` | O(V + E) |
  | Branching check | `branching?/1` | O(V + E) |
  | Complete graph check | `complete?/1` | O(V) |
  | Regular graph check | `regular?/2` | O(V) |
  | Connected check | `connected?/1` | O(V + E) |
  | Strongly connected check | `strongly_connected?/1` | O(V + E) |
  | Weakly connected check | `weakly_connected?/1` | O(V + E) |
  | Chordal check | `chordal?/1` | O(V + E) |

  ## Key Concepts

  - **Tree**: Connected acyclic undirected graph.
  - **Arborescence**: Directed tree with a unique root.
  - **Complete Graph (Kn)**: Every pair of distinct vertices is connected by an edge.
  - **Regular Graph**: Every vertex has the same degree k.

  ## Structural Visualizations

  Comparison of an undirected tree and a complete graph.

  <div class="graphviz">
  graph G {
    rankdir=LR;
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];

    subgraph cluster_tree {
      label="Undirected Tree"; color="#6366f1"; style=rounded;
      T1 -- T2; T1 -- T3; T2 -- T4; T2 -- T5;
    }

    subgraph cluster_complete {
      label="Complete (K3)"; color="#f43f5e"; style=rounded;
      K1 -- K2; K2 -- K3; K3 -- K1;
    }
  }
  </div>

      iex> alias Yog.Property.Structure
      iex> tree = Yog.from_edges(:undirected, [{"T1", "T2", 1}, {"T1", "T3", 1}, {"T2", "T4", 1}, {"T2", "T5", 1}])
      iex> Structure.tree?(tree)
      true
      iex> complete = Yog.from_edges(:undirected, [{"K1", "K2", 1}, {"K2", "K3", 1}, {"K3", "K1", 1}])
      iex> Structure.complete?(complete)
      true

  ## Arborescence Visualization

  A directed tree with a unique root node.

  <div class="graphviz">
  digraph G {
    rankdir=TB;
    bgcolor="transparent";
    node [shape=circle, fontname="inherit"];
    edge [fontname="inherit", fontsize=10];
    
    subgraph cluster_arb {
      label="Arborescence"; color="#10b981"; style=rounded;
      R -> A; R -> B; A -> C; A -> D;
    }
  }
  </div>

      iex> alias Yog.Property.Structure
      iex> arb = Yog.from_edges(:directed, [{"R", "A", 1}, {"R", "B", 1}, {"A", "C", 1}, {"A", "D", 1}])
      iex> Structure.arborescence?(arb)
      true
      iex> Structure.arborescence_root(arb)
      "R"

  ## Examples

      # Simple tree
      iex> graph = Yog.undirected()
      ...> |> Yog.add_node(1, nil)
      ...> |> Yog.add_node(2, nil)
      ...> |> Yog.add_edge_ensure(1, 2, 1)
      iex> Yog.Property.Structure.tree?(graph)
      true

      # Complete graph K3 (triangle)
      iex> graph = Yog.undirected() |> Yog.add_node(1, nil) |> Yog.add_node(2, nil) |> Yog.add_node(3, nil)
      ...> |> Yog.add_edge_ensure(1, 2, 1) |> Yog.add_edge_ensure(2, 3, 1) |> Yog.add_edge_ensure(3, 1, 1)
      iex> Yog.Property.Structure.complete?(graph)
      true
  """

  alias Yog.Connectivity.Components
  alias Yog.Connectivity.SCC
  alias Yog.Model
  alias Yog.Property.Cyclicity
  alias Yog.Utils

  @doc """
  Checks if the graph is a tree (connected and acyclic).
  Works for undirected graphs.

  ## Time Complexity
  O(V + E)
  """
  @spec tree?(Yog.graph()) :: boolean()
  def tree?(graph) do
    case Model.type(graph) do
      :undirected ->
        n = Model.node_count(graph)
        e = Model.edge_count(graph)
        n > 0 and e == n - 1 and connected?(graph)

      :directed ->
        false
    end
  end

  @doc """
  Checks if the graph is an arborescence (directed tree with a single root).

  A directed graph is an arborescence iff:
  - It has n nodes and n-1 edges
  - Exactly one node has in-degree 0 (the root)
  - All other nodes have in-degree >= 1

  When edges = n-1 and there's exactly one root, reachability is guaranteed
  (no need for explicit BFS check).
  """
  @spec arborescence?(Yog.graph()) :: boolean()
  def arborescence?(graph) do
    case Model.type(graph) do
      :directed ->
        n = Model.node_count(graph)

        if n > 0 and Model.edge_count(graph) == n - 1 do
          {roots, non_roots_with_valid_degree} =
            graph
            |> Model.all_nodes()
            |> Enum.reduce({[], 0}, fn node, {roots, valid} ->
              case Model.in_degree(graph, node) do
                0 -> {[node | roots], valid}
                1 -> {roots, valid + 1}
                _ -> {roots, valid}
              end
            end)

          match?([_], roots) and non_roots_with_valid_degree == n - 1
        else
          false
        end

      _ ->
        false
    end
  end

  @doc """
  Finds the root of an arborescence.
  """
  @spec arborescence_root(Yog.graph()) :: Yog.node_id() | nil
  def arborescence_root(graph) do
    if arborescence?(graph) do
      graph
      |> Model.all_nodes()
      |> Enum.find(fn node ->
        graph
        |> Model.predecessors(node)
        |> Enum.empty?()
      end)
    else
      nil
    end
  end

  @doc """
  Checks if the graph is a forest (a loopless undirected graph consisting
  entirely of disjoint trees).

  A disconnected graph with multiple trees evaluates to `true`.

  ## Examples

      iex> forest = Yog.undirected()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(3, 4, 1, nil)
      iex> Yog.Property.Structure.forest?(forest)
      true
  """
  @spec forest?(Yog.graph()) :: boolean()
  def forest?(graph) do
    case Model.type(graph) do
      :undirected ->
        n = Model.node_count(graph)

        if n == 0 do
          true
        else
          e = Model.edge_count(graph)
          c = length(Components.connected_components(graph))
          e == n - c
        end

      :directed ->
        false
    end
  end

  @doc """
  Checks if a directed graph is a branching (a directed forest).

  Evaluates to `true` if every node has an in-degree of 1 or 0, and
  the graph contains no directed cycles.

  ## Examples

      iex> branch = Yog.directed()
      ...> |> Yog.add_edge_ensure(1, 2, 1, nil)
      ...> |> Yog.add_edge_ensure(1, 3, 1, nil)
      ...> |> Yog.add_edge_ensure(4, 5, 1, nil)
      iex> Yog.Property.Structure.branching?(branch)
      true
  """
  @spec branching?(Yog.graph()) :: boolean()
  def branching?(graph) do
    case Model.type(graph) do
      :directed ->
        # Condition 1: All nodes have in-degree <= 1
        valid_in_degrees? =
          graph
          |> Model.all_nodes()
          |> Enum.all?(fn node -> Model.in_degree(graph, node) <= 1 end)

        # Condition 2: No directed cycles
        valid_in_degrees? and Cyclicity.acyclic?(graph)

      :undirected ->
        false
    end
  end

  @doc """
  Checks if the graph is complete (every pair of distinct nodes is connected).
  """
  @spec complete?(Yog.graph()) :: boolean()
  def complete?(graph) do
    n = Model.node_count(graph)

    if n <= 1 do
      true
    else
      e = Model.edge_count(graph)

      expected_e =
        case Model.type(graph) do
          :undirected -> div(n * (n - 1), 2)
          :directed -> n * (n - 1)
        end

      e == expected_e and no_self_loops?(graph)
    end
  end

  @doc """
  Checks if the graph is k-regular (every node has degree exactly k).
  """
  @spec regular?(Yog.graph(), integer()) :: boolean()
  def regular?(graph, k) do
    nodes = Model.all_nodes(graph)

    if nodes == [] do
      true
    else
      case Model.type(graph) do
        :undirected ->
          Enum.all?(nodes, fn u -> Model.degree(graph, u) == k end)

        :directed ->
          Enum.all?(nodes, fn u ->
            Model.out_degree(graph, u) == k and Model.in_degree(graph, u) == k
          end)
      end
    end
  end

  @doc """
  Checks if the graph is connected.

  For undirected graphs, every node is reachable from every other node.
  For directed graphs, this checks for strong connectivity.
  """
  @spec connected?(Yog.graph()) :: boolean()
  def connected?(graph) do
    case Model.type(graph) do
      :undirected ->
        case Components.connected_components(graph) do
          [_] -> true
          [] -> true
          _ -> false
        end

      :directed ->
        strongly_connected?(graph)
    end
  end

  @doc """
  Checks if a directed graph is strongly connected.
  """
  @spec strongly_connected?(Yog.graph()) :: boolean()
  def strongly_connected?(graph) do
    case Model.type(graph) do
      :undirected ->
        connected?(graph)

      :directed ->
        case SCC.strongly_connected_components(graph) do
          [_] -> true
          [] -> true
          _ -> false
        end
    end
  end

  @doc """
  Checks if a directed graph is weakly connected.
  """
  @spec weakly_connected?(Yog.graph()) :: boolean()
  def weakly_connected?(graph) do
    case Model.type(graph) do
      :undirected ->
        connected?(graph)

      :directed ->
        case Components.weakly_connected_components(graph) do
          [_] -> true
          [] -> true
          _ -> false
        end
    end
  end

  @doc """
  Checks if the graph is chordal using Maximum Cardinality Search.
  """
  @spec chordal?(Yog.graph()) :: boolean()
  def chordal?(graph) do
    case Model.type(graph) do
      :undirected ->
        peo?(graph, mcs_ordering(graph))

      :directed ->
        false
    end
  end

  # =============================================================================
  # Helpers
  # =============================================================================

  defp mcs_ordering(graph) do
    nodes = Model.all_nodes(graph)
    n = length(nodes)

    if n == 0 do
      []
    else
      buckets = %{0 => MapSet.new(nodes)}
      weights = Map.new(nodes, fn id -> {id, 0} end)

      do_mcs(graph, weights, [], MapSet.new(nodes), buckets, 0)
    end
  end

  defp do_mcs(graph, weights, order, remaining, buckets, max_weight) do
    if MapSet.size(remaining) == 0 do
      Enum.reverse(order)
    else
      {v, new_buckets, new_max_weight} =
        pop_max_weight_node(buckets, max_weight)

      neighbors = Model.neighbor_ids(graph, v)

      {new_weights, new_buckets2, updated_max_weight} =
        Enum.reduce(
          neighbors,
          {weights, new_buckets, new_max_weight},
          fn u, {w_acc, b_acc, max_w_acc} ->
            if MapSet.member?(remaining, u) do
              old_weight = Map.get(w_acc, u)
              new_weight = old_weight + 1

              w_acc2 = Map.put(w_acc, u, new_weight)

              old_bucket = Map.get(b_acc, old_weight)
              new_bucket = Map.get(b_acc, new_weight) || MapSet.new()

              b_acc2 =
                b_acc
                |> Map.put(old_weight, MapSet.delete(old_bucket, u))
                |> Map.put(new_weight, MapSet.put(new_bucket, u))

              max_w_acc2 = max(max_w_acc, new_weight)

              {w_acc2, b_acc2, max_w_acc2}
            else
              {w_acc, b_acc, max_w_acc}
            end
          end
        )

      do_mcs(
        graph,
        new_weights,
        [v | order],
        MapSet.delete(remaining, v),
        new_buckets2,
        updated_max_weight
      )
    end
  end

  defp pop_max_weight_node(_buckets, max_weight) when max_weight < 0 do
    raise "Bucket queue empty - no more nodes to process"
  end

  defp pop_max_weight_node(buckets, max_weight) do
    case Map.get(buckets, max_weight) do
      nil ->
        pop_max_weight_node(buckets, max_weight - 1)

      set ->
        if MapSet.size(set) == 0 do
          pop_max_weight_node(buckets, max_weight - 1)
        else
          node = Enum.at(MapSet.to_list(set), 0)
          new_set = MapSet.delete(set, node)
          new_buckets = Map.put(buckets, max_weight, new_set)
          {node, new_buckets, max_weight}
        end
    end
  end

  defp peo?(graph, order) do
    pos_map = order |> Enum.with_index() |> Map.new()

    Enum.all?(order, fn v ->
      earlier_neighbors =
        graph
        |> Model.neighbor_ids(v)
        |> Enum.filter(fn u -> Map.get(pos_map, u) < Map.get(pos_map, v) end)

      clique?(graph, earlier_neighbors)
    end)
  end

  defp clique?(graph, nodes) do
    Utils.combinations(nodes, 2)
    |> Enum.all?(fn pair ->
      case pair do
        [u, v] -> Model.has_edge?(graph, u, v)
        _ -> true
      end
    end)
  end

  defp no_self_loops?(graph) do
    graph
    |> Model.all_nodes()
    |> Enum.all?(fn u -> not Model.has_edge?(graph, u, u) end)
  end
end
