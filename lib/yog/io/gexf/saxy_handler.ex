defmodule Yog.IO.GEXF.SaxyHandler do
  @moduledoc false
  @behaviour Saxy.Handler

  defstruct node_folder: nil,
            edge_folder: nil,
            graph_type: :directed,
            node_attr_map: %{},
            node_attr_types: %{},
            edge_attr_map: %{},
            edge_attr_types: %{},
            nodes: [],
            edges: [],
            current_element: nil,
            current_attrs: %{},
            multigraph: false

  @impl Saxy.Handler
  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  @impl Saxy.Handler
  def handle_event(:end_document, _data, state) do
    {:ok, state}
  end

  @impl Saxy.Handler
  def handle_event(:start_element, {"graph", attrs}, state) do
    graph_type =
      case List.keyfind(attrs, "defaultedgetype", 0) do
        {"defaultedgetype", "undirected"} -> :undirected
        _ -> :directed
      end

    {:ok, %{state | graph_type: graph_type}}
  end

  def handle_event(:start_element, {"attributes", attrs}, state) do
    class =
      case List.keyfind(attrs, "class", 0) do
        {"class", c} -> c
        _ -> "node"
      end

    {:ok, %{state | current_element: {:attributes, class}}}
  end

  def handle_event(
        :start_element,
        {"attribute", attrs},
        %{current_element: {:attributes, class}} = state
      ) do
    id_str =
      case List.keyfind(attrs, "id", 0) do
        {"id", id} -> id
        _ -> nil
      end

    title =
      case List.keyfind(attrs, "title", 0) do
        {"title", t} -> t
        _ -> id_str
      end

    type =
      case List.keyfind(attrs, "type", 0) do
        {"type", t} -> t
        _ -> "string"
      end

    if id_str != nil do
      case class do
        "edge" ->
          {:ok,
           %{
             state
             | edge_attr_map: Map.put(state.edge_attr_map, id_str, title),
               edge_attr_types: Map.put(state.edge_attr_types, id_str, type)
           }}

        _ ->
          {:ok,
           %{
             state
             | node_attr_map: Map.put(state.node_attr_map, id_str, title),
               node_attr_types: Map.put(state.node_attr_types, id_str, type)
           }}
      end
    else
      {:ok, state}
    end
  end

  def handle_event(:start_element, {"node", attrs}, state) do
    id =
      case List.keyfind(attrs, "id", 0) do
        {"id", id_str} -> parse_id(id_str)
        _ -> nil
      end

    label =
      case List.keyfind(attrs, "label", 0) do
        {"label", l} -> l
        _ -> ""
      end

    {:ok, %{state | current_element: :node, current_attrs: %{"_id" => id, "label" => label}}}
  end

  def handle_event(:start_element, {"edge", attrs}, state) do
    eid =
      if state.multigraph do
        case List.keyfind(attrs, "id", 0) do
          {"id", id_str} -> parse_id(id_str)
          _ -> nil
        end
      else
        nil
      end

    source =
      case List.keyfind(attrs, "source", 0) do
        {"source", src} -> parse_id(src)
        _ -> nil
      end

    target =
      case List.keyfind(attrs, "target", 0) do
        {"target", tgt} -> parse_id(tgt)
        _ -> nil
      end

    weight =
      case List.keyfind(attrs, "weight", 0) do
        {"weight", w} -> w
        _ -> ""
      end

    base_attrs = %{
      "_source" => source,
      "_target" => target,
      "weight" => weight
    }

    current_attrs = if state.multigraph, do: Map.put(base_attrs, "_eid", eid), else: base_attrs

    {:ok,
     %{
       state
       | current_element: :edge,
         current_attrs: current_attrs
     }}
  end

  def handle_event(:start_element, {"attvalue", attrs}, state) do
    for_attr =
      case List.keyfind(attrs, "for", 0) do
        {"for", f} -> f
        _ -> nil
      end

    value_str =
      case List.keyfind(attrs, "value", 0) do
        {"value", v} -> v
        _ -> ""
      end

    if for_attr != nil do
      {attr_map, type_map} =
        case state.current_element do
          :edge -> {state.edge_attr_map, state.edge_attr_types}
          _ -> {state.node_attr_map, state.node_attr_types}
        end

      key = Map.get(attr_map, for_attr, for_attr)
      type = Map.get(type_map, for_attr, "string")
      value = cast_value(value_str, type)

      new_attrs = Map.put(state.current_attrs, key, value)
      {:ok, %{state | current_attrs: new_attrs}}
    else
      {:ok, state}
    end
  end

  def handle_event(:start_element, {"viz:color", attrs}, state) do
    r = get_attr_int(attrs, "r", 0)
    g = get_attr_int(attrs, "g", 0)
    b = get_attr_int(attrs, "b", 0)
    a = get_attr_float(attrs, "a", 1.0)
    new_attrs = Map.put(state.current_attrs, "viz:color", %{r: r, g: g, b: b, a: a})
    {:ok, %{state | current_attrs: new_attrs}}
  end

  def handle_event(:start_element, {"viz:size", attrs}, state) do
    val = get_attr_float(attrs, "value", 1.0)
    new_attrs = Map.put(state.current_attrs, "viz:size", val)
    {:ok, %{state | current_attrs: new_attrs}}
  end

  def handle_event(:start_element, {"viz:position", attrs}, state) do
    x = get_attr_float(attrs, "x", 0.0)
    y = get_attr_float(attrs, "y", 0.0)
    z = get_attr_float(attrs, "z", 0.0)
    new_attrs = Map.put(state.current_attrs, "viz:position", %{x: x, y: y, z: z})
    {:ok, %{state | current_attrs: new_attrs}}
  end

  def handle_event(:start_element, {"viz:shape", attrs}, state) do
    val =
      case List.keyfind(attrs, "value", 0) do
        {"value", v} -> v
        _ -> "disc"
      end

    new_attrs = Map.put(state.current_attrs, "viz:shape", val)
    {:ok, %{state | current_attrs: new_attrs}}
  end

  def handle_event(:start_element, _other, state) do
    {:ok, state}
  end

  @impl Saxy.Handler
  def handle_event(:end_element, "node", state) do
    id = Map.get(state.current_attrs, "_id")
    label = Map.get(state.current_attrs, "label", "")

    attrs_map =
      state.current_attrs
      |> Map.delete("_id")
      |> Map.delete("label")

    attrs = if label != "", do: Map.put(attrs_map, "label", label), else: attrs_map

    data = state.node_folder.(attrs)
    nodes = [{id, data} | state.nodes]

    {:ok, %{state | nodes: nodes, current_element: nil, current_attrs: %{}}}
  end

  def handle_event(:end_element, "edge", state) do
    source = Map.get(state.current_attrs, "_source")
    target = Map.get(state.current_attrs, "_target")

    base_keys = ["_source", "_target"]
    keys_to_delete = if state.multigraph, do: ["_eid" | base_keys], else: base_keys

    attrs_map = Map.drop(state.current_attrs, keys_to_delete)

    weight = state.edge_folder.(attrs_map)

    edge =
      if state.multigraph do
        eid = Map.get(state.current_attrs, "_eid")
        {eid, source, target, weight}
      else
        {source, target, weight}
      end

    edges = [edge | state.edges]

    {:ok, %{state | edges: edges, current_element: nil, current_attrs: %{}}}
  end

  def handle_event(:end_element, _other, state) do
    {:ok, state}
  end

  @impl Saxy.Handler
  def handle_event(:characters, _chars, state) do
    {:ok, state}
  end

  defp cast_value(val, "integer"), do: String.to_integer(val)
  defp cast_value(val, "long"), do: String.to_integer(val)
  defp cast_value(val, "double"), do: String.to_float(val)
  defp cast_value(val, "float"), do: String.to_float(val)
  defp cast_value("true", "boolean"), do: true
  defp cast_value("false", "boolean"), do: false
  defp cast_value(val, _), do: val

  defp get_attr_int(attrs, name, default) do
    case List.keyfind(attrs, name, 0) do
      {^name, v} -> String.to_integer(v)
      _ -> default
    end
  end

  defp get_attr_float(attrs, name, default) do
    case List.keyfind(attrs, name, 0) do
      {^name, v} ->
        case Float.parse(v) do
          {f, _} -> f
          :error -> default
        end

      _ ->
        default
    end
  end

  defp parse_id(id_str) do
    case Integer.parse(id_str) do
      {int, ""} -> int
      _ -> id_str
    end
  end
end
