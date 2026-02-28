defmodule Yog.Generators.Random do
  @moduledoc "Generators for stochastic random graph models"

  defdelegate erdos_renyi_gnp(n, p), to: :yog@generators@random
  defdelegate erdos_renyi_gnp_with_type(n, p, graph_type), to: :yog@generators@random

  defdelegate erdos_renyi_gnm(n, m), to: :yog@generators@random
  defdelegate erdos_renyi_gnm_with_type(n, m, graph_type), to: :yog@generators@random

  defdelegate barabasi_albert(n, m), to: :yog@generators@random
  defdelegate barabasi_albert_with_type(n, m, graph_type), to: :yog@generators@random

  defdelegate watts_strogatz(n, k, p), to: :yog@generators@random
  defdelegate watts_strogatz_with_type(n, k, p, graph_type), to: :yog@generators@random

  defdelegate random_tree(n), to: :yog@generators@random
  defdelegate random_tree_with_type(n, graph_type), to: :yog@generators@random
end
