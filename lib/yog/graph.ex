defmodule Yog.Graph do
  @moduledoc """
  Core graph data structure.

  A graph is represented as a struct with four fields:
  - `kind`: Either `:directed` or `:undirected`
  - `nodes`: Map of node_id => node_data
  - `out_edges`: Map of node_id => %{neighbor_id => weight}
  - `in_edges`: Map of node_id => %{neighbor_id => weight}

  The dual-map representation (storing both out_edges and in_edges) enables:
  - O(1) graph transpose (just swap out_edges ↔ in_edges)
  - Efficient predecessor queries without traversing the entire graph
  - Fast bidirectional edge lookups

  ## Examples

      iex> %Yog.Graph{
      ...>   kind: :directed,
      ...>   nodes: %{1 => "A", 2 => "B"},
      ...>   out_edges: %{1 => %{2 => 10}},
      ...>   in_edges: %{2 => %{1 => 10}}
      ...> }
  """

  @type node_id :: integer()
  @type kind :: :directed | :undirected

  @type t :: %__MODULE__{
          kind: kind(),
          nodes: %{node_id() => any()},
          out_edges: %{node_id() => %{node_id() => number()}},
          in_edges: %{node_id() => %{node_id() => number()}}
        }

  @enforce_keys [:kind, :nodes, :out_edges, :in_edges]
  defstruct [:kind, :nodes, :out_edges, :in_edges]

  @doc """
  Creates a new empty graph of the given type.
  """
  @spec new(kind()) :: t()
  def new(kind) when kind in [:directed, :undirected] do
    %__MODULE__{
      kind: kind,
      nodes: %{},
      out_edges: %{},
      in_edges: %{}
    }
  end
end
