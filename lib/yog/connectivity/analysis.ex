defmodule Yog.Connectivity.Analysis do
  @moduledoc """
  Algorithms for analyzing graph connectivity (bridges, articulation points).
  """

  @type bridge :: {Yog.node_id(), Yog.node_id()}
  @type connectivity_results :: %{
          bridges: [bridge()],
          articulation_points: [Yog.node_id()]
        }

  @doc """
  Analyzes an **undirected graph** to find all bridges and articulation points.
  """
  @spec analyze(keyword() | Yog.graph()) :: connectivity_results()
  def analyze(options_or_graph) do
    graph =
      if is_list(options_or_graph) do
        Keyword.fetch!(options_or_graph, :in)
      else
        options_or_graph
      end

    do_analyze(graph)
  end

  defp do_analyze(graph) do
    initial_state = %{
      disc: %{},
      low: %{},
      parent: %{},
      time: 0,
      bridges: [],
      articulation_points: MapSet.new()
    }

    final_state =
      :maps.fold(
        fn node, _, state ->
          if Map.has_key?(state.disc, node) do
            state
          else
            analyze_dfs(graph, node, state)
          end
        end,
        initial_state,
        graph.nodes
      )

    %{
      bridges: Enum.sort(final_state.bridges),
      articulation_points: Enum.sort(MapSet.to_list(final_state.articulation_points))
    }
  end

  defp analyze_dfs(graph, node, state) do
    state =
      Map.update!(state, :disc, &Map.put(&1, node, state.time))
      |> Map.update!(:low, &Map.put(&1, node, state.time))
      |> Map.update!(:time, &(&1 + 1))

    {state_after_neighbors, children_count} =
      case Map.fetch(graph.out_edges, node) do
        {:ok, edges} ->
          :maps.fold(
            fn neighbor, _, {acc_state, count} ->
              case Map.fetch(acc_state.disc, neighbor) do
                :error ->
                  new_count = count + 1

                  new_state =
                    Map.update!(acc_state, :parent, &Map.put(&1, neighbor, node))
                    |> then(&analyze_dfs(graph, neighbor, &1))

                  new_low =
                    min(Map.fetch!(new_state.low, node), Map.fetch!(new_state.low, neighbor))

                  new_state = Map.update!(new_state, :low, &Map.put(&1, node, new_low))

                  parent = Map.get(new_state.parent, node)

                  new_state =
                    if parent != nil and
                         Map.fetch!(new_state.low, neighbor) >= Map.fetch!(new_state.disc, node) do
                      Map.update!(new_state, :articulation_points, &MapSet.put(&1, node))
                    else
                      new_state
                    end

                  new_state =
                    if Map.fetch!(new_state.low, neighbor) > Map.fetch!(new_state.disc, node) do
                      bridge = if node < neighbor, do: {node, neighbor}, else: {neighbor, node}
                      Map.update!(new_state, :bridges, &[bridge | &1])
                    else
                      new_state
                    end

                  {new_state, new_count}

                {:ok, _} ->
                  if Map.get(acc_state.parent, node) != neighbor do
                    new_low =
                      min(Map.fetch!(acc_state.low, node), Map.fetch!(acc_state.disc, neighbor))

                    new_state = Map.update!(acc_state, :low, &Map.put(&1, node, new_low))
                    {new_state, count}
                  else
                    {acc_state, count}
                  end
              end
            end,
            {state, 0},
            edges
          )

        :error ->
          {state, 0}
      end

    if Map.get(state_after_neighbors.parent, node) == nil and children_count > 1 do
      Map.update!(state_after_neighbors, :articulation_points, &MapSet.put(&1, node))
    else
      state_after_neighbors
    end
  end
end
