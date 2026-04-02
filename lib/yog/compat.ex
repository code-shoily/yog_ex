defmodule Yog.Compat do
  @moduledoc """
  Compatibility layer for choosing between protocol-based and direct module calls.

  ## Usage

  For internal modules that only work with `Yog.Graph` (the default), use direct
  `Yog.Model` calls for maximum performance:

      use Yog.Compat, mode: :direct
      # Expands to: alias Yog.Model

  For modules that need to work with custom graph types, use protocols:

      use Yog.Compat, mode: :protocol
      # Expands to: alias Yog.Queryable, as: Model

  ## Default

  If no mode is specified, defaults to `:direct` for maximum performance
  on `Yog.Graph` structs.

  ## When to Use Each Mode

  | Mode | Use When | Performance |
  |------|----------|-------------|
  | `:direct` | Working only with `Yog.Graph` | Fastest (direct calls) |
  | `:protocol` | Working with custom graph types | Slower (protocol dispatch) |

  ## Examples

      defmodule MyAlgorithm do
        # Fast path - only works with Yog.Graph
        use Yog.Compat, mode: :direct

        def process(graph) do
          # Calls Yog.Model.successors/2 directly
          Model.successors(graph, node)
        end
      end

      defmodule MyGenericAlgorithm do
        # Polymorphic path - works with any graph type
        use Yog.Compat, mode: :protocol

        def process(graph) do
          # Calls Yog.Queryable.successors/2 via protocol
          Model.successors(graph, node)
        end
      end
  """

  defmacro __using__(opts) do
    mode = Keyword.get(opts, :mode, :direct)

    aliases =
      case mode do
        :direct ->
          quote do
            @compile {:inline, successors: 2, predecessors: 2, out_degree: 2}
            alias Yog.Model
          end

        :protocol ->
          quote do
            alias Yog.Queryable, as: Model
          end

        other ->
          raise ArgumentError, "Invalid mode: #{inspect(other)}. Use :direct or :protocol"
      end

    quote do
      unquote(aliases)
    end
  end

  @doc """
  Macro for conditionally using either protocol or direct calls based on a compile-time flag.

  ## Example

      defmodule MyModule do
        @use_protocols Application.compile_env(:yog_ex, :use_protocols, false)

        require Yog.Compat
        Yog.Compat.using_protocols @use_protocols do
          alias Yog.Queryable, as: Model
        else
          alias Yog.Model
        end
      end
  """
  defmacro using_protocols(flag, do: protocol_block, else: direct_block) do
    quote do
      if unquote(flag) do
        unquote(protocol_block)
      else
        unquote(direct_block)
      end
    end
  end
end
