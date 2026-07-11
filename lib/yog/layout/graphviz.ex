defmodule Yog.Layout.GraphViz do
  @moduledoc """
  Optional layout adapter that shells out to GraphViz and imports computed
  coordinates back into `Yog.Layout` position maps.

  This module requires an external installation of GraphViz (the `dot`, `neato`,
  etc. commands) to be present on your system's PATH.

  ## Coordinates and Scaling

  GraphViz computes coordinates in inches by default in its `-Tplain` output.
  To align with typical screen pixels, this module scales coordinates by `72.0`
  (since standard resolution is 72 points per inch). You can customize this
  using the `:position_scale` option.
  """

  @node_regex ~r/^node\s+(?:"([^"]*)"|([^\s]+))\s+([-\d.]+)\s+([-\d.]+)/

  @doc """
  Positions nodes using a GraphViz layout engine.

  Supports both simple graphs (`Yog.Graph`) and multigraphs (`Yog.Multi.Graph`).

  ## Options

    * `:engine` - The GraphViz engine to execute (e.g. `:dot`, `:neato`, `:fdp`, `:circo`, `:twopi`) (default: `:dot`).
    * `:position_scale` - Factor to multiply GraphViz coordinates by (default: `72.0` to convert inches to screen points/pixels).
    * `:dot_options` - Map of custom DOT renderer options passed to the exporter.

  ## Error Handling

  Raises a `RuntimeError` if the GraphViz engine executable is not found on the
  system's PATH, or if the command fails during execution.

  ## Example

      graph = Yog.directed() |> Yog.add_nodes_from([1, 2])
      # Requires GraphViz installed on system PATH:
      # positions = Yog.Layout.GraphViz.layout(graph, engine: :dot)
      # => %{1 => {27.0, 90.0}, 2 => {27.0, 18.0}}
  """
  @spec layout(Yog.Graph.t() | Yog.Multi.Graph.t(), keyword()) :: %{
          any() => {float(), float()}
        }
  def layout(graph, opts \\ []) do
    engine_name = Keyword.get(opts, :engine, :dot) |> to_string()
    dot_opts = Keyword.get(opts, :dot_options, %{})
    scale = Keyword.get(opts, :position_scale, 72.0)

    case System.find_executable(engine_name) do
      nil ->
        raise RuntimeError,
              "GraphViz executable '#{engine_name}' not found. Please ensure GraphViz is installed and on your PATH."

      _path ->
        :ok
    end

    is_multi = is_struct(graph, Yog.Multi.Graph)

    dot_string =
      if is_multi do
        Yog.Multi.DOT.to_dot(
          graph,
          Map.merge(Yog.Multi.DOT.default_options(), dot_opts)
        )
      else
        Yog.Render.DOT.to_dot(
          graph,
          Map.merge(Yog.Render.DOT.default_options(), dot_opts)
        )
      end

    plain = run_graphviz(engine_name, dot_string)

    node_ids = if is_multi, do: Yog.Multi.all_nodes(graph), else: Yog.all_nodes(graph)
    id_map = Map.new(node_ids, fn id -> {Yog.Utils.safe_string(id), id} end)

    parse_plain_output(plain, id_map, scale)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp run_graphviz(engine, dot_string) do
    # Write DOT source to a temp file and pipe it to the GraphViz engine.
    tmp_path =
      System.tmp_dir!() |> Path.join("yog_graphviz_#{:erlang.unique_integer([:positive])}.dot")

    try do
      File.write!(tmp_path, dot_string)

      case System.cmd(engine, ["-Tplain", tmp_path]) do
        {output, 0} ->
          output

        {err, code} ->
          raise RuntimeError,
                "GraphViz command '#{engine}' failed with exit code #{code}: #{inspect(err)}"
      end
    after
      File.rm(tmp_path)
    end
  end

  defp parse_plain_output(plain, id_map, scale) do
    plain
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case Regex.run(@node_regex, line) do
        [_, quoted, unquoted, x_str, y_str] ->
          str_name = if quoted != "", do: quoted, else: unquoted

          case Map.fetch(id_map, str_name) do
            {:ok, node_id} ->
              x = parse_float(x_str) * scale
              y = parse_float(y_str) * scale
              Map.put(acc, node_id, {x, y})

            :error ->
              acc
          end

        _ ->
          acc
      end
    end)
  end

  defp parse_float(str) do
    if String.contains?(str, "."),
      do: String.to_float(str),
      else: String.to_float(str <> ".0")
  end
end
