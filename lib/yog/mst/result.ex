defmodule Yog.MST.Result do
  @moduledoc """
  Result of a Minimum Spanning Tree computation.

  Contains the edges of the MST along with summary statistics.

  ## Fields

  - `edges` - List of edges in the MST, as `%{from: id, to: id, weight: term()}` maps
  - `total_weight` - Sum of all edge weights in the MST
  - `node_count` - Number of nodes in the original graph
  - `edge_count` - Number of edges in the MST
  - `algorithm` - The algorithm used (`:kruskal`, `:prim`, `:boruvka`, `:chu_liu_edmonds`, or `:wilson`)
  - `root` - The root node ID (for arborescence algorithms)

  ## Examples

      iex> edges = [
      ...>   %{from: 1, to: 2, weight: 1},
      ...>   %{from: 2, to: 3, weight: 2}
      ...> ]
      iex> result = Yog.MST.Result.new(edges, :kruskal, 3)
      iex> result.total_weight
      3
      iex> result.edge_count
      2
  """

  @enforce_keys [:edges, :total_weight, :node_count, :edge_count, :algorithm]
  defstruct [:edges, :total_weight, :node_count, :edge_count, :algorithm, :root]

  @type t :: %__MODULE__{
          edges: [Yog.MST.edge()],
          total_weight: number(),
          node_count: non_neg_integer(),
          edge_count: non_neg_integer(),
          algorithm: :kruskal | :prim | :boruvka | :chu_liu_edmonds | :wilson,
          root: Yog.node_id() | nil
        }

  @doc """
  Creates a new MST result from a list of edges.

  ## Example

      iex> edges = [%{from: 1, to: 2, weight: 5}]
      iex> Yog.MST.Result.new(edges, :prim, 2)
      %Yog.MST.Result{
        edges: [%{from: 1, to: 2, weight: 5}],
        total_weight: 5,
        node_count: 2,
        edge_count: 1,
        algorithm: :prim
      }
  """
  @spec new(
          [Yog.MST.edge()],
          :kruskal | :prim | :boruvka | :chu_liu_edmonds | :wilson,
          non_neg_integer(),
          term()
        ) :: t()
  def new(edges, algorithm, node_count, root \\ nil) do
    total_weight = Enum.reduce(edges, 0, fn e, acc -> acc + e.weight end)

    %__MODULE__{
      edges: edges,
      total_weight: total_weight,
      node_count: node_count,
      edge_count: length(edges),
      algorithm: algorithm,
      root: root
    }
  end
end
