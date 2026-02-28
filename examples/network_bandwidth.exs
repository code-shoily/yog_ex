defmodule NetworkBandwidth do
  @moduledoc """
  Network Bandwidth Allocation Example

  Demonstrates max flow for bandwidth optimization with bottleneck analysis
  """

  require Yog

  def run do
    IO.puts("=== Network Bandwidth Allocation ===\n")

    # Model a network with routers and bandwidth constraints
    # Nodes: 0=Source, 1=RouterA, 2=RouterB, 3=RouterC, 4=RouterD, 5=Destination
    # Edge weights represent bandwidth capacity in Mbps

    network =
      Yog.directed()
      # From source
      |> Yog.add_edge(from: 0, to: 1, with: 20)
      # Source -> Router A (20 Mbps)
      |> Yog.add_edge(from: 0, to: 2, with: 30)
      # Source -> Router B (30 Mbps)
      # Intermediate connections
      |> Yog.add_edge(from: 1, to: 2, with: 10)
      # Router A -> Router B (10 Mbps)
      |> Yog.add_edge(from: 1, to: 3, with: 15)
      # Router A -> Router C (15 Mbps)
      |> Yog.add_edge(from: 2, to: 3, with: 25)
      # Router B -> Router C (25 Mbps)
      |> Yog.add_edge(from: 2, to: 4, with: 20)
      # Router B -> Router D (20 Mbps)
      # To destination
      |> Yog.add_edge(from: 3, to: 5, with: 30)
      # Router C -> Destination (30 Mbps)
      |> Yog.add_edge(from: 4, to: 5, with: 15)
      # Router D -> Destination (15 Mbps)

    IO.puts("Network topology:")
    IO.puts(" Source (0) -> RouterA (1): 20 Mbps")
    IO.puts(" Source (0) -> RouterB (2): 30 Mbps")
    IO.puts(" RouterA (1) -> RouterC (3): 15 Mbps")
    IO.puts(" RouterB (2) -> RouterC (3): 25 Mbps")
    IO.puts(" RouterB (2) -> RouterD (4): 20 Mbps")
    IO.puts(" RouterC (3) -> Dest (5): 30 Mbps")
    IO.puts(" RouterD (4) -> Dest (5): 15 Mbps\n")

    # Find maximum bandwidth from source to destination
    result = Yog.MaxFlow.edmonds_karp(
      in: network,
      from: 0,
      to: 5,
      zero: 0,
      add: &(&1 + &2),
      subtract: fn a, b -> a - b end,
      compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end,
      min: &min/2
    )

    IO.puts("Maximum bandwidth from source to destination: #{result.max_flow} Mbps")

    # Find the minimum cut (bottleneck in the network)
    cut = Yog.MaxFlow.min_cut(
      result: result,
      zero: 0,
      compare: fn a, b -> if a < b, do: :lt, else: if(a > b, do: :gt, else: :eq) end
    )

    IO.puts("\n=== Minimum Cut Analysis ===")
    IO.puts("This identifies the bottleneck that limits network capacity.\n")

    IO.puts("Source side nodes:")
    print_node_list(MapSet.to_list(cut.source_side))

    IO.puts("\nSink side nodes:")
    print_node_list(MapSet.to_list(cut.sink_side))

    IO.puts("\nThe edges crossing from source side to sink side form the bottleneck.")
    IO.puts("Their total capacity (#{result.max_flow} Mbps) equals the maximum flow.")
    IO.puts("\nThis tells us which links to upgrade to increase network capacity.")
  end

  defp print_node_list([]), do: IO.puts(" (none)")
  defp print_node_list(nodes) do
    nodes
    |> Enum.each(fn node -> IO.puts(" Node #{node}") end)
  end
end

NetworkBandwidth.run()
