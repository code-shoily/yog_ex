defmodule YogEx.MixProject do
  use Mix.Project

  @version "0.51.0"
  @source_url "https://github.com/code-shoily/yog_ex"

  def project do
    [
      app: :yog_ex,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: "Elixir wrapper for Yog - A comprehensive graph algorithm library",
      package: package(),

      # Docs
      name: "YogEx",
      source_url: @source_url,
      docs: docs(),

      # Test Coverage
      test_coverage: [tool: ExCoveralls]
    ]
  end

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
    [extra_applications: [:logger]]
  end

  defp deps do
    deps(Mix.env())
  end

  # Environment-specific dependencies to support hex publishing
  # Use MIX_ENV=publish for publishing package and docs to hex
  defp deps(:publish) do
    [
      {:yog, "~> 5.1"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp deps(_) do
    [
      {:yog, "~> 5.1", manager: :rebar3, app: false, override: true},
      # Note: yog_io is NOT included as a dependency to avoid conflicts during hex publishing.
      # The I/O modules (Yog.IO.*) are included in the package but require users to add
      # yog_io to their own deps if they need I/O functionality. See README for details.
      {:yog_io, ">= 1.0.0", manager: :rebar3, app: false, only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp package do
    [
      name: "yog_ex",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/main/CHANGELOG.md",
        "Yog (Gleam)" => "https://hexdocs.pm/yog"
      }
    ]
  end

  defp docs do
    [
      main: "README",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
