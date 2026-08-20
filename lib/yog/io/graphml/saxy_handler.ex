defmodule Yog.IO.GraphML.SaxyHandler do
  @moduledoc """
  SAX event handler for streaming GraphML parsing using `Saxy`.

  Maintains parser state across XML elements (`<graph>`, `<node>`, `<edge>`, `<data>`)
  to construct node and edge lists with custom attributes.
  """

  if Code.ensure_loaded?(Saxy) do
    @behaviour Saxy.Handler
  end

  @type t :: %__MODULE__{
          node_folder: (map() -> any()) | nil,
          edge_folder: (map() -> any()) | nil,
          graph_type: :directed | :undirected,
          nodes: list({any(), any()}),
          edges: list({any(), any(), any()}),
          current_element: :node | :edge | nil,
          current_attrs: map(),
          current_data_key: String.t() | nil,
          current_data_value: String.t()
        }

  defstruct node_folder: nil,
            edge_folder: nil,
            graph_type: :directed,
            nodes: [],
            edges: [],
            current_element: nil,
            current_attrs: %{},
            current_data_key: nil,
            current_data_value: ""

  @doc """
  Processes SAX events emitted during GraphML XML streaming parsing.

  Time complexity: $\\mathcal{O}(1)$ per XML event.
  """
  @spec handle_event(atom(), any(), t()) :: {:ok, t()}
  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:end_document, _data, state) do
    {:ok, state}
  end

  def handle_event(:start_element, {"graph", attrs}, state) do
    graph_type =
      case List.keyfind(attrs, "edgedefault", 0) do
        {"edgedefault", "undirected"} -> :undirected
        _ -> :directed
      end

    {:ok, %{state | graph_type: graph_type}}
  end

  def handle_event(:start_element, {"node", attrs}, state) do
    id =
      case List.keyfind(attrs, "id", 0) do
        {"id", id_str} -> parse_id(id_str)
        _ -> nil
      end

    {:ok, %{state | current_element: :node, current_attrs: %{"_id" => id}}}
  end

  def handle_event(:start_element, {"edge", attrs}, state) do
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

    {:ok,
     %{
       state
       | current_element: :edge,
         current_attrs: %{"_source" => source, "_target" => target}
     }}
  end

  def handle_event(:start_element, {"data", attrs}, state) do
    key =
      case List.keyfind(attrs, "key", 0) do
        {"key", k} -> k
        _ -> nil
      end

    {:ok, %{state | current_data_key: key, current_data_value: ""}}
  end

  def handle_event(:start_element, _other, state) do
    {:ok, state}
  end

  def handle_event(:end_element, "node", state) do
    id = Map.get(state.current_attrs, "_id")
    attrs = Map.delete(state.current_attrs, "_id")
    folder = if is_function(state.node_folder, 1), do: state.node_folder, else: & &1
    data = folder.(attrs)
    nodes = [{id, data} | state.nodes]

    {:ok, %{state | nodes: nodes, current_element: nil, current_attrs: %{}}}
  end

  def handle_event(:end_element, "edge", state) do
    source = Map.get(state.current_attrs, "_source")
    target = Map.get(state.current_attrs, "_target")
    attrs = state.current_attrs |> Map.delete("_source") |> Map.delete("_target")
    folder = if is_function(state.edge_folder, 1), do: state.edge_folder, else: & &1
    weight = folder.(attrs)
    edges = [{source, target, weight} | state.edges]

    {:ok, %{state | edges: edges, current_element: nil, current_attrs: %{}}}
  end

  def handle_event(:end_element, "data", state) do
    key = state.current_data_key
    value = state.current_data_value

    new_attrs =
      if key do
        Map.put(state.current_attrs, key, value)
      else
        state.current_attrs
      end

    {:ok, %{state | current_attrs: new_attrs, current_data_key: nil, current_data_value: ""}}
  end

  def handle_event(:end_element, _other, state) do
    {:ok, state}
  end

  def handle_event(:characters, chars, %{current_data_key: key} = state) when key != nil do
    {:ok, %{state | current_data_value: state.current_data_value <> chars}}
  end

  def handle_event(:characters, _chars, state) do
    {:ok, state}
  end

  defp parse_id(id_str) when is_binary(id_str) do
    case Integer.parse(id_str) do
      {int, ""} -> int
      _ -> id_str
    end
  end

  defp parse_id(id), do: id
end
