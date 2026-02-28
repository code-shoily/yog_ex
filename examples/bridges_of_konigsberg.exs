defmodule BridgesOfKonigsberg do
  @moduledoc """
  The Seven Bridges of Königsberg problem
  """

  require Yog

  def run do
    # Nodes represent the four land masses (A, B, C, D)
    # Edges represent the seven bridges
    graph =
      Yog.undirected()
      |> Yog.add_node(1, "Island A")
      |> Yog.add_node(2, "Bank B")
      |> Yog.add_node(3, "Bank C")
      |> Yog.add_node(4, "Island D")
      # Bridges
      |> Yog.add_edge(from: 1, to: 2, weight: "b1")
      |> Yog.add_edge(from: 1, to: 2, weight: "b2")
      |> Yog.add_edge(from: 1, to: 3, weight: "b3")
      |> Yog.add_edge(from: 1, to: 3, weight: "b4")
      |> Yog.add_edge(from: 1, to: 4, weight: "b5")
      |> Yog.add_edge(from: 2, to: 4, weight: "b6")
      |> Yog.add_edge(from: 3, to: 4, weight: "b7")

    IO.puts("--- Seven Bridges of Königsberg ---")

    # Check if an Eulerian circuit exists (all even degrees)
    if Yog.Eulerian.has_eulerian_circuit?(graph) do
      IO.puts("Eulerian circuit exists!")
    else
      IO.puts("No Eulerian circuit exists.")
    end

    # Check if an Eulerian path exists (0 or 2 odd degrees)
    if Yog.Eulerian.has_eulerian_path?(graph) do
      IO.puts("Eulerian path exists!")

      case Yog.Eulerian.find_eulerian_path(graph) do
        {:ok, path} -> IO.puts("Path: #{inspect(path)}")
        {:error, _} -> nil
      end
    else
      IO.puts("No Eulerian path exists either.")
    end

    # Example of a graph that DOES have a circuit
    circuit_graph =
      Yog.undirected()
      |> Yog.add_node(1, "A")
      |> Yog.add_node(2, "B")
      |> Yog.add_node(3, "C")
      |> Yog.add_edge(from: 1, to: 2, weight: nil)
      |> Yog.add_edge(from: 2, to: 3, weight: nil)
      |> Yog.add_edge(from: 3, to: 1, weight: nil)

    IO.puts("\n--- Simple Triangle ---")

    case Yog.Eulerian.find_eulerian_circuit(circuit_graph) do
      {:ok, circuit} -> IO.puts("Circuit found: #{inspect(circuit)}")
      {:error, _} -> IO.puts("No circuit found")
    end
  end
end

BridgesOfKonigsberg.run()
