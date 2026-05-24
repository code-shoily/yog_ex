exclude = if Code.ensure_loaded?(Zig), do: [], else: [:zigler]
ExUnit.start(exclude: exclude)
