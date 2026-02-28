defmodule SocialNetworkAnalysis do
  @moduledoc """
  Social Network Analysis Example

  Finding communities using SCCs
  """

  require Yog

  def run do
    # Model a social network where edges represent "follows" relationships
    social_graph =
      Yog.directed()
      |> Yog.add_node(1, "Alice")
      |> Yog.add_node(2, "Bob")
      |> Yog.add_node(3, "Carol")
      |> Yog.add_edge(from: 1, to: 2, weight: nil)
      |> Yog.add_edge(from: 2, to: 3, weight: nil)
      |> Yog.add_edge(from: 3, to: 1, weight: nil)

    # Find groups of mutually connected users
    communities = Yog.Components.scc(social_graph)

    IO.inspect(communities)
    # => [[...]] // Represents strongly connected communities
  end
end

SocialNetworkAnalysis.run()
