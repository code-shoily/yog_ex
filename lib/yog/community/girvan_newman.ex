defmodule Yog.Community.GirvanNewman do
  @moduledoc """
  Girvan-Newman algorithm for community detection.

  A divisive hierarchical clustering algorithm that progressively removes
  edges with highest betweenness centrality. This reveals the community
  structure at different levels of granularity.

  ## When to Use

  - When you need hierarchical community structure
  - When edge betweenness is meaningful for your domain
  - Smaller graphs (computationally expensive)

  ## Options

  - `:target_communities` - Stop when this many communities reached

  ## Example

      communities = Yog.Community.GirvanNewman.detect(graph)
  """

  alias Yog.Community

  @doc """
  Returns default options for Girvan-Newman.
  """
  @spec default_options() :: %{target_communities: integer() | nil}
  def default_options do
    %{target_communities: nil}
  end

  @doc """
  Detects communities using Girvan-Newman with default options.
  """
  @spec detect(Yog.graph()) :: Community.communities()
  def detect(graph) do
    {:communities, assignments, num} = :yog@community@girvan_newman.detect(graph)

    %{
      assignments: wrap_gleam_dict(assignments),
      num_communities: num
    }
  end

  @doc """
  Detects communities using Girvan-Newman with custom options.

  ## Options

    * `:target_communities` - Stop when this many communities reached (default: nil)
  """
  @spec detect_with_options(Yog.graph(), keyword()) ::
          {:ok, Community.communities()} | {:error, String.t()}
  def detect_with_options(graph, opts) do
    target = Keyword.get(opts, :target_communities)

    options = {:girvan_newman_options, target}

    case :yog@community@girvan_newman.detect_with_options(graph, options) do
      {:ok, {:communities, assignments, num}} ->
        {:ok,
         %{
           assignments: wrap_gleam_dict(assignments),
           num_communities: num
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================
  # Private Helpers
  # ============================================================

  defp wrap_gleam_dict(dict) do
    dict
    |> :gleam@dict.to_list()
    |> Map.new()
  end
end
