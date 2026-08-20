defmodule Yog.IO.GEXF.SaxyHandlerTest do
  use ExUnit.Case, async: true

  alias Yog.IO.GEXF.SaxyHandler

  setup do
    {:ok, state: %SaxyHandler{}}
  end

  test "start_document and end_document events", %{state: state} do
    assert {:ok, ^state} = SaxyHandler.handle_event(:start_document, nil, state)
    assert {:ok, ^state} = SaxyHandler.handle_event(:end_document, nil, state)
  end

  test "graph event sets graph_type", %{state: state} do
    {:ok, state1} =
      SaxyHandler.handle_event(
        :start_element,
        {"graph", [{"defaultedgetype", "undirected"}]},
        state
      )

    assert state1.graph_type == :undirected

    {:ok, state2} =
      SaxyHandler.handle_event(
        :start_element,
        {"graph", [{"defaultedgetype", "directed"}]},
        state
      )

    assert state2.graph_type == :directed
  end

  test "attributes and attribute declaration events", %{state: state} do
    {:ok, state} =
      SaxyHandler.handle_event(:start_element, {"attributes", [{"class", "node"}]}, state)

    assert state.current_element == {:attributes, "node"}

    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"attribute", [{"id", "0"}, {"title", "age"}, {"type", "integer"}]},
        state
      )

    assert state.node_attr_map["0"] == "age"
    assert state.node_attr_types["0"] == "integer"

    {:ok, state} =
      SaxyHandler.handle_event(:start_element, {"attributes", [{"class", "edge"}]}, state)

    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"attribute", [{"id", "e0"}, {"title", "weight"}, {"type", "double"}]},
        state
      )

    assert state.edge_attr_map["e0"] == "weight"
    assert state.edge_attr_types["e0"] == "double"
  end

  test "node start and end element events", %{state: state} do
    {:ok, state} =
      SaxyHandler.handle_event(:start_element, {"node", [{"id", "1"}, {"label", "Alice"}]}, state)

    assert state.current_element == :node
    assert state.current_attrs["_id"] == 1
    assert state.current_attrs["label"] == "Alice"

    {:ok, state} = SaxyHandler.handle_event(:end_element, "node", state)
    assert length(state.nodes) == 1
    {id, data} = List.first(state.nodes)
    assert id == 1
    assert data["label"] == "Alice"
  end

  test "edge start and end element events", %{state: state} do
    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"edge", [{"source", "1"}, {"target", "2"}, {"weight", "3.5"}]},
        state
      )

    assert state.current_element == :edge
    assert state.current_attrs["_source"] == 1
    assert state.current_attrs["_target"] == 2

    {:ok, state} = SaxyHandler.handle_event(:end_element, "edge", state)
    assert length(state.edges) == 1
    {source, target, weight} = List.first(state.edges)
    assert source == 1
    assert target == 2
    assert weight["weight"] == "3.5"
  end

  test "attvalue event with type casting", %{state: state} do
    # Declare attributes
    {:ok, state} =
      SaxyHandler.handle_event(:start_element, {"attributes", [{"class", "node"}]}, state)

    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"attribute", [{"id", "a0"}, {"title", "age"}, {"type", "integer"}]},
        state
      )

    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"attribute", [{"id", "a1"}, {"title", "active"}, {"type", "boolean"}]},
        state
      )

    # Start node
    {:ok, state} = SaxyHandler.handle_event(:start_element, {"node", [{"id", "1"}]}, state)

    # Add attvalues
    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"attvalue", [{"for", "a0"}, {"value", "30"}]},
        state
      )

    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"attvalue", [{"for", "a1"}, {"value", "true"}]},
        state
      )

    assert state.current_attrs["age"] == 30
    assert state.current_attrs["active"] == true
  end

  test "viz extension events (viz:color, viz:size, viz:position, viz:shape)", %{state: state} do
    {:ok, state} = SaxyHandler.handle_event(:start_element, {"node", [{"id", "1"}]}, state)

    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"viz:color", [{"r", "255"}, {"g", "0"}, {"b", "128"}, {"a", "0.8"}]},
        state
      )

    {:ok, state} =
      SaxyHandler.handle_event(:start_element, {"viz:size", [{"value", "15.5"}]}, state)

    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"viz:position", [{"x", "1.0"}, {"y", "2.0"}, {"z", "3.0"}]},
        state
      )

    {:ok, state} =
      SaxyHandler.handle_event(:start_element, {"viz:shape", [{"value", "square"}]}, state)

    assert state.current_attrs["viz:color"] == %{r: 255, g: 0, b: 128, a: 0.8}
    assert state.current_attrs["viz:size"] == 15.5
    assert state.current_attrs["viz:position"] == %{x: 1.0, y: 2.0, z: 3.0}
    assert state.current_attrs["viz:shape"] == "square"
  end

  test "multigraph edge handling", %{state: state} do
    state = %{state | multigraph: true}

    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"edge", [{"id", "e100"}, {"source", "1"}, {"target", "2"}]},
        state
      )

    {:ok, state} = SaxyHandler.handle_event(:end_element, "edge", state)

    assert length(state.edges) == 1
    assert {"e100", 1, 2, %{"weight" => ""}} = List.first(state.edges)
  end

  test "malformed or invalid attribute type parsing does not crash", %{state: state} do
    {:ok, state} =
      SaxyHandler.handle_event(:start_element, {"attributes", [{"class", "node"}]}, state)

    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"attribute", [{"id", "a0"}, {"title", "age"}, {"type", "integer"}]},
        state
      )

    {:ok, state} = SaxyHandler.handle_event(:start_element, {"node", [{"id", "1"}]}, state)

    # Pass invalid integer string
    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"attvalue", [{"for", "a0"}, {"value", "not_an_int"}]},
        state
      )

    assert state.current_attrs["age"] == "not_an_int"
  end
end
