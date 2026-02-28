defmodule Yog.Generators do
  @moduledoc """
  Convenience access to all Graph generators.
  """

  # Classic
  defdelegate empty(n), to: Yog.Generators.Classic
  defdelegate empty_with_type(n, graph_type), to: Yog.Generators.Classic
  defdelegate complete(n), to: Yog.Generators.Classic
  defdelegate complete_with_type(n, graph_type), to: Yog.Generators.Classic
  defdelegate cycle(n), to: Yog.Generators.Classic
  defdelegate cycle_with_type(n, graph_type), to: Yog.Generators.Classic
  defdelegate complete_bipartite(n1, n2), to: Yog.Generators.Classic
  defdelegate complete_bipartite_with_type(n1, n2, graph_type), to: Yog.Generators.Classic
  defdelegate path(n), to: Yog.Generators.Classic
  defdelegate path_with_type(n, graph_type), to: Yog.Generators.Classic
  defdelegate star(n), to: Yog.Generators.Classic
  defdelegate star_with_type(n, graph_type), to: Yog.Generators.Classic
  defdelegate wheel(n), to: Yog.Generators.Classic
  defdelegate wheel_with_type(n, graph_type), to: Yog.Generators.Classic
  defdelegate binary_tree(depth), to: Yog.Generators.Classic
  defdelegate binary_tree_with_type(depth, graph_type), to: Yog.Generators.Classic
  defdelegate grid_2d(rows, cols), to: Yog.Generators.Classic
  defdelegate grid_2d_with_type(rows, cols, graph_type), to: Yog.Generators.Classic
  defdelegate petersen(), to: Yog.Generators.Classic
  defdelegate petersen_with_type(graph_type), to: Yog.Generators.Classic

  # Random
  defdelegate erdos_renyi_gnp(n, p), to: Yog.Generators.Random
  defdelegate erdos_renyi_gnp_with_type(n, p, graph_type), to: Yog.Generators.Random
  defdelegate erdos_renyi_gnm(n, m), to: Yog.Generators.Random
  defdelegate erdos_renyi_gnm_with_type(n, m, graph_type), to: Yog.Generators.Random
  defdelegate barabasi_albert(n, m), to: Yog.Generators.Random
  defdelegate barabasi_albert_with_type(n, m, graph_type), to: Yog.Generators.Random
  defdelegate watts_strogatz(n, k, p), to: Yog.Generators.Random
  defdelegate watts_strogatz_with_type(n, k, p, graph_type), to: Yog.Generators.Random
  defdelegate random_tree(n), to: Yog.Generators.Random
  defdelegate random_tree_with_type(n, graph_type), to: Yog.Generators.Random
end
