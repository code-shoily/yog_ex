defmodule Yog.Community.CliquePercolation do
  @moduledoc """
  Clique Percolation Method (CPM) for overlapping community detection.

  Finds communities by identifying k-cliques (complete subgraphs of size k)
  and merging those that share (k-1)-cliques. Unlike other algorithms,
  CPM allows nodes to belong to multiple communities (overlapping).

  ## When to Use

  - When nodes may belong to multiple communities
  - For detecting overlapping community structure
  - When cliques are meaningful in your domain

  ## Options

  - `:k` - Clique size (default: 3)
  - `:min_community_size` - Minimum community size (default: 3)

  ## Example

      # Find overlapping communities
      overlapping = Yog.Community.CliquePercolation.detect_overlapping(graph)

      # Convert to standard communities (each node assigned to first community)
      communities = Yog.Community.CliquePercolation.to_communities(overlapping)
  """

  alias Yog.Community

  @doc """
  Returns default options for CPM.
  """
  @spec default_options() :: %{k: integer(), min_community_size: integer()}
  def default_options do
    %{k: 3, min_community_size: 3}
  end

  @doc """
  Detects overlapping communities using CPM with default options.

  Returns overlapping communities where each node can belong to multiple communities.
  """
  @spec detect_overlapping(Yog.graph()) :: Community.overlapping_communities()
  def detect_overlapping(graph) do
    {:overlapping_communities, memberships, num} =
      :yog@community@clique_percolation.detect_overlapping(graph)

    %{
      memberships: wrap_memberships(memberships),
      num_communities: num
    }
  end

  @doc """
  Detects overlapping communities using CPM with custom options.

  ## Options

    * `:k` - Clique size (default: 3)
    * `:min_community_size` - Minimum community size (default: 3)
  """
  @spec detect_overlapping_with_options(Yog.graph(), keyword()) ::
          Community.overlapping_communities()
  def detect_overlapping_with_options(graph, opts) do
    k = Keyword.get(opts, :k, 3)
    min_size = Keyword.get(opts, :min_community_size, 3)

    options = {:cpm_options, k, min_size}

    {:overlapping_communities, memberships, num} =
      :yog@community@clique_percolation.detect_overlapping_with_options(graph, options)

    %{
      memberships: wrap_memberships(memberships),
      num_communities: num
    }
  end

  @doc """
  Converts overlapping communities to standard communities.

  Each node is assigned to the first community in its membership list.
  """
  @spec to_communities(Community.overlapping_communities()) :: Community.communities()
  def to_communities(overlapping) do
    assignments =
      Enum.reduce(overlapping.memberships, %{}, fn {node, communities}, acc ->
        case communities do
          [first | _] -> Map.put(acc, node, first)
          [] -> acc
        end
      end)

    %{
      assignments: assignments,
      num_communities: overlapping.num_communities
    }
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp wrap_memberships(memberships) do
    memberships
    |> :gleam@dict.to_list()
    |> Map.new()
  end
end
