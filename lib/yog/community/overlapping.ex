defmodule Yog.Community.Overlapping do
  @moduledoc """
  Result of overlapping community detection (e.g., Clique Percolation).

  Unlike standard community detection, nodes can belong to multiple communities
  simultaneously, reflecting the reality that individuals often participate in
  multiple social groups.

  ## Fields

  - `memberships` - Map from node ID to list of community IDs
  - `num_communities` - Total number of distinct communities
  - `metadata` - Optional metadata (algorithm name, parameters, etc.)

  ## Examples

      iex> # Node 1 in communities 0 and 1, node 2 only in 1
      iex> overlapping = Yog.Community.Overlapping.new(%{1 => [0, 1], 2 => [1], 3 => [0]})
      iex> overlapping.num_communities
      2
      iex> overlapping.memberships[1]
      [0, 1]
  """

  alias Yog.Community.Result

  @type node_id :: Yog.Model.node_id()
  @type community_id :: integer()

  @enforce_keys [:memberships, :num_communities]
  defstruct [:memberships, :num_communities, metadata: %{}]

  @type t :: %__MODULE__{
          memberships: %{node_id() => [community_id()]},
          num_communities: non_neg_integer(),
          metadata: map()
        }

  @doc """
  Creates an overlapping community result from a memberships map.

  Automatically calculates the number of communities.
  """
  @spec new(%{node_id() => [community_id()]}) :: t()
  def new(memberships) when is_map(memberships) do
    num =
      if map_size(memberships) == 0 do
        0
      else
        memberships
        |> Map.values()
        |> List.flatten()
        |> Enum.max(fn -> -1 end)
        |> Kernel.+(1)
      end

    %__MODULE__{memberships: memberships, num_communities: num}
  end

  @doc """
  Creates an overlapping community result with explicit metadata.
  """
  @spec new(%{node_id() => [community_id()]}, map()) :: t()
  def new(memberships, metadata) when is_map(memberships) and is_map(metadata) do
    result = new(memberships)
    %{result | metadata: metadata}
  end

  @doc """
  Convert to non-overlapping result by assigning each node to its first community.
  """
  @spec to_result(t()) :: Result.t()
  def to_result(%__MODULE__{memberships: m, num_communities: n, metadata: meta}) do
    assignments =
      Map.new(m, fn
        {node, [first | _]} -> {node, first}
        {node, []} -> {node, 0}
      end)

    %Result{assignments: assignments, num_communities: n, metadata: meta}
  end

  @doc """
  Get all communities a node belongs to.
  """
  @spec communities_for_node(t(), node_id()) :: [community_id()]
  def communities_for_node(%__MODULE__{memberships: m}, node) do
    Map.get(m, node, [])
  end

  @doc """
  Get all nodes in a specific community.
  """
  @spec nodes_in_community(t(), community_id()) :: MapSet.t(node_id())
  def nodes_in_community(%__MODULE__{memberships: m}, community_id) do
    m
    |> Enum.filter(fn {_node, comms} -> community_id in comms end)
    |> Enum.map(fn {node, _} -> node end)
    |> MapSet.new()
  end

  @doc """
  Calculate the overlap (number of shared nodes) between two communities.
  """
  @spec overlap(t(), community_id(), community_id()) :: non_neg_integer()
  def overlap(%__MODULE__{} = result, comm_a, comm_b) do
    nodes_a = nodes_in_community(result, comm_a)
    nodes_b = nodes_in_community(result, comm_b)
    MapSet.size(MapSet.intersection(nodes_a, nodes_b))
  end

  @doc """
  Backward compatibility: convert from legacy map format.
  """
  @spec from_map(map()) :: t()
  def from_map(%{memberships: m, num_communities: n} = map) do
    metadata = Map.get(map, :metadata, %{})
    %__MODULE__{memberships: m, num_communities: n, metadata: metadata}
  end

  @doc """
  Convert to legacy map format.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{memberships: m, num_communities: n}) do
    %{memberships: m, num_communities: n}
  end
end
