# YogEx Livebooks

Welcome to the **YogEx** Livebooks directory! [Livebook](https://livebook.dev/) is an interactive, collaborative web notebook for writing and running Elixir code. 

This folder contains interactive notebooks designed to help you learn, explore, and visualize the graph and maze algorithms provided by `YogEx`.

---

## Directory Structure

The notebooks are organized into logical subdirectories based on their focus:

### 1. [Guides](file:///home/mafinar/repos/elixir/yog_ex/livebooks/guides/)
Step-by-step learning notebooks designed to take you from graph basics to advanced concepts in sequence:
*   [01_getting_started.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/guides/01_getting_started.livemd): Basics of constructing, inspecting, and querying graphs.
*   [02_traversals_and_pathfinding.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/guides/02_traversals_and_pathfinding.livemd): DFS/BFS traversals, Dijkstra, and A* pathfinding.
*   [03_graph_properties.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/guides/03_graph_properties.livemd): Connectivity, checking for cycles, bipartite checks, topological sorts, and graph metrics.
*   [04_dag_analysis.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/guides/04_dag_analysis.livemd): Specific utilities and algorithms optimized for Directed Acyclic Graphs.
*   [05_network_analysis.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/guides/05_network_analysis.livemd): Node centralities (PageRank, Closeness, Harmonic, Betweenness, HITS) and modularity detection.
*   [06_network_flow.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/guides/06_network_flow.livemd): Max-flow algorithms like Ford-Fulkerson and Edmonds-Karp.

### 2. [How-To Guides](file:///home/mafinar/repos/elixir/yog_ex/livebooks/how_to/)
Practical walkthroughs addressing specific design patterns, configurations, or features:
*   [customizing_visualizations.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/how_to/customizing_visualizations.livemd): How to color nodes, customize styles, and format Graphviz DOT attributes.
*   [import_export.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/how_to/import_export.livemd): Importing/exporting graphs via CSV, JSON, DOT, GML, and GraphML.
*   [maze_generation.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/how_to/maze_generation.livemd): A deep dive into generating spanning tree mazes using diverse algorithms.
*   [mermaid_complete_guide.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/how_to/mermaid_complete_guide.livemd): Rendering interactive flowcharts, sequence diagrams, and network layouts using Mermaid.js.
*   [multigraphs_and_collapsing.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/how_to/multigraphs_and_collapsing.livemd): Working with multiple edges between same nodes and collapsing/simplifying graphs.

### 3. [Galleries](file:///home/mafinar/repos/elixir/yog_ex/livebooks/gallery/)
Interactive showcases of complex topologies, visual layouts, and algorithm comparisons:
*   [graph_catalog.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/gallery/graph_catalog.livemd): A gallery of pre-constructed classic graphs (cliques, stars, wheels, grids, bipartite graphs) rendered in diverse formats.
*   [maze_gallery.livemd](file:///home/mafinar/repos/elixir/yog_ex/livebooks/gallery/maze_gallery.livemd): Side-by-side comparison of all 11+ supported maze generation algorithms with Unicode grids, solved paths, and spanning tree layouts.

---

## How to Run the Livebooks

1. **Install Livebook**: If you haven't already, install and launch [Livebook](https://livebook.dev/):
   ```bash
   mix escript.install hex livebook
   livebook start
   ```
2. **Open a Livebook**: From the Livebook dashboard, click **Open** and select any `.livemd` file in this directory.
3. **Run Cells**: Execute the code cells sequentially. The notebooks automatically pull the local `YogEx` source code so you can test features and customize them in real-time.
