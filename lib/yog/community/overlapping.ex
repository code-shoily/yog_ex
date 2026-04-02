defmodule Yog.Community.Overlapping do
  @moduledoc """
  Result of overlapping community detection (e.g., Clique Percolation).

  Unlike standard community detection, nodes can belong to multiple communities
  simultaneously, reflecting the reality that individuals often participate in
  multiple social groups.

  ## Fields

  - `memberships` - Map from node ID to list of community IDs
  - `num_communities` - Total number of distinct communities
  - `community_index` - Inverted index: community_id -> MapSet of nodes
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

  @type node_id :: Yog.node_id()
  @type community_id :: any()

  @enforce_keys [:memberships, :num_communities]
  defstruct [:memberships, :num_communities, :community_index, metadata: %{}]

  @type t :: %__MODULE__{
          memberships: %{node_id() => [community_id()]},
          num_communities: non_neg_integer(),
          community_index: %{community_id() => MapSet.t(node_id())} | nil,
          metadata: map()
        }

  @doc """
  Creates an overlapping community result from a memberships map.

  Automatically calculates the number of communities by counting unique community IDs.
  Also builds an inverted index for O(1) community queries.
  """
  @spec new(%{node_id() => [community_id()]}) :: t()
  def new(memberships) when is_map(memberships) do
    # This handles non-integer IDs and non-sequential integers correctly
    all_communities =
      memberships
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()

    num = length(all_communities)

    community_index = build_community_index(memberships)

    %__MODULE__{
      memberships: memberships,
      num_communities: num,
      community_index: community_index
    }
  end

  @doc """
  Creates an overlapping community result with explicit metadata and optional pre-computed values.

  ## Options

  - `:num_communities` - Pre-computed community count to avoid re-scanning
  - `:community_index` - Pre-computed inverted index for O(1) queries
  """
  @spec new(%{node_id() => [community_id()]}, map(), keyword()) :: t()
  def new(memberships, metadata, opts \\ []) when is_map(memberships) and is_map(metadata) do
    num =
      case Keyword.get(opts, :num_communities) do
        nil ->
          memberships
          |> Map.values()
          |> List.flatten()
          |> Enum.uniq()
          |> length()

        n ->
          n
      end

    community_index =
      case Keyword.get(opts, :community_index) do
        nil -> build_community_index(memberships)
        idx -> idx
      end

    %__MODULE__{
      memberships: memberships,
      num_communities: num,
      community_index: community_index,
      metadata: metadata
    }
  end

  defp build_community_index(memberships) do
    Enum.reduce(memberships, %{}, fn {node, comms}, acc ->
      Enum.reduce(comms, acc, fn comm, inner_acc ->
        Map.update(inner_acc, comm, MapSet.new([node]), &MapSet.put(&1, node))
      end)
    end)
  end

  @doc """
  Convert to non-overlapping result by assigning each node to its first community.

  Nodes with no membership are excluded (not assigned to any community).
  """
  @spec to_result(t()) :: Result.t()
  def to_result(%__MODULE__{memberships: m, metadata: meta}) do
    assignments =
      m
      |> Enum.filter(fn {_node, comms} -> comms != [] end)
      |> Map.new(fn {node, [first | _]} -> {node, first} end)

    # Recalculate num_communities based on actual assignments
    actual_num =
      if map_size(assignments) == 0 do
        0
      else
        assignments |> Map.values() |> Enum.uniq() |> length()
      end

    Result.new(assignments, meta, num_communities: actual_num)
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

  Uses inverted index for O(1) lookup.
  """
  @spec nodes_in_community(t(), community_id()) :: MapSet.t(node_id())
  def nodes_in_community(%__MODULE__{community_index: idx}, community_id) when is_map(idx) do
    Map.get(idx, community_id, MapSet.new())
  end

  # Fallback for legacy structs without index
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

    community_index = build_community_index(m)

    %__MODULE__{
      memberships: m,
      num_communities: n,
      community_index: community_index,
      metadata: metadata
    }
  end

  @doc """
  Convert to legacy map format.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{memberships: m, num_communities: n}) do
    %{memberships: m, num_communities: n}
  end
end
