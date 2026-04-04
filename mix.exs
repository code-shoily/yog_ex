defmodule YogEx.MixProject do
  use Mix.Project

  @version "0.90.0"
  @source_url "https://github.com/code-shoily/yog_ex"

  def project do
    [
      app: :yog_ex,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),

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
      {:saxy, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:stream_data, "~> 1.1", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      name: "yog_ex",
      files:
        ~w(lib .formatter.exs mix.exs README.md ALGORITHMS.md PROPERTIES.md LICENSE CHANGELOG.md),
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
        "ALGORITHMS.md",
        "examples/README.md",
        "lib/yog/functional/README.md",
        "CHANGELOG.md",
        "PROPERTIES.md"
      ],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
