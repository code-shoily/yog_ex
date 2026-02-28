defmodule Mix.Tasks.Yog.Sync do
  @moduledoc "Checks if YogEx is missing any exported functions from the Gleam Yog library"
  use Mix.Task

  @shortdoc "Checks for missing Gleam wrappers"

  @impl Mix.Task
  def run(_args) do
    # Ensure yog is loaded
    Application.ensure_all_started(:yog)

    # 1. Get all public functions from the primary :yog Erlang module
    gleam_exports = get_exports(:yog) |> MapSet.new()

    # 2. Get all public functions from our Elixir wrapper
    elixir_exports = get_exports(Yog) |> MapSet.new()

    # 3. Find missing exports
    missing = MapSet.difference(gleam_exports, elixir_exports)

    if MapSet.size(missing) == 0 do
      Mix.shell().info([:green, "✓ YogEx is fully in sync with Yog!"])
    else
      Mix.shell().error([:red, "✗ Missing wrappers in Yog!"])
      Mix.shell().info("The following functions are exported by :yog but missing in Yog:")

      missing
      |> Enum.sort()
      |> Enum.each(fn {func, arity} ->
        Mix.shell().info("  - #{func}/#{arity}")
      end)
      
      System.halt(1)
    end
  end

  defp get_exports(module) do
    # Load the module if it isn't already
    Code.ensure_loaded(module)
    
    module.module_info(:exports)
    |> Enum.reject(fn {func, _arity} ->
      # Ignore standard Erlang/Elixir internal functions
      func in [:module_info, :__info__]
    end)
  end
end
