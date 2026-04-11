defmodule YogEx.MixProject do
  use Mix.Project

  @version "0.95.0"
  @source_url "https://github.com/code-shoily/yog_ex"

  def project do
    [
      app: :yog_ex,
      version: @version,
      elixir: "~> 1.15",
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
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp package do
    [
      name: "yog_ex",
      files:
        ~w(lib .formatter.exs mix.exs README.md GLEAM_ELIXIR_COMPARISON.md ALGORITHMS.md PROPERTIES.md LICENSE CHANGELOG.md),
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
        {"lib/yog/CHEATSHEET.cheatmd", title: "Cheat Sheet"},
        {"examples/README.md", [filename: "examples_readme", title: "Examples README"]},
        {"lib/yog/functional/README.md",
         [filename: "functional_readme", title: "Functional API README"]},
        "ALGORITHMS.md",
        "PROPERTIES.md",
        "GLEAM_ELIXIR_COMPARISON.md",
        "CHANGELOG.md"
      ],
      source_ref: "v#{@version}",
      source_url: @source_url,
      groups_for_modules: [
        Core: [
          Yog,
          Yog.Model,
          Yog.Graph,
          Yog.Multi,
          Yog.Multi.Graph,
          Yog.Multi.Model
        ],
        "Directed Acyclic Graphs (DAG)": [
          Yog.DAG,
          Yog.DAG.Model,
          Yog.DAG.Algorithm
        ],
        Algorithms: [
          ~r/Yog\.(Pathfinding|Traversal|MST|Flow|Community|Centrality|Connectivity)/
        ],
        Properties: [
          ~r/Yog\.Property/
        ],
        Generators: [
          ~r/Yog\.Generator/
        ],
        "I/O & Serialization": [
          ~r/Yog\.IO/,
          ~r/Yog\.Render/
        ],
        "Utilities & Transformations": [
          Yog.Transform,
          Yog.Operation,
          Yog.Utils,
          Yog.Health
        ],
        "Internal Structures": [
          Yog.PriorityQueue,
          Yog.DisjointSet,
          Yog.PairingHeap
        ]
      ],
      groups_for_extras: [
        Guides: [
          "README.md",
          "examples_readme",
          "functional_readme",
          "GLEAM_ELIXIR_COMPARISON.md"
        ],
        Reference: [
          "ALGORITHMS.md",
          "PROPERTIES.md"
        ],
        Resources: [
          "lib/yog/CHEATSHEET.cheatmd",
          "CHANGELOG.md"
        ]
      ]
    ]
  end
end
