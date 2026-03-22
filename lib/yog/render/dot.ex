defmodule Yog.Render.DOT do
  @moduledoc """
  DOT (Graphviz) format export for visualizing graphs.

  This module exports graphs to the [DOT language](https://graphviz.org/doc/info/lang.html),
  which is the native format for [Graphviz](https://graphviz.org/) - a powerful open-source
  graph visualization tool. The exported files can be rendered to PNG, SVG, PDF, and other
  formats using the `dot`, `neato`, `circo`, or other Graphviz layout engines.

  ## Quick Start

      # Export with default styling
      dot_string = Yog.Render.DOT.to_dot(my_graph, Yog.Render.DOT.default_options())

      # Write to file and render with Graphviz CLI
      # $ dot -Tpng output.dot -o graph.png

  ## Customization

  Use `t:options/0` to customize:
  - Node labels and shapes
  - Edge labels and styles
  - Highlight specific nodes or paths
  - Graph direction (LR, TB, etc.)

  ## Rendering Options

  | Engine | Best For |
  |--------|----------|
  | `dot` | Hierarchical layouts (DAGs, trees) |
  | `neato` | Spring-based layouts (undirected) |
  | `circo` | Circular layouts |
  | `fdp` | Force-directed layouts |
  | `sfdp` | Large graphs |

  ## References

  - [Graphviz Documentation](https://graphviz.org/documentation/)
  - [DOT Language Guide](https://graphviz.org/doc/info/lang.html)
  - [Node Shapes](https://graphviz.org/doc/info/shapes.html)
  - [Arrow Styles](https://graphviz.org/doc/info/arrows.html)
  """

  @typedoc "Graph direction (rank direction)"
  @type rank_dir :: :tb | :lr | :bt | :rl

  @typedoc "Node shapes"
  @type node_shape ::
          :box
          | :circle
          | :ellipse
          | :diamond
          | :hexagon
          | :triangle
          | :rectangle

  @typedoc "Visual style"
  @type style :: :solid | :dashed | :dotted | :bold | :filled | :rounded

  @typedoc "Options for customizing DOT (Graphviz) diagram rendering"
  @type options :: %{
          node_label: (Yog.node_id(), any() -> String.t()),
          edge_label: (any() -> String.t()),
          highlighted_nodes: [Yog.node_id()] | nil,
          highlighted_edges: [{Yog.node_id(), Yog.node_id()}] | nil,
          graph_name: String.t(),
          rankdir: rank_dir() | nil,
          bgcolor: String.t() | nil,
          node_shape: node_shape(),
          node_color: String.t(),
          node_style: style(),
          node_fontname: String.t(),
          node_fontsize: integer(),
          edge_color: String.t(),
          edge_style: style(),
          highlight_color: String.t()
        }

  @doc """
  Creates default DOT options with simple labeling and sensible styling.

  Default configuration:
  - Layout: Auto-detected by Graphviz
  - Direction: Top-to-bottom
  - Node shape: Ellipse
  - Colors: Light blue nodes, black edges
  - Font: Helvetica 12pt

  ## Examples

      iex> opts = Yog.Render.DOT.default_options()
      iex> opts.graph_name
      "G"
      iex> opts.node_shape
      :ellipse
      iex> opts.node_color
      "lightblue"
  """
  @spec default_options() :: options()
  def default_options do
    %{
      node_label: fn id, _data -> Integer.to_string(id) end,
      edge_label: fn weight -> to_string(weight) end,
      highlighted_nodes: nil,
      highlighted_edges: nil,
      graph_name: "G",
      rankdir: :tb,
      bgcolor: nil,
      node_shape: :ellipse,
      node_color: "lightblue",
      node_style: :filled,
      node_fontname: "Helvetica",
      node_fontsize: 12,
      edge_color: "black",
      edge_style: :solid,
      highlight_color: "red"
    }
  end

  @doc """
  Converts a graph to DOT (Graphviz) syntax.

  Works with any node data type and edge data type. Use `default_options/0`
  to create appropriate options for your graph.

  ## Examples

      iex> graph = Yog.directed()
      ...> |> Yog.add_node(1, "Start")
      ...> |> Yog.add_node(2, "End")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "5")
      iex> dot = Yog.Render.DOT.to_dot(graph, Yog.Render.DOT.default_options())
      iex> String.contains?(dot, "digraph G {")
      true
      iex> String.contains?(dot, "->")
      true

      # Undirected graph
      iex> undirected = Yog.undirected()
      ...> |> Yog.add_node(1, "A")
      ...> |> Yog.add_node(2, "B")
      ...> |> Yog.add_edge!(from: 1, to: 2, with: "1")
      iex> dot = Yog.Render.DOT.to_dot(undirected, Yog.Render.DOT.default_options())
      iex> String.contains?(dot, "graph G {")
      true
      iex> String.contains?(dot, "--")
      true
  """
  @spec to_dot(Yog.graph(), options()) :: String.t()
  def to_dot(graph, options) do
    nodes = extract_nodes(graph)
    edges = extract_edges(graph)
    kind = extract_kind(graph)

    {graph_type, arrow} =
      if kind == :directed do
        {"digraph", "->"}
      else
        {"graph", "--"}
      end

    header = "#{graph_type} #{options.graph_name} {"
    graph_attrs = build_graph_attrs(options)
    node_defaults = build_node_defaults(options)
    edge_defaults = build_edge_defaults(options)

    lines =
      [header]
      |> add_if_not_empty(graph_attrs)
      |> List.insert_at(-1, node_defaults)
      |> List.insert_at(-1, edge_defaults)
      |> List.insert_at(-1, "")

    node_lines = build_node_lines(nodes, options)
    edge_lines = build_edge_lines(edges, options, arrow)

    lines =
      (lines ++ node_lines)
      |> List.insert_at(-1, "")
      |> Kernel.++(edge_lines)
      |> List.insert_at(-1, "}")

    Enum.join(lines, "\n")
  end

  defp extract_nodes(graph) do
    case graph do
      %{nodes: n} when is_map(n) -> n
      {:graph, _, n, _, _} when is_map(n) -> n
      _ -> %{}
    end
  end

  defp extract_edges(graph) do
    case graph do
      %{out_edges: e} when is_map(e) -> e
      {:graph, _, _, e, _} when is_map(e) -> e
      _ -> %{}
    end
  end

  defp extract_kind(graph) do
    case graph do
      %{kind: k} -> k
      {:graph, k, _, _, _} -> k
      _ -> :directed
    end
  end

  defp build_graph_attrs(options) do
    attrs =
      [
        options.rankdir && "rankdir=#{rankdir_to_string(options.rankdir)}",
        options.bgcolor && "bgcolor=\"#{options.bgcolor}\""
      ]
      |> Enum.reject(&is_nil/1)

    if attrs != [] do
      "  graph [#{Enum.join(attrs, ", ")}];"
    else
      ""
    end
  end

  defp build_node_defaults(options) do
    attrs = [
      "shape=#{options.node_shape}",
      "style=#{options.node_style}",
      "fillcolor=\"#{options.node_color}\"",
      "fontname=\"#{options.node_fontname}\"",
      "fontsize=#{options.node_fontsize}"
    ]

    "  node [#{Enum.join(attrs, ", ")}];"
  end

  defp build_edge_defaults(options) do
    attrs = [
      "color=\"#{options.edge_color}\"",
      "style=#{options.edge_style}"
    ]

    "  edge [#{Enum.join(attrs, ", ")}];"
  end

  defp build_node_lines(nodes, options) do
    Enum.map(nodes, fn {id, data} ->
      label = options.node_label.(id, data)
      attrs = [{"label", label}]

      attrs =
        if options.highlighted_nodes && id in options.highlighted_nodes do
          attrs ++ [{"color", options.highlight_color}, {"penwidth", "2"}]
        else
          attrs
        end

      attr_str = Enum.map_join(attrs, ", ", fn {k, v} -> "#{k}=\"#{v}\"" end)
      "  #{id} [#{attr_str}];"
    end)
  end

  defp build_edge_lines(edges, options, arrow) do
    Enum.flat_map(edges, fn {from, targets} ->
      build_edge_lines_for_node(from, targets, options, arrow)
    end)
  end

  defp build_edge_lines_for_node(from, targets, options, arrow) do
    if is_map(targets) do
      Enum.map(targets, fn {to, weight} ->
        build_single_edge_line(from, to, weight, arrow, options)
      end)
    else
      []
    end
  end

  defp build_single_edge_line(from, to, weight, arrow, options) do
    label = options.edge_label.(weight)
    attrs = if label != "" and label != "nil", do: [{"label", label}], else: []

    attrs =
      if options.highlighted_edges && {from, to} in options.highlighted_edges do
        attrs ++ [{"color", options.highlight_color}, {"penwidth", "2"}]
      else
        attrs
      end

    if attrs == [] do
      "  #{from} #{arrow} #{to};"
    else
      attr_str = Enum.map_join(attrs, ", ", fn {k, v} -> "#{k}=\"#{v}\"" end)
      "  #{from} #{arrow} #{to} [#{attr_str}];"
    end
  end

  defp add_if_not_empty(lines, ""), do: lines
  defp add_if_not_empty(lines, line), do: lines ++ [line]

  defp rankdir_to_string(:tb), do: "TB"
  defp rankdir_to_string(:lr), do: "LR"
  defp rankdir_to_string(:bt), do: "BT"
  defp rankdir_to_string(:rl), do: "RL"

  @doc """
  Converts a shortest path result to highlighted DOT options.

  Creates a copy of the base options with the path's nodes and edges
  set to be highlighted. This is useful for visualizing algorithm results.

  ## Examples

      iex> base_opts = Yog.Render.DOT.default_options()
      iex> path = %{nodes: [1, 2, 3], weight: 10}
      iex> highlighted_opts = Yog.Render.DOT.path_to_options(path, base_opts)
      iex> highlighted_opts.highlighted_nodes
      [1, 2, 3]
      iex> highlighted_opts.highlighted_edges
      [{1, 2}, {2, 3}]
  """
  @spec path_to_options(map(), options()) :: options()
  def path_to_options(path, base_options) do
    nodes = path.nodes
    edges = path_to_edges(nodes)

    Map.merge(base_options, %{
      highlighted_nodes: nodes,
      highlighted_edges: edges
    })
  end

  defp path_to_edges([]), do: []
  defp path_to_edges([_]), do: []

  defp path_to_edges([first, second | rest]) do
    [{first, second} | path_to_edges([second | rest])]
  end
end
