defmodule Yog.Render do
  @moduledoc """
  Graph visualization and export.

  Supports multiple output formats:
  - Mermaid (for Markdown/GitHub)
  - DOT/Graphviz (for publication-quality graphics)
  - JSON (for web visualization libraries)

  ## Examples

      # Mermaid diagram for GitHub
      mermaid = Yog.Render.to_mermaid(graph)
      File.write!("graph.md", "```mermaid\\n\#{mermaid}\\n```")

      # DOT for Graphviz
      dot = Yog.Render.to_dot(graph)
      File.write!("graph.dot", dot)
      # Then: dot -Tpng graph.dot -o graph.png

      # JSON for D3.js/Cytoscape
      json = Yog.Render.to_json(graph)
  """

  @doc """
  Converts a graph to Mermaid diagram syntax.

  Returns a string that can be embedded in Markdown and rendered by
  GitHub, GitLab, or any Mermaid-compatible viewer.

  ## Options

  - `:node_label` - Function to generate node labels (default: node ID)
  - `:edge_label` - Function to generate edge labels (default: edge weight)
  - `:options` - Map of options (see below)

  ## Render Options

  - `:highlighted_nodes` - List of node IDs to highlight
  - `:highlighted_edges` - List of `{from, to}` tuples to highlight

  ## Examples

      # Basic mermaid
      mermaid = Yog.Render.to_mermaid(graph)

      # With custom labels
      mermaid = Yog.Render.to_mermaid(
        graph,
        node_label: fn id, data -> "\#{id}: \#{data}" end,
        edge_label: fn weight -> "weight=\#{weight}" end
      )

      # Highlight a path
      mermaid = Yog.Render.to_mermaid(
        graph,
        options: %{
          highlighted_nodes: [1, 2, 3],
          highlighted_edges: [{1, 2}, {2, 3}]
        }
      )
  """
  @spec to_mermaid(Yog.graph(), keyword()) :: String.t()
  def to_mermaid(graph, opts \\ []) do
    node_label_fn = Keyword.get(opts, :node_label, fn id, _data -> to_string(id) end)
    edge_label_fn = Keyword.get(opts, :edge_label, fn weight -> to_string(weight) end)
    
    opts_map = Keyword.get(opts, :options, %{})
    high_nodes = wrap_option(Map.get(opts_map, :highlighted_nodes))
    high_edges = wrap_option(Map.get(opts_map, :highlighted_edges))

    gleam_opts = {:mermaid_options, node_label_fn, edge_label_fn, high_nodes, high_edges}
    :yog@render.to_mermaid(graph, gleam_opts)
  end

  @doc """
  Converts a shortest path to Mermaid options for highlighting.
  """
  @spec path_to_mermaid_options(Yog.Pathfinding.path(), keyword()) :: map()
  def path_to_mermaid_options(path, base_options \\ []) do
    case path do
      %{} = map ->
        {:path, nodes, _} = map.gleam_path
        node_label_fn = Keyword.get(base_options, :node_label, fn id, _data -> to_string(id) end)
        edge_label_fn = Keyword.get(base_options, :edge_label, fn w -> to_string(w) end)
        
        # Gleam 1.3.0 path_to_options returns a MermaidOptions tuple, which we could return directly
        # or repackage. Let's return the gleam tuple, to_mermaid will need to handle it or we just
        # let users pass it. 
        # Actually, it's better to just build the option map.
        %{highlighted_nodes: nodes, highlighted_edges: path_to_edges(nodes)}
      _ -> base_options
    end
  end

  defp path_to_edges(nodes) do
    case nodes do
      [] -> []
      [_] -> []
      [a, b | rest] -> [{a, b} | path_to_edges([b | rest])]
    end
  end

  @doc """
  Converts a graph to DOT (Graphviz) format.
  """
  @spec to_dot(Yog.graph(), keyword()) :: String.t()
  def to_dot(graph, opts \\ []) do
    node_label_fn = Keyword.get(opts, :node_label, fn id, _data -> to_string(id) end)
    edge_label_fn = Keyword.get(opts, :edge_label, fn weight -> to_string(weight) end)
    
    opts_map = Keyword.get(opts, :options, %{})
    high_nodes = wrap_option(Map.get(opts_map, :highlighted_nodes))
    high_edges = wrap_option(Map.get(opts_map, :highlighted_edges))
    
    node_shape = Keyword.get(opts, :node_shape, "ellipse")
    highlight_color = Keyword.get(opts, :highlight_color, "red")

    gleam_opts = {:dot_options, node_label_fn, edge_label_fn, high_nodes, high_edges, node_shape, highlight_color}
    :yog@render.to_dot(graph, gleam_opts)
  end

  @doc """
  Converts a shortest path to DOT options for highlighting.
  """
  @spec path_to_dot_options(Yog.Pathfinding.path(), keyword()) :: map()
  def path_to_dot_options(path, base_options \\ []) do
    case path do
      %{} = map ->
        {:path, nodes, _} = map.gleam_path
        %{highlighted_nodes: nodes, highlighted_edges: path_to_edges(nodes)}
      _ -> base_options
    end
  end

  @doc """
  Converts a graph to JSON format.
  """
  @spec to_json(Yog.graph(), keyword()) :: String.t()
  def to_json(graph, opts \\ []) do
    node_mapper = Keyword.get(opts, :node_mapper, fn id, label -> 
      :gleam@json.object([{"id", :gleam@json.int(id)}, {"label", :gleam@json.string(to_string(label))}]) 
    end)
    edge_mapper = Keyword.get(opts, :edge_mapper, fn from, to, weight -> 
      :gleam@json.object([{"source", :gleam@json.int(from)}, {"target", :gleam@json.int(to)}, {"weight", :gleam@json.string(to_string(weight))}]) 
    end)

    gleam_opts = {:json_options, node_mapper, edge_mapper}
    :yog@render.to_json(graph, gleam_opts)
  end

  defp wrap_option(nil), do: :none
  defp wrap_option(val), do: {:some, val}
end
