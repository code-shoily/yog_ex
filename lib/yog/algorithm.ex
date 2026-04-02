defmodule Yog.Algorithm do
  @moduledoc """
  Compile-time configuration for algorithm implementations.

  This module provides a way to choose between polymorphic (protocol-based)
  and direct (module-based) algorithm implementations at compile time.

  ## Configuration

  In your `config/config.exs` or `config/runtime.exs`:

      # Default: Fast direct calls, Yog.Graph only (2x faster)
      config :yog_ex, :algorithm_mode, :direct

      # Polymorphic: Works with any graph type (slower, for libgraph/etc)
      config :yog_ex, :algorithm_mode, :protocol

  ## Trade-offs

  | Mode | Works With | Speed | Use When |
  |------|------------|-------|----------|
  | `:direct` (default) | Yog.Graph only | **2x faster** | Default - most users use Yog.Graph |
  | `:protocol` | Any graph type | Normal (protocol dispatch) | Using libgraph, custom graphs, or mixed types |

  ## Switching Modes

  After changing config, **recompile**:

      mix deps.compile yog_ex --force

  ## Example

      # config/config.exs
      config :yog_ex, :algorithm_mode, :direct

      # Your code - now uses fast direct calls
      Yog.Pathfinding.Dijkstra.shortest_path(graph, from: 1, to: 5)

  ## Provided Aliases

  Using `Yog.Algorithm` provides these aliases based on mode:

  | Alias | `:direct` mode | `:protocol` mode |
  |-------|----------------|------------------|
  | `Model` | `Yog.Model` | `Yog.Queryable` |
  | `Mutator` | `Yog.Model` | `Yog.Modifiable` |
  """

  @mode Application.compile_env(:yog_ex, :algorithm_mode, :direct)

  defmacro __using__(opts \\ []) do
    mode = Keyword.get(opts, :mode, @mode)

    case mode do
      :protocol ->
        quote do
          alias Yog.Modifiable, as: Mutator
          alias Yog.Queryable, as: Model
        end

      :direct ->
        quote do
          alias Yog.Model
          alias Yog.Model, as: Mutator
        end

      other ->
        raise ArgumentError,
              "Invalid algorithm_mode: #{inspect(other)}. Use :protocol or :direct"
    end
  end

  @doc """
  Returns the current algorithm mode.

  ## Examples

      iex> Yog.Algorithm.mode()
      :direct  # or :protocol
  """
  def mode, do: @mode
end
