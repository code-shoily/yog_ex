defmodule Yog.IO.GEXF.Common do
  @moduledoc false
  alias Yog.IO.XMLUtils

  # ==========================================================================
  # Serialization helpers
  # ==========================================================================

  def discover_keys_with_types(attrs_list, special_key) do
    attrs_list
    |> Enum.reduce(%{}, fn attrs, acc ->
      Enum.reduce(attrs, acc, fn {key, value}, inner_acc ->
        key_str = Yog.Utils.safe_string(key)

        if Map.has_key?(inner_acc, key_str) or viz_key?(key_str) or key_str == special_key do
          inner_acc
        else
          Map.put(inner_acc, key_str, %{id: map_size(inner_acc), type: infer_type(value)})
        end
      end)
    end)
  end

  def viz_key?("viz:" <> _), do: true
  def viz_key?(_), do: false

  def infer_type(v) when is_integer(v), do: "integer"
  def infer_type(v) when is_float(v), do: "double"
  def infer_type(v) when is_boolean(v), do: "boolean"
  def infer_type(_), do: "string"

  def to_string_key(k) when is_binary(k), do: k
  def to_string_key(k), do: Yog.Utils.safe_string(k)

  def build_attribute_definitions(node_keys, edge_keys) do
    node_defs =
      node_keys
      |> Enum.sort_by(fn {_k, meta} -> meta.id end)
      |> Enum.map(fn {key, meta} ->
        [
          "    <attribute id=\"",
          Yog.Utils.safe_string(meta.id),
          "\" title=\"",
          XMLUtils.escape_xml(key),
          "\" type=\"",
          meta.type,
          "\"/>\n"
        ]
      end)

    edge_defs =
      edge_keys
      |> Enum.sort_by(fn {_k, meta} -> meta.id end)
      |> Enum.map(fn {key, meta} ->
        [
          "    <attribute id=\"",
          Yog.Utils.safe_string(meta.id),
          "\" title=\"",
          XMLUtils.escape_xml(key),
          "\" type=\"",
          meta.type,
          "\"/>\n"
        ]
      end)

    [
      if(node_defs != [],
        do: ["    <attributes class=\"node\">\n", node_defs, "    </attributes>\n"],
        else: []
      ),
      if(edge_defs != [],
        do: ["    <attributes class=\"edge\">\n", edge_defs, "    </attributes>\n"],
        else: []
      )
    ]
  end

  def build_nodes_xml(nodes_map, node_attr, node_keys, node_fmt \\ &Yog.Utils.safe_string/1) do
    if map_size(nodes_map) == 0 do
      "    <nodes></nodes>\n"
    else
      nodes_inner =
        nodes_map
        |> Enum.sort()
        |> Enum.map(fn {id, data} ->
          attrs = node_attr.(data)
          label = Map.get(attrs, "label") || Map.get(attrs, :label) || node_fmt.(id)

          attvalues = build_attvalues(attrs, node_keys, "label")
          viz_xml = build_viz_xml(attrs)

          [
            "    <node id=\"",
            XMLUtils.escape_xml(node_fmt.(id)),
            "\" label=\"",
            XMLUtils.escape_xml(label),
            "\">\n",
            if(attvalues != [],
              do: ["      <attvalues>\n", attvalues, "      </attvalues>\n"],
              else: []
            ),
            viz_xml,
            "    </node>\n"
          ]
        end)

      ["    <nodes>\n", nodes_inner, "    </nodes>\n"]
    end
  end

  def build_single_edge_xml(
        edge_id,
        from,
        to,
        weight,
        edge_attr,
        edge_keys,
        node_fmt \\ &Yog.Utils.safe_string/1,
        edge_fmt \\ &Yog.Utils.safe_string/1
      ) do
    attrs = edge_attr.(weight)
    weight_val = Map.get(attrs, "weight") || Map.get(attrs, :weight) || ""

    attvalues = build_attvalues(attrs, edge_keys, "weight")
    viz_xml = build_viz_xml(attrs)

    [
      "    <edge id=\"",
      edge_fmt.(edge_id),
      "\" source=\"",
      XMLUtils.escape_xml(node_fmt.(from)),
      "\" target=\"",
      XMLUtils.escape_xml(node_fmt.(to)),
      "\"",
      if(weight_val != "", do: [" weight=\"", XMLUtils.escape_xml(weight_val), "\""], else: ""),
      ">\n",
      if(attvalues != [],
        do: ["      <attvalues>\n", attvalues, "      </attvalues>\n"],
        else: []
      ),
      viz_xml,
      "    </edge>\n"
    ]
  end

  def build_viz_xml(attrs) do
    has_viz? =
      Enum.any?(attrs, fn {k, _} ->
        match?("viz:" <> _, to_string_key(k))
      end)

    if has_viz? do
      Enum.flat_map(attrs, fn {key, value} ->
        case to_string_key(key) do
          "viz:color" ->
            r = Map.get(value, :r) || Map.get(value, "r", 0)
            g = Map.get(value, :g) || Map.get(value, "g", 0)
            b = Map.get(value, :b) || Map.get(value, "b", 0)
            a = Map.get(value, :a) || Map.get(value, "a", 1.0)

            [
              "      <viz:color r=\"",
              Yog.Utils.safe_string(r),
              "\" g=\"",
              Yog.Utils.safe_string(g),
              "\" b=\"",
              Yog.Utils.safe_string(b),
              "\" a=\"",
              Yog.Utils.safe_string(a),
              "\"/>\n"
            ]

          "viz:size" ->
            ["      <viz:size value=\"", Yog.Utils.safe_string(value), "\"/>\n"]

          "viz:position" ->
            x = Map.get(value, :x) || Map.get(value, "x", 0.0)
            y = Map.get(value, :y) || Map.get(value, "y", 0.0)
            z = Map.get(value, :z) || Map.get(value, "z", 0.0)

            [
              "      <viz:position x=\"",
              Yog.Utils.safe_string(x),
              "\" y=\"",
              Yog.Utils.safe_string(y),
              "\" z=\"",
              Yog.Utils.safe_string(z),
              "\"/>\n"
            ]

          "viz:shape" ->
            ["      <viz:shape value=\"", XMLUtils.escape_xml(value), "\"/>\n"]

          _ ->
            []
        end
      end)
    else
      []
    end
  end

  def build_attvalues(attrs, keys_map, special_key) do
    Enum.flat_map(attrs, fn {key, value} ->
      k_str = to_string_key(key)

      if k_str == special_key or viz_key?(k_str) do
        []
      else
        meta = Map.get(keys_map, k_str)

        if meta != nil do
          [
            "        <attvalue for=\"",
            Yog.Utils.safe_string(meta.id),
            "\" value=\"",
            XMLUtils.escape_xml(value),
            "\"/>\n"
          ]
        else
          []
        end
      end
    end)
  end

  # ==========================================================================
  # Saxy deserialization graph building
  # ==========================================================================

  def build_graph_from_saxy_state(state, model_module, false) do
    Enum.reduce(state.nodes, model_module.new(state.graph_type), fn {id, data}, acc ->
      model_module.add_node(acc, id, data)
    end)
    |> then(fn graph ->
      Enum.reduce(state.edges, graph, fn {from, to, weight}, acc ->
        case model_module.add_edge(acc, from, to, weight) do
          {:ok, new_graph} -> new_graph
          {:error, _} -> acc
        end
      end)
    end)
  end

  def build_graph_from_saxy_state(state, model_module, true) do
    Enum.reduce(state.nodes, model_module.new(state.graph_type), fn {id, data}, acc ->
      model_module.add_node(acc, id, data)
    end)
    |> then(fn graph ->
      Enum.reduce(state.edges, graph, fn {_eid, from, to, weight}, acc ->
        model_module.add_edge(acc, from, to, weight) |> elem(0)
      end)
    end)
  end

  # ==========================================================================
  # xmerl deserialization helpers
  # ==========================================================================

  def build_graph_from_doc(doc, node_folder, edge_folder, model_module, false) do
    graph_type = extract_graph_type(doc)
    attr_map = build_attr_map(doc)
    nodes = extract_nodes(doc, node_folder, attr_map)

    graph =
      Enum.reduce(nodes, model_module.new(graph_type), fn {id, data}, acc ->
        model_module.add_node(acc, id, data)
      end)

    edges = extract_edges_simple(doc, edge_folder, attr_map)

    final_graph =
      Enum.reduce(edges, graph, fn {from, to, weight}, acc ->
        case model_module.add_edge(acc, from, to, weight) do
          {:ok, new_graph} -> new_graph
          {:error, _} -> acc
        end
      end)

    {:ok, final_graph}
  end

  def build_graph_from_doc(doc, node_folder, edge_folder, model_module, true) do
    graph_type = extract_graph_type(doc)
    attr_map = build_attr_map(doc)
    nodes = extract_nodes(doc, node_folder, attr_map)

    graph =
      Enum.reduce(nodes, model_module.new(graph_type), fn {id, data}, acc ->
        model_module.add_node(acc, id, data)
      end)

    edges = extract_edges_multi(doc, edge_folder, attr_map)

    final_graph =
      Enum.reduce(edges, graph, fn {_eid, from, to, weight}, acc ->
        model_module.add_edge(acc, from, to, weight) |> elem(0)
      end)

    {:ok, final_graph}
  end

  def extract_graph_type(doc) do
    case :xmerl_xpath.string(~c'string(/gexf/graph/@defaultedgetype)', doc) do
      {:xmlObj, :string, ~c"undirected"} ->
        :undirected

      charlist when is_list(charlist) ->
        if List.to_string(charlist) == "undirected", do: :undirected, else: :directed

      _ ->
        :directed
    end
  end

  def build_attr_map(doc) do
    node_attrs =
      :xmerl_xpath.string(~c'/gexf/graph/attributes[@class="node"]/attribute', doc)
      |> Enum.map(fn attr_elem ->
        id_str = xmerl_string_value(:xmerl_xpath.string(~c'string(@id)', attr_elem))
        title = xmerl_string_value(:xmerl_xpath.string(~c'string(@title)', attr_elem))
        type = xmerl_string_value(:xmerl_xpath.string(~c'string(@type)', attr_elem))
        {id_str, {title, type}}
      end)
      |> Map.new()

    edge_attrs =
      :xmerl_xpath.string(~c'/gexf/graph/attributes[@class="edge"]/attribute', doc)
      |> Enum.map(fn attr_elem ->
        id_str = xmerl_string_value(:xmerl_xpath.string(~c'string(@id)', attr_elem))
        title = xmerl_string_value(:xmerl_xpath.string(~c'string(@title)', attr_elem))
        type = xmerl_string_value(:xmerl_xpath.string(~c'string(@type)', attr_elem))
        {id_str, {title, type}}
      end)
      |> Map.new()

    %{node: node_attrs, edge: edge_attrs}
  end

  def extract_nodes(doc, node_folder, attr_map) do
    node_elements = :xmerl_xpath.string(~c'/gexf/graph/nodes/node', doc)

    Enum.map(node_elements, fn node_elem ->
      id_str = xmerl_string_value(:xmerl_xpath.string(~c'string(@id)', node_elem))
      id = parse_id(id_str)
      label = xmerl_string_value(:xmerl_xpath.string(~c'string(@label)', node_elem))
      attrs = extract_attvalues(node_elem, attr_map.node)
      attrs = if label != "", do: Map.put(attrs, "label", label), else: attrs
      attrs = extract_viz_attributes(node_elem, attrs)
      {id, node_folder.(attrs)}
    end)
  end

  def extract_edges_simple(doc, edge_folder, attr_map) do
    edge_elements = :xmerl_xpath.string(~c'/gexf/graph/edges/edge', doc)

    Enum.map(edge_elements, fn edge_elem ->
      source_str = xmerl_string_value(:xmerl_xpath.string(~c'string(@source)', edge_elem))
      target_str = xmerl_string_value(:xmerl_xpath.string(~c'string(@target)', edge_elem))
      weight_str = xmerl_string_value(:xmerl_xpath.string(~c'string(@weight)', edge_elem))
      source = parse_id(source_str)
      target = parse_id(target_str)
      attrs = extract_attvalues(edge_elem, attr_map.edge)
      attrs = if weight_str != "", do: Map.put(attrs, "weight", weight_str), else: attrs
      attrs = extract_viz_attributes(edge_elem, attrs)
      {source, target, edge_folder.(attrs)}
    end)
  end

  def extract_edges_multi(doc, edge_folder, attr_map) do
    edge_elements = :xmerl_xpath.string(~c'/gexf/graph/edges/edge', doc)

    Enum.map(edge_elements, fn edge_elem ->
      eid_str = xmerl_string_value(:xmerl_xpath.string(~c'string(@id)', edge_elem))
      source_str = xmerl_string_value(:xmerl_xpath.string(~c'string(@source)', edge_elem))
      target_str = xmerl_string_value(:xmerl_xpath.string(~c'string(@target)', edge_elem))
      weight_str = xmerl_string_value(:xmerl_xpath.string(~c'string(@weight)', edge_elem))

      eid = parse_id(eid_str)
      source = parse_id(source_str)
      target = parse_id(target_str)

      attrs = extract_attvalues(edge_elem, attr_map.edge)
      attrs = if weight_str != "", do: Map.put(attrs, "weight", weight_str), else: attrs
      attrs = extract_viz_attributes(edge_elem, attrs)
      {eid, source, target, edge_folder.(attrs)}
    end)
  end

  def extract_attvalues(element, attr_map) do
    attvalues = :xmerl_xpath.string(~c'.//attvalue', element)

    Enum.reduce(attvalues, %{}, fn attval, acc ->
      for_attr = xmerl_string_value(:xmerl_xpath.string(~c'string(@for)', attval))
      value_str = xmerl_string_value(:xmerl_xpath.string(~c'string(@value)', attval))
      {key, type} = Map.get(attr_map, for_attr, {for_attr, "string"})
      Map.put(acc, key, xmerl_cast_value(value_str, type))
    end)
  end

  def extract_viz_attributes(element, attrs) do
    attrs
    |> extract_viz_color(element)
    |> extract_viz_size(element)
    |> extract_viz_position(element)
    |> extract_viz_shape(element)
  end

  defp extract_viz_color(attrs, element) do
    case :xmerl_xpath.string(~c'./viz:color', element) do
      [color_elem | _] ->
        r = xmerl_get_int(color_elem, "r", 0)
        g = xmerl_get_int(color_elem, "g", 0)
        b = xmerl_get_int(color_elem, "b", 0)
        a = xmerl_get_float(color_elem, "a", 1.0)
        Map.put(attrs, "viz:color", %{r: r, g: g, b: b, a: a})

      _ ->
        attrs
    end
  end

  defp extract_viz_size(attrs, element) do
    case :xmerl_xpath.string(~c'./viz:size', element) do
      [size_elem | _] -> Map.put(attrs, "viz:size", xmerl_get_float(size_elem, "value", 1.0))
      _ -> attrs
    end
  end

  defp extract_viz_position(attrs, element) do
    case :xmerl_xpath.string(~c'./viz:position', element) do
      [pos_elem | _] ->
        x = xmerl_get_float(pos_elem, "x", 0.0)
        y = xmerl_get_float(pos_elem, "y", 0.0)
        z = xmerl_get_float(pos_elem, "z", 0.0)
        Map.put(attrs, "viz:position", %{x: x, y: y, z: z})

      _ ->
        attrs
    end
  end

  defp extract_viz_shape(attrs, element) do
    case :xmerl_xpath.string(~c'./viz:shape', element) do
      [shape_elem | _] ->
        val = xmerl_string_value(:xmerl_xpath.string(~c'string(@value)', shape_elem))
        Map.put(attrs, "viz:shape", val)

      _ ->
        attrs
    end
  end

  def xmerl_cast_value(val, "integer"), do: String.to_integer(val)
  def xmerl_cast_value(val, "long"), do: String.to_integer(val)
  def xmerl_cast_value(val, "double"), do: String.to_float(val)
  def xmerl_cast_value(val, "float"), do: String.to_float(val)
  def xmerl_cast_value("true", "boolean"), do: true
  def xmerl_cast_value("false", "boolean"), do: false
  def xmerl_cast_value(val, _), do: val

  def xmerl_get_int(elem, name, default) do
    case xmerl_string_value(:xmerl_xpath.string(~c'string(@#{name})', elem)) do
      "" -> default
      v -> String.to_integer(v)
    end
  end

  def xmerl_get_float(elem, name, default) do
    case xmerl_string_value(:xmerl_xpath.string(~c'string(@#{name})', elem)) do
      "" ->
        default

      v ->
        case Float.parse(v) do
          {f, _} -> f
          :error -> default
        end
    end
  end

  def parse_id(id_str) do
    case Integer.parse(id_str) do
      {int, ""} -> int
      _ -> id_str
    end
  end

  def xmerl_string_value(result) do
    case result do
      {:xmlObj, :string, charlist} -> List.to_string(charlist)
      charlist when is_list(charlist) -> List.to_string(charlist)
      _ -> ""
    end
  end
end
