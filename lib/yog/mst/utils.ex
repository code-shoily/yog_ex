defmodule Yog.MST.Utils do
  @moduledoc false

  @spec extract_edges(Yog.graph()) :: [map()]
  def extract_edges(%Yog.Graph{kind: kind, out_edges: out_edges}) do
    List.foldl(Map.to_list(out_edges), [], fn {from_id, targets}, acc ->
      List.foldl(Map.to_list(targets), acc, fn {to_id, weight}, inner_acc ->
        if kind == :undirected && from_id > to_id do
          inner_acc
        else
          [%{from: from_id, to: to_id, weight: weight} | inner_acc]
        end
      end)
    end)
  end

  @spec push_all(Yog.PairingHeap.t(), [map()]) :: Yog.PairingHeap.t()
  def push_all(pq, edges) do
    List.foldl(edges, pq, fn edge, acc -> Yog.PairingHeap.push(acc, edge) end)
  end
end
