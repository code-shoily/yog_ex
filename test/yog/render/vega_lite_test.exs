defmodule Yog.Render.VegaLiteTest do
  use ExUnit.Case, async: true

  doctest Yog.Render.VegaLite

  alias Yog.Layout

  test "generates VegaLite specification if module is loaded, otherwise raises error" do
    graph = Yog.from_unweighted_edges(:undirected, [{1, 2}])
    pos = Layout.circular(graph)

    if Code.ensure_loaded?(Elixir.VegaLite) do
      spec = Yog.Render.VegaLite.to_spec(graph, pos)
      assert is_struct(spec)
      assert spec.__struct__ == Elixir.VegaLite
    else
      assert_raise RuntimeError, ~r/VegaLite module is not loaded/, fn ->
        Yog.Render.VegaLite.to_spec(graph, pos)
      end
    end
  end
end
