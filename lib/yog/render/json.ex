defmodule Yog.Render.JSON do
  @moduledoc """
  JSON format export for graph data interchange.

  This module exports graphs to [JSON](https://json.org/) format, a widely
  adopted standard for data interchange. The exported JSON follows the
  [JSON Graph Format (JGF)](https://jsongraphformat.info/) specification,
  making it compatible with many graph visualization tools and libraries.

  ## Quick Start

      # Export a graph to JSON
      json_string = Yog.Render.JSON.to_json(my_graph, Yog.Render.JSON.default_options())

  ## JSON Graph Format

  The output follows the JGF v0.1 specification:

  ```json
  {
    "nodes": [
      {"id": 1, "label": "Node A"},
      {"id": 2, "label": "Node B"}
    ],
    "edges": [
      {"source": 1, "target": 2, "weight": "5"}
    ]
  }
  ```

  ## Customization

  Control the output using the `t:options/0` type with custom mappers:

      options = Yog.Render.JSON.default_options()
      node_mapper = fn id, data -> %{"name" => data.name, "type" => data.type} end
      edge_mapper = fn from, to, weight -> %{"cost" => weight, "capacity" => 100} end
      opts = %{options | node_mapper: node_mapper, edge_mapper: edge_mapper}

  ## Use Cases

  | Scenario | Recommended Approach |
  |----------|---------------------|
  | Web API | Export with minimal metadata |
  | Data persistence | Full graph export with all data |
  | D3.js visualization | Custom node/edge attributes |
  | Interoperability | Standard JGF format |

  ## Interoperability

  JSON exports work well with:
  - **D3.js**: Force-directed and other visualizations
  - **Cytoscape.js**: Interactive network visualization
  - **Sigma.js**: Large graph rendering
  - **Neo4j**: Import into graph databases
  - **NetworkX**: Python graph analysis

  ## References

  - [JSON Graph Format](https://jsongraphformat.info/)
  - [JSON.org](https://json.org/)
  - [D3.js Force Simulation](https://d3js.org/d3-force)
  """

  @typedoc "JSON-compatible value types for node and edge data"
  @type json_value ::
          nil
          | boolean()
          | integer()
          | float()
          | String.t()
          | [json_value()]
          | %{String.t() => json_value()}

  @typedoc "Mapper function for converting node data to JSON"
  @type node_mapper :: (Yog.node_id(), any() -> %{String.t() => json_value()})

  @typedoc "Mapper function for converting edge data to JSON"
  @type edge_mapper :: (Yog.node_id(), Yog.node_id(), any() -> %{String.t() => json_value()})

  @typedoc "Options for customizing JSON output"
  @type options :: %{
          node_mapper: node_mapper(),
          edge_mapper: edge_mapper()
        }

  @doc """
  Creates default JSON options with identity-based mapping.

  Default behavior:
  - Node ID: Included as `id` field
  - Node data: Stored in `label` field
  - Edge source/target: Included as `source` and `target` fields
  - Edge weight: Stored in `weight` field

  ## Examples

      iex> opts = Yog.Render.JSON.default_options()
      iex> node_result = opts.node_mapper.(1, "Alice")
      iex> node_result["id"]
      1
      iex> node_result["label"]
      "Alice"
      iex> edge_result = opts.edge_mapper.(1, 2, "follows")
      iex> edge_result["source"]
      1
      iex> edge_result["target"]
      2
      iex> edge_result["weight"]
      "follows"
  """
  @spec default_options() :: options()
  def default_options do
    %{
      node_mapper: fn id, data ->
        %{"id" => id, "label" => to_string(data)}
      end,
      edge_mapper: fn from, to, weight ->
        %{"source" => from, "target" => to, "weight" => to_string(weight)}
      end
    }
  end

  @doc """
  Exports a graph to JSON format.

  Uses the provided options to control how node and edge data is serialized.
  For custom data structures, provide mappers in the options.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Alice")
      ...> |> Yog.add_node(2, "Bob")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "follows")
      iex> json = Yog.Render.JSON.to_json(graph, Yog.Render.JSON.default_options())
      iex> String.contains?(json, "Alice")
      true
      iex> String.contains?(json, "Bob")
      true
      iex> String.contains?(json, "follows")
      true

      # Undirected graph
      iex> undirected = Yog.undirected()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "1")
      iex> json = Yog.Render.JSON.to_json(undirected, Yog.Render.JSON.default_options())
      iex> String.contains?(json, "A")
      true
      iex> String.contains?(json, "B")
      true
  """
  @spec to_json(Yog.graph(), options()) :: String.t()
  def to_json(graph, options) do
    # Extract nodes from the graph
    nodes_dict =
      case graph do
        %{nodes: n} when is_map(n) -> n
        {:graph, _, n, _, _} when is_map(n) -> n
        _ -> %{}
      end

    out_edges =
      case graph do
        %{out_edges: e} when is_map(e) -> e
        {:graph, _, _, e, _} when is_map(e) -> e
        _ -> %{}
      end

    kind =
      case graph do
        %{kind: k} -> k
        {:graph, k, _, _, _} -> k
        _ -> :directed
      end

    # Build nodes array using the mapper
    nodes =
      Enum.map(nodes_dict, fn {id, data} ->
        options.node_mapper.(id, data)
      end)

    # Build edges array using the mapper
    edges =
      Enum.flat_map(out_edges, fn {from_id, targets} ->
        case targets do
          t when is_map(t) ->
            Enum.flat_map(t, fn {to_id, weight} ->
              # For undirected graphs, only include each edge once
              if kind == :undirected and from_id > to_id do
                []
              else
                [options.edge_mapper.(from_id, to_id, weight)]
              end
            end)

          _ ->
            []
        end
      end)

    # Encode to JSON
    Jason.encode!(%{
      "nodes" => nodes,
      "edges" => edges
    })
  end
end
