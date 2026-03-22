defmodule LeetCode do
  def num_islands(grid) do
    # Step 1: Tell Grid Builder what makes a tile an "island connector"
    # We pass it a function that returns true only if BOTH tiles are "1" (land)
    # The grid builder passes the "from" tile and "to" tile.
    is_land_path? = fn from_val, to_val ->
      from_val == "1" and to_val == "1"
    end

    # Step 2: Build the Grid Graph (Undirected)
    # The builder will automatically connect all adjacent "1"s
    graph =
      Yog.Builder.Grid.from_2d_list(grid, :undirected, is_land_path?)
      |> Yog.Builder.Grid.to_graph()

    # Step 3: Run Strongly Connected Components (SCC)
    # Since it's an undirected graph connecting only lands,
    # SCC will extract everything as components (including isolated water tiles).
    components = Yog.Components.scc(graph)

    # Step 4: The number of islands is the number of components
    # that are actually made of land. We can just check the first
    # node of each component to see if it's land!
    Enum.count(components, fn [node_id | _] ->
      Yog.Model.node(graph, node_id) == "1"
    end)
  end
end

grid1 = [
  ["1", "1", "1", "1", "0"],
  ["1", "1", "0", "1", "0"],
  ["1", "1", "0", "0", "0"],
  ["0", "0", "0", "0", "0"]
]

grid2 = [
  ["1", "1", "0", "0", "0"],
  ["1", "1", "0", "0", "0"],
  ["0", "0", "1", "0", "0"],
  ["0", "0", "0", "1", "1"]
]

IO.puts("Grid 1 (Expected 1): #{LeetCode.num_islands(grid1)}")
IO.puts("Grid 2 (Expected 3): #{LeetCode.num_islands(grid2)}")
