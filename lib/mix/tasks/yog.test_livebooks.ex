# Mock modules for Kino to allow headless validation of Livebooks
defmodule KinoMock do
  @moduledoc false

  defmodule Layout do
    @moduledoc false
    def tabs(opts), do: opts
    def grid(inputs, _opts \\ []), do: inputs
  end

  defmodule Markdown do
    @moduledoc false
    def new(txt), do: txt
  end

  defmodule HTML do
    @moduledoc false
    def new(html), do: html
  end

  defmodule VizJS do
    @moduledoc false
    def render(dot, _opts \\ []), do: dot
  end

  defmodule Mermaid do
    @moduledoc false
    def new(mermaid_source), do: mermaid_source
  end
end

defmodule Mix.Tasks.Yog.TestLivebooks do
  use Mix.Task

  @shortdoc "Runs and evaluates all Elixir blocks inside the Livebooks"
  @moduledoc """
  Finds and runs all Elixir code blocks inside the `.livemd` files under the `livebooks/` directory.
  Ensures that the notebooks execute successfully without any runtime compilation or execution errors.

  Run this task via:
      mix yog.test_livebooks
  """

  @impl Mix.Task
  def run(_args) do
    # Start the application dependencies
    Mix.Task.run("app.start")

    # Find all livebooks
    livebooks =
      Path.wildcard("livebooks/**/*.livemd")
      |> Enum.sort()

    Mix.shell().info("Found #{length(livebooks)} Livebooks to evaluate...\n")

    results =
      Enum.map(livebooks, fn path ->
        IO.write("Testing #{path}... ")

        case run_livebook(path) do
          :ok ->
            IO.write("\e[32m[OK]\e[0m\n")
            {:ok, path}

          {:error, exception, stacktrace} ->
            IO.write("\e[31m[FAIL]\e[0m\n")
            Mix.shell().info("\n\e[31mError in #{path}:\e[0m")
            Mix.shell().info(Exception.format(:error, exception, stacktrace))

            Mix.shell().info(
              "--------------------------------------------------------------------------------"
            )

            {:error, path, exception}
        end
      end)

    failures = Enum.filter(results, &match?({:error, _, _}, &1))

    if Enum.empty?(failures) do
      Mix.shell().info("\n\e[32mAll Livebooks executed successfully!\e[0m")
      :ok
    else
      Mix.raise("#{length(failures)} Livebook(s) failed validation.")
    end
  end

  defp run_livebook(path) do
    content = File.read!(path)

    # Extract code blocks using a nested-aware backticks parser
    blocks = extract_code_blocks(content)

    # Concat blocks into a single execution block
    # Strip Mix.install calls and redirect Kino references to our mock module
    code_to_eval =
      blocks
      |> Enum.map_join("\n", &strip_mix_install/1)
      |> String.replace("Kino.", "KinoMock.")

    try do
      Code.eval_string(code_to_eval, [], __ENV__)
      :ok
    rescue
      exception ->
        {:error, exception, __STACKTRACE__}
    end
  end

  defp extract_code_blocks(content) do
    content
    |> String.split("\n")
    |> Enum.reduce({[], nil, []}, fn line, {blocks, current_block, current_lines} ->
      case current_block do
        nil ->
          case Regex.run(~r/^( `{3,})elixir\s*$/, line) do
            [_, ticks] ->
              {blocks, ticks, []}

            _ ->
              {blocks, nil, []}
          end

        ticks ->
          if String.trim(line) == ticks do
            block = Enum.reverse(current_lines) |> Enum.join("\n")
            {[block | blocks], nil, []}
          else
            {blocks, ticks, [line | current_lines]}
          end
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp strip_mix_install(code) do
    # Remove Mix.install([...]) blocks
    String.replace(code, ~r/Mix\.install\(\[.*?\]\)/s, "")
  end
end
