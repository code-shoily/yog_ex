defmodule Yog.IO.GraphML.SaxyHandlerTest do
  use ExUnit.Case, async: true
  alias Yog.IO.GraphML.SaxyHandler

  test "SaxyHandler parses graphml elements cleanly" do
    state = %SaxyHandler{node_folder: & &1, edge_folder: & &1}

    {:ok, state} = SaxyHandler.handle_event(:start_document, [], state)

    {:ok, state} =
      SaxyHandler.handle_event(:start_element, {"graph", [{"edgedefault", "undirected"}]}, state)

    assert state.graph_type == :undirected

    {:ok, state} = SaxyHandler.handle_event(:start_element, {"node", [{"id", "1"}]}, state)
    {:ok, state} = SaxyHandler.handle_event(:start_element, {"data", [{"key", "name"}]}, state)
    {:ok, state} = SaxyHandler.handle_event(:characters, "Alice", state)
    {:ok, state} = SaxyHandler.handle_event(:end_element, "data", state)
    {:ok, state} = SaxyHandler.handle_event(:end_element, "node", state)

    assert length(state.nodes) == 1
    assert state.nodes == [{1, %{"name" => "Alice"}}]

    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"edge", [{"source", "1"}, {"target", "2"}]},
        state
      )

    {:ok, state} = SaxyHandler.handle_event(:start_element, {"data", [{"key", "weight"}]}, state)
    {:ok, state} = SaxyHandler.handle_event(:characters, "10", state)
    {:ok, state} = SaxyHandler.handle_event(:end_element, "data", state)
    {:ok, state} = SaxyHandler.handle_event(:end_element, "edge", state)

    assert length(state.edges) == 1
    assert state.edges == [{1, 2, %{"weight" => "10"}}]

    {:ok, state} = SaxyHandler.handle_event(:end_document, [], state)
    assert state.nodes == [{1, %{"name" => "Alice"}}]
  end

  test "SaxyHandler fallbacks for missing folder functions" do
    state = %SaxyHandler{}

    {:ok, state} = SaxyHandler.handle_event(:start_element, {"node", [{"id", "alice"}]}, state)
    {:ok, state} = SaxyHandler.handle_event(:end_element, "node", state)

    assert state.nodes == [{"alice", %{}}]

    {:ok, state} =
      SaxyHandler.handle_event(
        :start_element,
        {"edge", [{"source", "alice"}, {"target", "bob"}]},
        state
      )

    {:ok, state} = SaxyHandler.handle_event(:end_element, "edge", state)

    assert state.edges == [{"alice", "bob", %{}}]
  end

  test "SaxyHandler handles data element with missing key" do
    state = %SaxyHandler{}

    {:ok, state} = SaxyHandler.handle_event(:start_element, {"data", []}, state)
    {:ok, state} = SaxyHandler.handle_event(:characters, "ignored", state)
    {:ok, state} = SaxyHandler.handle_event(:end_element, "data", state)

    assert state.current_attrs == %{}
  end
end
