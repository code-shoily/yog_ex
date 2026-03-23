defmodule YogEx.MixProject do
  use Mix.Project

  @version "0.52.2"
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
      test_coverage: [tool: ExCoveralls],
      # Suppress warnings for Erlang and Gleam modules
      xref: [
        exclude: [
          # Erlang stdlib modules (xmerl)
          :xmerl_scan,
          :xmerl_xpath,

          # Gleam yog modules - use regex pattern
          ~r/^:yog@.*/
        ]
      ]
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
      {:ex_doc, "~> 0.31", runtime: false}
    ]
  end

  defp deps(_) do
    [
      {:yog, "~> 5.1", manager: :rebar3, app: false},
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
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
