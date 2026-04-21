defmodule Yog.IO.Libgraph do
  @moduledoc """
  Interoperability with the [libgraph](https://hex.pm/packages/libgraph) library.

  This module provides bidirectional conversion between Yog graphs and Libgraph graphs,
  enabling users to leverage both libraries' algorithms on the same graph data.

  ## Installation

  To use this module, add `libgraph` to your dependencies:

      defp deps do
        [
          {:yog_ex, "~> 0.90.0"},
          {:libgraph, "~> 0.16"}  # Required for interoperability
        ]
      end

  ## Type Mapping

  | Yog Type | Libgraph Type | Notes |
  |----------|---------------|-------|
  | `Yog.Graph` (directed) | `Graph` with `:directed` type | Standard directed graph |
  | `Yog.Graph` (undirected) | `Graph` with `:undirected` type | Standard undirected graph |
  | `Yog.Multi.Graph` | `Graph` with parallel edges | Multi-graph support |
  | `Yog.DAG` | `Graph` (acyclic) | DAG type preserved |

  ## Examples

  ### Convert Yog to Libgraph

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_edge_ensure(from: 1, to: 2, with: 5)
      iex> libgraph = Yog.IO.Libgraph.to_libgraph(graph)
      iex> libgraph.type
      :directed

  ### Convert Libgraph to Yog

  ### DAG Conversion

      iex> {:ok, dag} = Yog.DAG.from_graph(
      ...>   Yog.directed()
      ...>   |> Yog.add_node(1, nil)
      ...>   |> Yog.add_node(2, nil)
      ...>   |> Yog.add_edge_ensure(1, 2, 1)
      ...> )
      iex> libgraph = Yog.IO.Libgraph.to_libgraph(dag)
      iex> {:ok, yog_dag} = Yog.IO.Libgraph.from_libgraph(libgraph)
      iex> %Yog.DAG{} = yog_dag

  ## Error Handling

  - `{:ok, graph}` - Successful conversion
  - `{:error, reason}` - Conversion failed (e.g., cycle detected when creating DAG)
  """

  alias Yog.Graph, as: YogGraph

  # Only compile this module if libgraph is available
  if Code.ensure_loaded?(Graph) do
    @doc """
    Converts a Libgraph graph to the appropriate Yog graph type.

    The returned type depends on the Libgraph graph structure:
    - Simple directed/undirected → `Yog.Graph`
    - Multi-edges detected → `Yog.Multi.Graph`
    - Acyclic → `Yog.DAG` (if validation passes)

    ## Options

      * `:force_type` - Override automatic type detection (`:simple`, `:multi`, `:dag`)

    ## Examples

        iex> libgraph = Graph.new(type: :directed)
        ...> |> Graph.add_vertex(1, "data")
        ...> |> Graph.add_vertex(2, "more")
        ...> |> Graph.add_edge(1, 2, weight: 10)
        iex> {:ok, graph} = Yog.IO.Libgraph.from_libgraph(libgraph, force_type: :simple)
        iex> Yog.Model.order(graph) == 2
        true
    """
    @spec from_libgraph(Graph.t(), keyword()) ::
            {:ok, YogGraph.t() | Yog.Multi.Graph.t() | Yog.DAG.t()} | {:error, atom()}
    def from_libgraph(libgraph, opts \\ []) when is_struct(libgraph, Graph) do
      force_type = opts[:force_type]

      vertices = Graph.vertices(libgraph)
      edges = Graph.edges(libgraph)
      type = libgraph.type
      simple_graph = to_simple_graph(vertices, edges, type, libgraph)

      is_multigraph =
        if force_type == :multi do
          true
        else
          detect_multigraph(edges, type)
        end

      cond do
        force_type == :dag ->
          Yog.DAG.from_graph(simple_graph)

        is_multigraph ->
          {:ok, to_multi_graph(vertices, edges, type, libgraph)}

        force_type == :simple ->
          {:ok, simple_graph}

        type == :directed ->
          # Try to create a DAG; if it fails (has cycles), return as simple graph
          case Yog.DAG.from_graph(simple_graph) do
            {:ok, dag} -> {:ok, dag}
            {:error, _} -> {:ok, simple_graph}
          end

        true ->
          {:ok, simple_graph}
      end
    end

    @doc """
    Converts a Yog graph to a Libgraph graph.

    Automatically detects the appropriate Libgraph configuration based on input type.

    ## Examples

        iex> graph = Yog.undirected()
        ...> |> Yog.add_node(1, "A")
        ...> |> Yog.add_node(2, "B")
        ...> |> Yog.add_edge_ensure(1, 2, 5)
        iex> libgraph = Yog.IO.Libgraph.to_libgraph(graph)
        iex> libgraph.type
        :undirected
    """
    @spec to_libgraph(YogGraph.t() | Yog.Multi.Graph.t() | Yog.DAG.t(), keyword()) :: Graph.t()
    def to_libgraph(graph, opts \\ [])

    def to_libgraph(%YogGraph{kind: kind, nodes: nodes, out_edges: out_edges}, opts) do
      type = kind

      base_graph = Graph.new(type: type)
      weight_fn = Keyword.get(opts, :weight_fn, &default_weight_extractor/1)

      graph_with_nodes =
        Enum.reduce(nodes, base_graph, fn {id, data}, acc ->
          Graph.add_vertex(acc, id, data)
        end)

      Enum.reduce(out_edges, graph_with_nodes, fn {from, targets}, acc ->
        Enum.reduce(targets, acc, fn {to, data}, inner_acc ->
          add_edge_safely(inner_acc, from, to, data, weight_fn)
        end)
      end)
    end

    def to_libgraph(%Yog.Multi.Model.Graph{} = multi, opts) do
      type = multi.kind

      base_graph = Graph.new(type: type)
      weight_fn = Keyword.get(opts, :weight_fn, &default_weight_extractor/1)

      graph_with_nodes =
        Enum.reduce(multi.nodes, base_graph, fn {id, data}, acc ->
          Graph.add_vertex(acc, id, data)
        end)

      Enum.reduce(multi.edges, graph_with_nodes, fn {_edge_id, {from, to, data}}, acc ->
        add_edge_safely(acc, from, to, data, weight_fn)
      end)
    end

    def to_libgraph(%Yog.DAG{graph: graph}, opts) do
      to_libgraph(graph, opts)
    end

    # ============================================================================
    # Private functions
    # ============================================================================

    defp default_weight_extractor(data) do
      cond do
        is_number(data) ->
          data

        is_map(data) ->
          val = Map.get(data, "weight") || Map.get(data, :weight)
          if is_number(val), do: val, else: 1

        true ->
          1
      end
    end

    defp add_edge_safely(acc, from, to, data, weight_fn) do
      weight_extracted = weight_fn.(data)
      weight = if is_number(weight_extracted), do: weight_extracted, else: 1

      # Libgraph identifies edges by {v1, v2, label}.
      # To support parallel edges (multigraphs), we must provide a label.
      # We use the original data as the label to preserve metadata.
      Graph.add_edge(acc, from, to, weight: weight, label: data)
    end

    defp detect_multigraph([], _type), do: false

    defp detect_multigraph(edges, type) do
      Enum.reduce_while(edges, MapSet.new(), fn edge, visited ->
        key =
          if type == :undirected do
            # Sort node IDs for undirected parallel edge detection
            if edge.v1 < edge.v2, do: {edge.v1, edge.v2}, else: {edge.v2, edge.v1}
          else
            {edge.v1, edge.v2}
          end

        if MapSet.member?(visited, key) do
          {:halt, true}
        else
          {:cont, MapSet.put(visited, key)}
        end
      end) == true
    end

    defp to_simple_graph(vertices, edges, type, libgraph) do
      base = if type == :directed, do: Yog.directed(), else: Yog.undirected()

      vertices
      |> Enum.reduce(base, fn v, acc ->
        Yog.add_node(acc, v, get_vertex_data(libgraph, v))
      end)
      |> populate_edges(edges, false)
    end

    defp to_multi_graph(vertices, edges, type, libgraph) do
      base = if type == :directed, do: Yog.Multi.new(:directed), else: Yog.Multi.new(:undirected)

      vertices
      |> Enum.reduce(base, fn v, acc ->
        Yog.Multi.add_node(acc, v, get_vertex_data(libgraph, v))
      end)
      |> populate_edges(edges, true)
    end

    defp get_vertex_data(libgraph, v) do
      case Graph.vertex_labels(libgraph, v) do
        [] -> nil
        [data | _] -> data
      end
    end

    defp populate_edges(graph, edges, is_multi?) do
      Enum.reduce(edges, graph, fn edge, acc ->
        if is_multi? do
          {new_graph, _} = Yog.Multi.add_edge(acc, edge.v1, edge.v2, edge.weight)
          new_graph
        else
          case Yog.add_edge(acc, edge.v1, edge.v2, edge.weight) do
            {:ok, new_graph} -> new_graph
            {:error, _} -> acc
          end
        end
      end)
    end
  else
    # libgraph is not available - provide helpful error messages
    @moduledoc """
    Interoperability with the [libgraph](https://hex.pm/packages/libgraph) library.

    ## Installation Required

    To use this module, you must add `libgraph` to your dependencies:

        defp deps do
          [
            {:yog_ex, "~> 0.90.0"},
            {:libgraph, "~> 0.16"}
          ]
        end

    Then run `mix deps.get`.
    """

    def from_libgraph(_libgraph, _opts \\ []) do
      raise "libgraph is not installed. Add {:libgraph, \"~> 0.16\"} to your deps to use this function."
    end

    def to_libgraph(_yog_graph) do
      raise "libgraph is not installed. Add {:libgraph, \"~> 0.16\"} to your deps to use this function."
    end
  end
end
