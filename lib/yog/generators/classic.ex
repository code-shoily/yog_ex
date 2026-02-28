defmodule Yog.Generators.Classic do
  @moduledoc "Generators for classic deterministic graphs"

  defdelegate empty(n), to: :yog@generators@classic
  defdelegate empty_with_type(n, graph_type), to: :yog@generators@classic

  defdelegate complete(n), to: :yog@generators@classic
  defdelegate complete_with_type(n, graph_type), to: :yog@generators@classic

  defdelegate cycle(n), to: :yog@generators@classic
  defdelegate cycle_with_type(n, graph_type), to: :yog@generators@classic

  defdelegate complete_bipartite(n1, n2), to: :yog@generators@classic
  defdelegate complete_bipartite_with_type(n1, n2, graph_type), to: :yog@generators@classic

  defdelegate path(n), to: :yog@generators@classic
  defdelegate path_with_type(n, graph_type), to: :yog@generators@classic

  defdelegate star(n), to: :yog@generators@classic
  defdelegate star_with_type(n, graph_type), to: :yog@generators@classic

  defdelegate wheel(n), to: :yog@generators@classic
  defdelegate wheel_with_type(n, graph_type), to: :yog@generators@classic

  defdelegate binary_tree(depth), to: :yog@generators@classic
  defdelegate binary_tree_with_type(depth, graph_type), to: :yog@generators@classic

  defdelegate grid_2d(rows, cols), to: :yog@generators@classic
  defdelegate grid_2d_with_type(rows, cols, graph_type), to: :yog@generators@classic

  defdelegate petersen(), to: :yog@generators@classic
  defdelegate petersen_with_type(graph_type), to: :yog@generators@classic
end
