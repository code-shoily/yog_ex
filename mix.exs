defmodule YogEx.MixProject do
  use Mix.Project

  @version "0.98.0"
  @source_url "https://github.com/code-shoily/yog_ex"

  def project do
    [
      app: :yog_ex,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix], flags: [:no_opaque]],

      # Hex
      description: "A comprehensive pure Elixir graph algorithm library",
      package: package(),

      # Docs
      name: "YogEx",
      source_url: @source_url,
      docs: docs(),

      # Test Coverage
      test_coverage: [tool: ExCoveralls],
      # Suppress warnings for Erlang modules
      xref: [
        exclude: [
          # Erlang stdlib modules (xmerl)
          :xmerl_scan,
          :xmerl_xpath
        ]
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :xmerl]]
  end

  defp deps do
    [
      {:saxy, "~> 1.5", optional: true},
      {:jason, "~> 1.4", optional: true},
      {:libgraph, "~> 0.16", optional: true},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      {:benchee, "~> 1.3", only: :dev},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:jump_credo_checks, "~> 0.1", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      name: "yog_ex",
      files:
        ~w(lib .formatter.exs mix.exs README.md ALGORITHMS.md PROPERTIES.md LICENSE CHANGELOG.md livebooks),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        {"lib/yog/CHEATSHEET.cheatmd", [title: "Cheat Sheet", filename: "cheat_sheet"]},
        {"examples/README.md", [filename: "examples_readme", title: "Examples README"]},
        {"lib/yog/functional/README.md",
         [filename: "functional_readme", title: "Functional API README"]},
        {"livebooks/guides/getting_started.livemd",
         [filename: "getting_started", title: "Getting Started"]},
        {"livebooks/how_to/maze_generation.livemd",
         [filename: "maze_generation", title: "Maze Generation"]},
        {"livebooks/guides/traversals_and_pathfinding.livemd",
         [filename: "traversals_and_pathfinding", title: "Traversals & Pathfinding"]},
        {"livebooks/guides/network_analysis.livemd",
         [filename: "network_analysis", title: "Network Analysis"]},
        {"livebooks/guides/network_flow.livemd",
         [filename: "network_flow", title: "Network Flow"]},
        {"livebooks/guides/graph_properties.livemd",
         [filename: "graph_properties", title: "Graph Properties"]},
        {"livebooks/guides/dag_analysis.livemd",
         [filename: "dag_analysis", title: "DAG Analysis"]},
        {"livebooks/gallery/graph_catalog.livemd",
         [filename: "graph_catalog", title: "Graph Gallery"]},
        {"livebooks/how_to/customizing_visualizations.livemd",
         [filename: "customizing_visualizations", title: "Customizing Visualizations"]},
        {"livebooks/how_to/import_export.livemd",
         [filename: "import_export", title: "Importing & Exporting"]},
        {"livebooks/how_to/multigraphs_and_collapsing.livemd",
         [filename: "multigraphs_and_collapsing", title: "Multigraphs & Collapsing"]},
        "ALGORITHMS.md",
        "PROPERTIES.md",
        "CHANGELOG.md"
      ],
      source_ref: "v#{@version}",
      source_url: @source_url,
      mermaid: true,
      before_closing_body_tag: &before_closing_body_tag/1,
      groups_for_modules: [
        Core: [
          Yog,
          Yog.Model,
          Yog.Graph
        ],
        "Transformers & Operations": [
          Yog.Transform,
          Yog.Operation
        ],
        Builder: [
          ~r/Yog\.Builder/
        ],
        "Pathfinding & Traversal": [
          ~r/Yog\.(Pathfinding|Traversal)/
        ],
        "Network Algorithms": [
          ~r/Yog\.(MST|Flow|Connectivity)/
        ],
        "Network Analysis": [
          ~r/Yog\.(Community|Centrality)/,
          Yog.Health
        ],
        Multi: [
          ~r/Yog\.Multi/
        ],
        Functional: [
          ~r/Yog\.Functional/
        ],
        "Directed Acyclic Graphs (DAG)": [
          ~r/Yog\.DAG/
        ],
        Properties: [
          ~r/Yog\.Property/
        ],
        Generators: [
          ~r/Yog\.Generator/
        ],
        "I/O & Rendering": [
          ~r/Yog\.IO/,
          ~r/Yog\.Render/
        ],
        "Data Structures & Utils": [
          ~r/Yog\.(PriorityQueue|DisjointSet|PairingHeap)/,
          Yog.Utils
        ]
      ],
      groups_for_extras: [
        "Cheat Sheets": [
          "cheat_sheet"
        ],
        Guides: [
          "README.md",
          "examples_readme",
          "functional_readme",
          "getting_started",
          "traversals_and_pathfinding",
          "network_analysis",
          "network_flow",
          "graph_properties",
          "dag_analysis"
        ],
        Gallery: [
          "graph_catalog"
        ],
        "How-To": [
          "maze_generation",
          "customizing_visualizations",
          "import_export",
          "multigraphs_and_collapsing"
        ],
        Reference: [
          "ALGORITHMS.md",
          "PROPERTIES.md"
        ],
        Resources: [
          "CHANGELOG.md"
        ]
      ]
    ]
  end

  defp before_closing_body_tag(:html) do
    File.read!("priv/docs/graphviz.html")
  end

  defp before_closing_body_tag(_), do: ""
end
